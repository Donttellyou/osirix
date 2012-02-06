/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - LGPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import "basicHTTPServer.h"


@implementation basicHTTPServer

- (id)init {
    connClass = [basicHTTPConnection self];
    return self;
}

- (void)dealloc {
    [super dealloc];
}

- (Class)connectionClass {
    return connClass;
}

- (void)setConnectionClass:(Class)value {
    connClass = value;
}

- (NSURL *)documentRoot {
    return docRoot;
}

- (void)setDocumentRoot:(NSURL *)value {
    if (docRoot != value) {
        [docRoot release];
        docRoot = [value copy];
    }
}

// Converts the TCPServer delegate notification into the HTTPServer delegate method.
- (void)handleNewConnectionFromAddress:(NSData *)addr inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr {
    basicHTTPConnection *connection = [[connClass alloc] initWithPeerAddress:addr inputStream:istr outputStream:ostr forServer:self runloopMode: runloopmode];
    [connection setDelegate:[self delegate]];
    if ([self delegate] && [[self delegate] respondsToSelector:@selector(basicHTTPServer:didMakeNewConnection:)]) { 
        [[self delegate] HTTPServer:self didMakeNewConnection:connection];
    }
    // The connection at this point is turned loose to exist on its
    // own, and not released or autoreleased.  Alternatively, the
    // HTTPServer could keep a list of connections, and basicHTTPConnection
    // would have to tell the server to delete one at invalidation
    // time.  This would perhaps be more correct and ensure no
    // spurious leaks get reported by the tools, but HTTPServer
    // has nothing further it wants to do with the HTTPConnections,
    // and would just be "owning" the connections for form.
}

@end


@implementation basicHTTPConnection

- (id)init {
    [self release];
    return nil;
}

- (id)initWithPeerAddress:(NSData *)addr inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr forServer:(basicHTTPServer *)serv runloopMode: (NSString*) r {
    peerAddress = [addr copy];
    server = serv;
    istream = [istr retain];
    ostream = [ostr retain];
    [istream setDelegate:self];
    [ostream setDelegate:self];
    [istream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode: r];		//kCFRunLoopCommonModes
    [ostream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode: r];		//kCFRunLoopCommonModes
    [istream open];
    [ostream open];
    isValid = YES;
	
    return self;
}

- (void)dealloc
{
    [self invalidate];
    [peerAddress release];
	[closeTimer invalidate];
	[closeTimer release];
	[super dealloc];
}

- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)value {
    delegate = value;
}

- (NSData *)peerAddress {
    return peerAddress;
}

- (basicHTTPServer *)server {
    return server;
}

- (HTTPServerRequest *)nextRequest {
    unsigned idx, cnt = requests ? [requests count] : 0;
    for (idx = 0; idx < cnt; idx++) {
        id obj = [requests objectAtIndex:idx];
        if ([obj response] == nil) {
            return obj;
        }
    }
    return nil;
}

- (BOOL)isValid {
    return isValid;
}

- (void)invalidate
{
	if (isValid)
	{
//		NSLog( @"http connection closed");
		
        isValid = NO;
        [istream close];
        [ostream close];
        [istream release];
        [ostream release];
        istream = nil;
        ostream = nil;
        [ibuffer release];
        [obuffer release];
        ibuffer = nil;
        obuffer = nil;
		[requests removeAllObjects];
        [requests release];
        requests = nil;
        [self release];
		
        // This last line removes the implicit retain the basicHTTPConnection
        // has on itself, given by the HTTPServer when it abandoned the
        // new connection.
    }
}

