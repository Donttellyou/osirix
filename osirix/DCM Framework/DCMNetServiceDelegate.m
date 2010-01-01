/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import "DCMNetServiceDelegate.h"
#import "SendController.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>

static DCMNetServiceDelegate *_netServiceDelegate = nil;
static NSHost *currentHost = nil;
static BOOL bugFixedForDNSResolve = NO;
static NSMutableArray *cachedServersArray = nil;
static NSLock *currentHostLock = nil;

@implementation DCMNetServiceDelegate

+ (id)sharedNetServiceDelegate
{
	if (! _netServiceDelegate)
		_netServiceDelegate = [[DCMNetServiceDelegate alloc] init];
	return _netServiceDelegate;
}

+(NSHost*) currentHost
{
	if( currentHostLock == nil) currentHostLock = [[NSLock alloc] init];
	[currentHostLock lock];
	if( currentHost == nil)
	{
		NSLog( @"<><><><><><><> [NSHost currentHost]");
		currentHost = [[NSHost currentHost] retain];
	}
	[currentHostLock unlock];
	
	return currentHost;
}

- (void) setPublisher: (NSNetService*) p
{
	publisher = p;
}

- (id)init
{
	if (self = [super init])
	{
		OSErr err;
		SInt32 osVersion;
		
		err = Gestalt ( gestaltSystemVersion, &osVersion );       
		if ( err == noErr)       
		{
			if ( osVersion >= 0x1052UL ) bugFixedForDNSResolve = YES;
		}
		
		#if !__LP64__
			bugFixedForDNSResolve = YES;
		#endif
		
		_dicomNetBrowser = [[NSNetServiceBrowser alloc] init];
		[_dicomNetBrowser setDelegate:self];
		[self update];
	}
	return self;
}

- (void)update
{
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"searchDICOMBonjour"])
	{
		NSLog(@"searchDICOMBonjour - searchForServicesOfType : _dicom._tcp");
		[_dicomNetBrowser searchForServicesOfType:@"_dicom._tcp." inDomain:@""];
	}
}

- (void)dealloc
{
	NSLog(@"DCMNetServiceDelegate dealloc");
	[_dicomServices release];
	[_dicomNetBrowser release];
	[super dealloc];
}

- (NSArray *)dicomServices
{
	return _dicomServices;
}

- (int)portForNetService:(NSNetService *)netService
{		
	//NSArray *addresses = [[_dicomServices objectAtIndex:0] addresses];
	NSArray *addresses = [netService addresses];
	NSLog( @"portForNetService addresses:%d", [addresses count]);
	struct sockaddr *addr = ( struct sockaddr *) [[addresses objectAtIndex:0]  bytes];
	int aPort = -1;
	if(addr->sa_family == AF_INET)		
		aPort = ((struct sockaddr_in *)addr)->sin_port;
	
	else if(addr->sa_family == AF_INET6)		
		aPort = ((struct sockaddr_in6 *)addr)->sin6_port;
			
	return NSSwapBigShortToHost(aPort);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing
{
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
	if( aNetService == publisher || [[aNetService name] isEqualToString: [publisher name]] == YES)
	{
	
	}
	else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"searchDICOMBonjour"])
	{
		if( bugFixedForDNSResolve)
		{
			[_dicomServices addObject: aNetService];
			
			[aNetService resolveWithTimeout: 5];
			[aNetService setDelegate:self];
		}
	}
}

//Bonjour Delegate methods
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict
{
	NSLog(@"netServiceBrowser didNotSearch");	
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveDomain:(NSString *)domainString moreComing:(BOOL)moreComing
{
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
	[aNetService retain];	// <- Yes, this is a memory leak, but we will avoid a not comprehensible bug....
	
	if( [_dicomServices containsObject: aNetService])
	{
		NSLog( @"didRemove retainCout: %d", [aNetService retainCount]);
		[_dicomServices removeObject: aNetService];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"DCMNetServicesDidChange" object:nil];
	}
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser{
	NSLog(@"Stopped DICOM bonjour search");
	[_dicomServices removeAllObjects];
}

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser{
	NSLog(@"Start bonjour DICOM search");
	if (_dicomServices)
		[_dicomServices release];
	_dicomServices = [[NSMutableArray array] retain];
}

//NetService delegate
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
    NSLog( @"There was an error while attempting to resolve address for %@", [sender name]);
}