// YES return means that a complete request was parsed, and the caller
// should call again as the buffered bytes may have another complete
// request available.
- (BOOL)processIncomingBytes
{
	if( isValid == NO)
		return NO;
	
	if( closeTimer)
		[closeTimer setFireDate: [[closeTimer fireDate] addTimeInterval: 1]];
	
    CFHTTPMessageRef working = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
    CFHTTPMessageAppendBytes(working, [ibuffer bytes], [ibuffer length]);
    
    // This "try and possibly succeed" approach is potentially expensive
    // (lots of bytes being copied around), but the only API available for
    // the server to use, short of doing the parsing itself.
    
    // basicHTTPConnection does not handle the chunked transfer encoding
    // described in the HTTP spec.  And if there is no Content-Length
    // header, then the request is the remainder of the stream bytes.
    
    if (CFHTTPMessageIsHeaderComplete(working))
	{
        NSString *contentLengthValue = [(NSString *)CFHTTPMessageCopyHeaderFieldValue(working, (CFStringRef)@"Content-Length") autorelease];
        
        unsigned contentLength = contentLengthValue ? [contentLengthValue intValue] : 0;
        NSData *body = [(NSData *)CFHTTPMessageCopyBody(working) autorelease];
        unsigned bodyLength = [body length];
        if (contentLength <= bodyLength)
		{
            NSData *newBody = [NSData dataWithBytes:[body bytes] length:contentLength];
            [ibuffer setLength:0];
            [ibuffer appendBytes:([body bytes] + contentLength) length:(bodyLength - contentLength)];
            CFHTTPMessageSetBody(working, (CFDataRef)newBody);
        }
		else
		{
            CFRelease(working);
            return NO;
        }
    }
	else
	{
		CFRelease(working);
        return NO;
    }
    
	if( isValid == NO)
	{
		CFRelease(working);
		return NO;
	}
	
    HTTPServerRequest *request = [[HTTPServerRequest alloc] initWithRequest:working connection:self];
    if (!requests)
        requests = [[NSMutableArray alloc] init];
	
    [requests addObject: request];
	
	@try
	{
		if (delegate && [delegate respondsToSelector:@selector(HTTPConnection:didReceiveRequest:)])
		{ 
			[delegate HTTPConnection:self didReceiveRequest:request];
		}
		else
		{
			[self performDefaultRequestHandling:request];
		}
	}
	@catch (NSException * e)
	{
		NSLog( @"basicHTTPConnection didReceiveRequest exception: %@", e);
	}
	
	CFRelease(working);
	[request release];
	
	if( isValid == NO)
		return NO;
	
    return YES;
}

- (void)processOutgoingBytes {
    // The HTTP headers, then the body if any, then the response stream get
    // written out, in that order.  The Content-Length: header is assumed to 
    // be properly set in the response.  Outgoing responses are processed in 
    // the order the requests were received (required by HTTP).
    
    // Write as many bytes as possible, from buffered bytes, response
    // headers and body, and response stream.

    if (![ostream hasSpaceAvailable]) {
        return;
    }

    unsigned olen = [obuffer length];
    if (0 < olen) {
        int writ = [ostream write:[obuffer bytes] maxLength:olen];
        // buffer any unwritten bytes for later writing
        if (writ < olen) {
            memmove([obuffer mutableBytes], [obuffer mutableBytes] + writ, olen - writ);
            [obuffer setLength:olen - writ];
            return;
        }
        [obuffer setLength:0];
    }

    unsigned cnt = requests ? [requests count] : 0;
    HTTPServerRequest *req = (0 < cnt) ? [requests objectAtIndex:0] : nil;

    CFHTTPMessageRef cfresp = req ? [req response] : NULL;
    if (!cfresp) return;
    
    if (!obuffer) {
        obuffer = [[NSMutableData alloc] init];
    }

    if (!firstResponseDone) {
        firstResponseDone = YES;
        NSData *serialized = [(NSData *)CFHTTPMessageCopySerializedMessage(cfresp) autorelease];
        unsigned olen = [serialized length];
        if (0 < olen) {
            int writ = [ostream write:[serialized bytes] maxLength:olen];
            if (writ < olen) {
                // buffer any unwritten bytes for later writing
                [obuffer setLength:(olen - writ)];
                memmove([obuffer mutableBytes], [serialized bytes] + writ, olen - writ);
                return;
            }
        }
    }

    NSInputStream *respStream = [req responseBodyStream];
    if (respStream) {
        if ([respStream streamStatus] == NSStreamStatusNotOpen) {
            [respStream open];
        }
        // read some bytes from the stream into our local buffer
        [obuffer setLength:16 * 1024];
        int read = [respStream read:[obuffer mutableBytes] maxLength:[obuffer length]];
        [obuffer setLength:read];
    }

    if (0 == [obuffer length]) {
        // When we get to this point with an empty buffer, then the 
        // processing of the response is done. If the input stream
        // is closed or at EOF, then no more requests are coming in.
        if (delegate && [delegate respondsToSelector:@selector(HTTPConnection:didSendResponse:)])
		{ 
            [delegate HTTPConnection:self didSendResponse:req];
        }
		
		[req retain];
		
        [requests removeObjectAtIndex:0];
        firstResponseDone = NO;
		
        if( ([istream streamStatus] == NSStreamStatusAtEnd && [requests count] == 0))
		{
            [self invalidate];
        }
		else if( [[(id)CFHTTPMessageCopyHeaderFieldValue( [req request], (CFStringRef)@"Connection") autorelease] isEqualToString: @"close"] && [requests count] == 0)
		{
			[self invalidate];
		}
		else if( [requests count] == 0)
		{
			if( closeTimer == nil)
			{
				[closeTimer invalidate];
				[closeTimer release];
				closeTimer = [[NSTimer scheduledTimerWithTimeInterval: 60 target: self selector: @selector( closeTimerFunction:)  userInfo:0 repeats: NO] retain];
				[[NSRunLoop currentRunLoop] addTimer: closeTimer forMode: [server runloopmode]];
			}
		}
		
		[req release];
		
        return;
    }
    
    olen = [obuffer length];
    if (0 < olen) {
        int writ = [ostream write:[obuffer bytes] maxLength:olen];
        // buffer any unwritten bytes for later writing
        if (writ < olen) {
            memmove([obuffer mutableBytes], [obuffer mutableBytes] + writ, olen - writ);
        }
        [obuffer setLength:olen - writ];
    }
}

- (void)closeTimerFunction:(NSTimer*)theTimer
{
	[self invalidate];
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)streamEvent
{
	if( isValid == NO) return;
	
    switch(streamEvent)
	{
    case NSStreamEventHasBytesAvailable:;
        uint8_t buf[16 * 1024];
        uint8_t *buffer = NULL;
        NSUInteger len = 0;
        if (![istream getBuffer:&buffer length:&len])
		{
            int amount = [istream read:buf maxLength:sizeof(buf)];
            buffer = buf;
            len = amount;
        }
        if (0 < len && len < 0xffffffff) {
            if (!ibuffer) {
                ibuffer = [[NSMutableData alloc] init];
            }
            [ibuffer appendBytes:buffer length:len];
        }
        do {} while (isValid && [self processIncomingBytes]);
        break;
    case NSStreamEventHasSpaceAvailable:;
        [self processOutgoingBytes];
        break;
    case NSStreamEventEndEncountered:;
        [self processIncomingBytes];
        if (stream == ostream) {
            // When the output stream is closed, no more writing will succeed and
            // will abandon the processing of any pending requests and further
            // incoming bytes.
            [self invalidate];
        }
        break;
    case NSStreamEventErrorOccurred:;
        NSLog(@"basicHTTPServer stream error: %@", [stream streamError]);
        break;
    default:
        break;
    }
}

- (void)performDefaultRequestHandling:(HTTPServerRequest *)mess {
    CFHTTPMessageRef request = [mess request];

    NSString *vers = [(id)CFHTTPMessageCopyVersion(request) autorelease];
    if (!vers) {
        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 505, NULL, vers ? (CFStringRef)vers : kCFHTTPVersion1_0); // Version Not Supported
        [mess setResponse:response];
        CFRelease(response);
        return;
    }

    NSString *method = [(id)CFHTTPMessageCopyRequestMethod(request) autorelease];
    if (!method) {
        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 400, NULL, (CFStringRef)vers); // Bad Request
        [mess setResponse:response];
        CFRelease(response);
        return;
    }

    if ([method isEqual:@"GET"] || [method isEqual:@"HEAD"]) {
        NSURL *uri = [(NSURL *)CFHTTPMessageCopyRequestURL(request) autorelease];
        NSURL *url = [NSURL URLWithString:[uri path] relativeToURL:[server documentRoot]];
        NSData *data = [NSData dataWithContentsOfURL:url];

        if (!data) {
            CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 404, NULL, (CFStringRef)vers); // Not Found
            [mess setResponse:response];
            CFRelease(response);
            return;
        }

        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 200, NULL, (CFStringRef)vers); // OK
        CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Length", (CFStringRef)[NSString stringWithFormat:@"%d", [data length]]);
        if ([method isEqual:@"GET"]) {
            CFHTTPMessageSetBody(response, (CFDataRef)data);
        }
        [mess setResponse:response];
        CFRelease(response);
        return;
    }

    CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 405, NULL, (CFStringRef)vers); // Method Not Allowed
    [mess setResponse:response];
    CFRelease(response);
}

@end


@implementation HTTPServerRequest

- (id)init {
    [self dealloc];
    return nil;
}

- (id)initWithRequest:(CFHTTPMessageRef)req connection:(basicHTTPConnection *)conn {
    connection = conn;
    request = (CFHTTPMessageRef)CFRetain(req);
    return self;
}

- (void)dealloc {
    if (request) CFRelease(request);
    if (response) CFRelease(response);
    [responseStream release];
    [super dealloc];
}

- (basicHTTPConnection *)connection {
    return connection;
}

- (CFHTTPMessageRef)request {
    return request;
}

- (CFHTTPMessageRef)response {
    return response;
}

- (void)setResponse:(CFHTTPMessageRef)value {
    if (value != response) {
        if (response) CFRelease(response);
        response = (CFHTTPMessageRef)CFRetain(value);
        if (response) {
            // check to see if the response can now be sent out
            [connection processOutgoingBytes];
        }
    }
}

- (NSInputStream *)responseBodyStream {
    return responseStream;
}

- (void)setResponseBodyStream:(NSInputStream *)value {
    if (value != responseStream) {
        [responseStream release];
        responseStream = [value retain];
    }
}

@end