+ (NSArray *) DICOMServersListSendOnly: (BOOL) send QROnly:(BOOL) QR cached:(BOOL) cached
{
	NSMutableArray *serversArray = nil;
	
	if( cached == NO)	// Important - forked processes will fail here
	{
		if( [[NSUserDefaults standardUserDefaults] boolForKey:@"syncDICOMNodes"])
		{
			NSURL *url = [NSURL URLWithString: [[NSUserDefaults standardUserDefaults] valueForKey:@"syncDICOMNodesURL"]];
			
			if( url)
			{
				NSArray	*r = [NSArray arrayWithContentsOfURL: url];
				
				if( r)
					[[NSUserDefaults standardUserDefaults] setObject: r forKey:@"SERVERS"];
			}
		}
	}
	
	if( cached == NO || cachedServersArray == nil)
	{
		serversArray = [NSMutableArray arrayWithArray: [[NSUserDefaults standardUserDefaults] arrayForKey: @"SERVERS"]];
		
		// Check if we have the new/old format
		
		BOOL toBeSaved = NO;
		for( int i = 0 ; i < [serversArray count] ; i++)
		{
			NSDictionary *d = [serversArray objectAtIndex: i];
			
			if( [d objectForKey: @"retrieveMode"] == nil)
			{
				NSMutableDictionary *mdict = [NSMutableDictionary dictionaryWithDictionary: d];
				
				if( [[d objectForKey: @"CGET"] boolValue] == YES)
					[mdict setObject: [NSNumber numberWithInt: CGETRetrieveMode] forKey: @"retrieveMode"];
				else
					[mdict setObject: [NSNumber numberWithInt: CMOVERetrieveMode] forKey: @"retrieveMode"];
					
				[mdict removeObjectForKey: @"CGET"];
				[mdict removeObjectForKey: @"CMOVE"];
				[mdict removeObjectForKey: @"WADO"];
				
				[serversArray replaceObjectAtIndex: [serversArray indexOfObject: d] withObject: mdict];
				
				toBeSaved = YES;
			}
		}
		
		if( toBeSaved)
		{
			[[NSUserDefaults standardUserDefaults] setObject: serversArray forKey: @"SERVERS"];
		}
		
		if( [[NSUserDefaults standardUserDefaults] boolForKey:@"searchDICOMBonjour"])
		{
			NSArray *dicomServices = [[DCMNetServiceDelegate sharedNetServiceDelegate] dicomServices];
			
			for( int i = 0 ; i < [dicomServices count] ; i++)
			{
				NSNetService*	aServer = [dicomServices objectAtIndex: i];
				
				NSString		*hostname;
				int				port;
				
				hostname = [DCMNetServiceDelegate gethostnameAndPort:&port forService: aServer];
				
				if( hostname)
				{
					NSDictionary *dict = [NSNetService dictionaryFromTXTRecordData: [aServer TXTRecordData]];
					NSString *description = nil;
					
					if( [dict valueForKey: @"serverDescription"])
						description = [[[NSString alloc] initWithData: [dict valueForKey: @"serverDescription"] encoding:NSUTF8StringEncoding] autorelease];
					else
						description = [NSString stringWithFormat:@"%@ (Bonjour)", [aServer hostName]];
					
					int transferSyntax = 2;
					
					if( [dict valueForKey: @"preferredSyntax"])
					{
						NSString *ts = [[[NSString alloc] initWithData: [dict valueForKey: @"preferredSyntax"] encoding:NSUTF8StringEncoding] autorelease];
						
						if( [ts isEqualToString: @"LittleEndianImplicit"])
							transferSyntax = 0;
							
						if( [ts isEqualToString: @"JPEGProcess14SV1TransferSyntax"])
							transferSyntax = SendJPEGLossless;
							
						if( [ts isEqualToString: @"JPEG2000LosslessOnly"])
							transferSyntax = SendJPEG2000Lossless;
							
						if( [ts isEqualToString: @"JPEG2000"])
							transferSyntax = SendJPEG2000Lossy50;
							
						if( [ts isEqualToString: @"RLELossless"])
							transferSyntax = SendRLE;
					}
					
					BOOL retrieveMode = CMOVERetrieveMode;
					
					if( [dict valueForKey: @"CGET"])
					{
						NSString *cg = [[[NSString alloc] initWithData: [dict valueForKey: @"CGET"] encoding:NSUTF8StringEncoding] autorelease];
						retrieveMode = CGETRetrieveMode;
					}
					
					NSMutableDictionary *s = [NSMutableDictionary dictionaryWithObjectsAndKeys:	hostname, @"Address",
																									[aServer name], @"AETitle",
																									[NSString stringWithFormat:@"%d", port], @"Port",
																									[NSNumber numberWithBool:YES] , @"QR",
																									[NSNumber numberWithInt: retrieveMode] , @"retrieveMode",
																									[NSNumber numberWithBool:YES] , @"Send",
																									description, @"Description",
																									[NSNumber numberWithInt: transferSyntax], @"TransferSyntax",
																									nil];
					
					if( [dict valueForKey: @"icon"])
					{
						NSString *icon = [[[NSString alloc] initWithData: [dict valueForKey: @"icon"] encoding:NSUTF8StringEncoding] autorelease];
						[s setObject: icon forKey: @"icon"];
					}
					
					// Dont add duplicate addresses
					BOOL alreadyHere = NO;
					for( int v = 0; v < [serversArray count]; v++)
					{
						NSDictionary *d = [serversArray objectAtIndex: v];
						
						if( [[d valueForKey: @"Port"] intValue] == [[s valueForKey: @"Port"] intValue])
						{
							if( [[d valueForKey: @"Address"] isEqualToString: [s valueForKey: @"Address"]])
								alreadyHere = YES;
							else if( [[DCMNetServiceDelegate getIPAddress: [d valueForKey: @"Address"]] isEqualToString: [DCMNetServiceDelegate getIPAddress: [s valueForKey: @"Address"]]])
							{
								// If one of these addresses is numeric -> keep the dns name
								if( [[NSCharacterSet decimalDigitCharacterSet] characterIsMember: [[d valueForKey: @"Address"] characterAtIndex: 0]])
								{
									[serversArray objectAtIndex: v];
									v--;
								}
								else
									alreadyHere = YES;
							}
						}
					}
					
					if( alreadyHere == NO)
						[serversArray addObject: s];
				}
			}
		}
		
		[cachedServersArray release];
		cachedServersArray = [[NSMutableArray arrayWithArray: serversArray] retain];
	}
	else serversArray = [NSMutableArray arrayWithArray: cachedServersArray];
	
	if( send)
	{
		for( int i = 0 ; i < [serversArray count] ; i++)
		{
			if( [[serversArray objectAtIndex: i] valueForKey:@"Send"] != nil && [[[serversArray objectAtIndex: i] valueForKey:@"Send"] boolValue] == NO)
			{
				[serversArray removeObjectAtIndex: i];
				i--;
			}
		}
	}
	
	if( QR)
	{
		for( int i = 0 ; i < [serversArray count] ; i++ )
		{
			if( [[serversArray objectAtIndex: i] valueForKey:@"QR"] != nil && [[[serversArray objectAtIndex: i] valueForKey:@"QR"] boolValue] == NO)
			{
				[serversArray removeObjectAtIndex: i];
				i--;
			}
		}
	}
	
	return serversArray;
}

+ (NSArray *) DICOMServersListSendOnly: (BOOL) send QROnly:(BOOL) QR
{
	return [DCMNetServiceDelegate DICOMServersListSendOnly:send QROnly:QR cached:NO];
}

+ (NSArray *) DICOMServersList
{
	return [DCMNetServiceDelegate DICOMServersListSendOnly:NO QROnly:NO];
}

+ (NSString*) getIPAddress: (NSString*) address
{
	struct sockaddr_in service;
	const char	*host_name = [address UTF8String];
	
	bzero((char *) &service, sizeof(service));
	service.sin_family = AF_INET;
	
	if( host_name)
	{
		if (isalpha(host_name[0]))
		{
			struct hostent *hp;
			
			hp = gethostbyname( host_name);
			if( hp) bcopy(hp->h_addr, (char *) &service.sin_addr, hp->h_length);
			else service.sin_addr.s_addr = inet_addr( host_name);
		}
		else service.sin_addr.s_addr = inet_addr( host_name);
		
		char buffer[256];
		NSString *result = nil;
		
		if (inet_ntop(AF_INET, &service.sin_addr, buffer, sizeof(buffer)))
			result = [NSString stringWithCString:buffer encoding: NSISOLatin1StringEncoding];
		
		return result;
	}
	
	return nil;
}

+ (NSString*) gethostnameAndPort: (int*) port forService:(NSNetService*) sender
{
	struct sockaddr		*result;
	char				buffer[256];
	NSString			*hostname = nil;
	NSString			*portString = nil;
	
	for ( NSData *addr in [sender addresses] )
	{
		result = (struct sockaddr *)[addr bytes];
	
		int family = result->sa_family;
		if (family == AF_INET)
		{
			if (inet_ntop(AF_INET, &((struct sockaddr_in *)result)->sin_addr, buffer, sizeof(buffer)))
			{
				hostname = [NSString stringWithCString:buffer encoding: NSISOLatin1StringEncoding];
				portString = [NSString stringWithFormat:@"%d", ntohs(((struct sockaddr_in *)result)->sin_port)];
				
				if(port) *port = [portString intValue];
			}
		}
		else if (family == AF_INET6)
		{
		
		}
		else
		{
		
		}
	}
	
	return hostname;
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
	NSLog( @"DICOM Bonjour node detected: %@", sender);
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DCMNetServicesDidChange" object:nil];
}
@end
