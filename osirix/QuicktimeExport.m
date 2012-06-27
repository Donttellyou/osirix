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

#import <QTKit/QTKit.h>
#import "QuicktimeExport.h"
#import "Wait.h"
#import "WaitRendering.h"
#import "BrowserController.h"
#import "DicomDatabase.h"

#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>

@implementation QuicktimeExport

//+ (NSString*) generateQTVR:(NSString*) srcPath frames:(int) frames
//{
//	NSTask			*theTask = [[NSTask alloc] init];
//	
//	NSString *newPath = [[srcPath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"tempMovie"];
//	[[NSFileManager defaultManager] removeFileAtPath: newPath handler: nil];
//	
//	[theTask setArguments: [NSArray arrayWithObjects:@"generateQTVR", srcPath, [NSString stringWithFormat:@"%d", frames], nil]];
//	
//	NSString	*stringPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"/32-bit shell.app/Contents/MacOS/32-bit shell"];
//	if( [[NSFileManager defaultManager] fileExistsAtPath: stringPath])
//	{
//		[theTask setLaunchPath: stringPath];
//		[theTask launch];
//		[theTask waitUntilExit];
//	}
//	
//	[theTask release];
//	
//	return newPath;
//}

- (id) initWithSelector:(id) o :(SEL) s :(long) f
{
	self = [super init];
	
	[NSBundle loadNibNamed:@"QuicktimeExport" owner:self];
	
	object = o;
	selector = s;
	numberOfFrames = f;
	
	return self;
}

#if !__LP64__
//- (NSArray *)availableComponents
//{
//	//{
////		NSMutableArray		*results = nil;
////	ComponentDescription	cd = {};
////	Component		 c = NULL;
////	Handle			 nameHandle = NewHandle(0);
////	
////	if ( nameHandle == NULL )
////		return( nil );
////	cd.componentType = MovieExportType;
////	cd.componentSubType = 0;
////	cd.componentManufacturer = 0;
////	cd.componentFlags = canMovieExportFiles;
////	cd.componentFlagsMask = canMovieExportFiles;
////
////	while((c = FindNextComponent(c, &cd)))
////	{
////		ComponentDescription	exportCD = {};
////		
////		if ( GetComponentInfo( c, &exportCD, nameHandle, NULL, NULL ) == noErr )
////		{
////			HLock( nameHandle );
////			NSString	*nameStr = [[[NSString alloc] initWithBytes:(*nameHandle)+1 length:(int)**nameHandle encoding:NSMacOSRomanStringEncoding] autorelease];
////			HUnlock( nameHandle );
////			
////			exportCD.componentType = CFSwapInt32HostToBig(exportCD.componentType);
////			exportCD.componentSubType = CFSwapInt32HostToBig(exportCD.componentSubType);
////			exportCD.componentManufacturer = CFSwapInt32HostToBig(exportCD.componentManufacturer);
////				
////			NSString *type = [[[NSString alloc] initWithBytes:&exportCD.componentType length:sizeof(OSType) encoding:NSMacOSRomanStringEncoding] autorelease];
////			NSString *subType = [[[NSString alloc] initWithBytes:&exportCD.componentSubType length:sizeof(OSType) encoding:NSMacOSRomanStringEncoding] autorelease];
////			NSString *manufacturer = [[[NSString alloc] initWithBytes:&exportCD.componentManufacturer length:sizeof(OSType) encoding:NSMacOSRomanStringEncoding] autorelease];
////			
////			NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
////				nameStr, @"name", [NSValue valueWithPointer:c], @"component",
////				type, @"type", subType, @"subtype", manufacturer, @"manufacturer", nil];
////			
////			NSLog( [dictionary description]);
////			
////			if ( results == nil ) {
////				results = [NSMutableArray array];
////			}
////			
////			[results addObject:dictionary];
////		}
////	}
////	
////	DisposeHandle( nameHandle );
////
////	}
//	NSMutableArray *array = [NSMutableArray array];
//
//
//	ComponentDescription cd;
//	Component c;
//	
//	cd.componentType = MovieExportType;
//	cd.componentSubType = kQTFileTypeMovie;
//	cd.componentManufacturer = kAppleManufacturer;
//	cd.componentFlags = hasMovieExportUserInterface;
//	cd.componentFlagsMask = hasMovieExportUserInterface;
//	c = FindNextComponent( 0, &cd );
//	
//	if( c)
//	{
//		Handle name = NewHandle(4);
//		ComponentDescription exportCD;
//		
//		if (GetComponentInfo(c, &exportCD, name, nil, nil) == noErr)
//		{
//			//unsigned char *namePStr = (unsigned char*) *name;
//			//NSString *nameStr = [[NSString alloc] initWithBytes:&namePStr[1] length:namePStr[0] encoding:NSUTF8StringEncoding];
//			NSString *nameStr = [[NSString alloc] initWithString: @"Quicktime Movie"];
//			
//			NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
//				nameStr, @"name",
//				[NSData dataWithBytes:&c length:sizeof(c)], @"component",
//				[NSNumber numberWithLong:exportCD.componentType], @"type",
//				[NSNumber numberWithLong:exportCD.componentSubType], @"subtype",
//				[NSNumber numberWithLong:exportCD.componentManufacturer], @"manufacturer",
//				nil];
//			[array addObject:dictionary];
//			[nameStr release];
//			
//			NSLog( @"%@", [dictionary description]);
//		}
//		
//		DisposeHandle(name);
//	}
//
//	cd.componentType = MovieExportType;
//	cd.componentSubType = 'ASF_';
//	cd.componentManufacturer = 'TELE';
//	cd.componentFlags = hasMovieExportUserInterface;
//	cd.componentFlagsMask = hasMovieExportUserInterface;
//	c = FindNextComponent( 0, &cd );
//	
//	if( c)
//	{
//		Handle name = NewHandle(4);
//		ComponentDescription exportCD;
//		
//		if (GetComponentInfo(c, &exportCD, name, nil, nil) == noErr)
//		{
//			//unsigned char *namePStr = (unsigned char*) *name;
//			//NSString *nameStr = [[NSString alloc] initWithBytes:&namePStr[1] length:namePStr[0] encoding:NSUTF8StringEncoding];
//			NSString *nameStr = [[NSString alloc] initWithString: @"WMV Movie"];
//			
//			NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
//				nameStr, @"name",
//				[NSData dataWithBytes:&c length:sizeof(c)], @"component",
//				[NSNumber numberWithLong:exportCD.componentType], @"type",
//				[NSNumber numberWithLong:exportCD.componentSubType], @"subtype",
//				[NSNumber numberWithLong:exportCD.componentManufacturer], @"manufacturer",
//				nil];
//			[array addObject:dictionary];
//			[nameStr release];
//			
//			NSLog( @"%@", [dictionary description]);
//		}
//		
//		DisposeHandle(name);
//	}
//
//	cd.componentType = MovieExportType;
//	cd.componentSubType = kQTFileTypeAVI;
//	cd.componentManufacturer = kAppleManufacturer;
//	cd.componentFlags = hasMovieExportUserInterface;
//	cd.componentFlagsMask = hasMovieExportUserInterface;
//	c = FindNextComponent( 0, &cd );
//	
//	if( c)
//	{
//		Handle name = NewHandle(4);
//		ComponentDescription exportCD;
//		
//		if (GetComponentInfo(c, &exportCD, name, nil, nil) == noErr)
//		{
//			//unsigned char *namePStr = (unsigned char*) *name;
//			//NSString *nameStr = [[NSString alloc] initWithBytes:&namePStr[1] length:namePStr[0] encoding:NSUTF8StringEncoding];
//			NSString *nameStr = [[NSString alloc] initWithString: @"AVI Movie"];
//			
//			NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
//				nameStr, @"name",
//				[NSData dataWithBytes:&c length:sizeof(c)], @"component",
//				[NSNumber numberWithLong:exportCD.componentType], @"type",
//				[NSNumber numberWithLong:exportCD.componentSubType], @"subtype",
//				[NSNumber numberWithLong:exportCD.componentManufacturer], @"manufacturer",
//				nil];
//			[array addObject:dictionary];
//			[nameStr release];
//			
//			NSLog( @"%@", [dictionary description]);
//		}
//		
//		DisposeHandle(name);
//	}
//	
//	cd.componentType = MovieExportType;
//	cd.componentSubType = kQTFileTypeMP4;
//	cd.componentManufacturer = kAppleManufacturer;
//	cd.componentFlags = hasMovieExportUserInterface;
//	cd.componentFlagsMask = hasMovieExportUserInterface;
//	c = FindNextComponent( 0, &cd );
//	
//	if( c)
//	{
//		Handle name = NewHandle(4);
//		ComponentDescription exportCD;
//		
//		if (GetComponentInfo(c, &exportCD, name, nil, nil) == noErr)
//		{
//			//unsigned char *namePStr = (unsigned char*) *name;
//			//NSString *nameStr = [[NSString alloc] initWithBytes:&namePStr[1] length:namePStr[0] encoding:NSUTF8StringEncoding];
//			
//			NSString *nameStr = [[NSString alloc] initWithString: @"MPEG4 Movie"];
//			
//			NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
//				nameStr, @"name",
//				[NSData dataWithBytes:&c length:sizeof(c)], @"component",
//				[NSNumber numberWithLong:exportCD.componentType], @"type",
//				[NSNumber numberWithLong:exportCD.componentSubType], @"subtype",
//				[NSNumber numberWithLong:exportCD.componentManufacturer], @"manufacturer",
//				nil];
//			[array addObject:dictionary];
//			[nameStr release];
//			
//			NSLog( @"%@", [dictionary description]);
//		}
//		
//		DisposeHandle(name);
//	}
//	
//	return array;
//}

//- (NSData *)getExportSettings:(QTMovie*) aMovie component:(NSDictionary*) component
//{
//	Component c;
//	
//	memcpy(&c, [[component objectForKey:@"component"] bytes], sizeof(c));
//	
//	MovieExportComponent exporter = OpenComponent(c);
//	Boolean canceled;
//	
//	Movie theMovie = [aMovie quickTimeMovie] ;
//	TimeValue duration = GetMovieDuration(theMovie) ;
//	
//	ComponentResult err;
//	
//	NSString	*prefString = [NSString stringWithFormat:@"Quicktime Export:%d", [[component valueForKey:@"subtype"] unsignedLongValue]];
//	NSLog( @"%@", prefString);
//	
//	NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey: prefString];
//	char	*ptr = (char*) [data bytes];
//	
//	if( data) MovieExportSetSettingsFromAtomContainer (exporter, &ptr);
//	
//	err = MovieExportDoUserDialog(exporter, theMovie, NULL, 0, duration, &canceled);
//	if(err)
//	{
//		NSLog(@"Got error %d when calling MovieExportDoUserDialog", (int) err);
//		CloseComponent(exporter);
//		return nil;
//	}
//	if(canceled)
//	{
//		CloseComponent(exporter);
//		return nil;
//	}
//	
//	QTAtomContainer settings;
//	err = MovieExportGetSettingsAsAtomContainer(exporter, &settings);
//	if(err)
//	{
//		NSLog(@"Got error %d when calling MovieExportGetSettingsAsAtomContainer", (int) err);
//		CloseComponent(exporter);
//		return nil;
//	}
//	
//	data = [NSData dataWithBytes:*settings length:GetHandleSize(settings)];	
//	[[NSUserDefaults standardUserDefaults] setObject:data forKey: prefString];
//	
//	DisposeHandle(settings);
//
//	CloseComponent(exporter);
//	
//	return data;
//}
#else
//- (NSArray *)availableComponents
//{
//	NSMutableArray *array = [NSMutableArray array];
//	NSDictionary *dictionary = nil;
//	
//	dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
//		[NSString stringWithString: @"Quicktime Movie"], @"name",
//		[NSNumber numberWithLong: kQTFileTypeMovie], @"subtype",
//		[NSNumber numberWithLong: kAppleManufacturer], @"manufacturer",
//		nil];
//	[array addObject:dictionary];
//
//	if( selector != @selector(imageForFrameVR: maxFrame:))		// QTVR is limited to Quicktime file format !
//	{
//		dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
//			[NSString stringWithString: @"MPEG4 Movie"], @"name",
//			[NSNumber numberWithLong: kQTFileTypeMP4], @"subtype",
//			[NSNumber numberWithLong: kAppleManufacturer], @"manufacturer",
//			nil];
//		[array addObject:dictionary];
//
//		dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
//			[NSString stringWithString: @"AVI Movie"], @"name",
//			[NSNumber numberWithLong: kQTFileTypeAVI], @"subtype",
//			[NSNumber numberWithLong: kAppleManufacturer], @"manufacturer",
//			nil];
//		[array addObject:dictionary];
//	}
//	
//	return array;
//}

//- (NSData *)getExportSettings:(QTMovie*) aMovie component:(NSDictionary*) component
//{
//	// QTKit is currently very limited.... The only solution for 64-bit app -> 32-bit process. Is Apple really investing in Quicktime anymore ??
//    
//	NSString		*prefString = [NSString stringWithFormat:@"Quicktime Export:%d", [[component valueForKey:@"subtype"] unsignedLongValue]];
//	NSData			*data = nil;
//	NSTask			*theTask = [[NSTask alloc] init];
//	
//	NSImage *frame = nil;
//	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool:YES], QTMovieExport,
//			[NSNumber numberWithBool:YES], QTMovieFlatten,
//			nil];
//	
//	[aMovie writeToFile: @"/tmp/QTExportOsiriX64bits-Movie" withAttributes: attributes];
//	
//    if( aMovie == nil)
//        NSLog( @"****** aMovie == nil - QuicktimeExport getExportSettings");
//    
//	NSString	*tempComponentPath = [NSString stringWithString:@"/tmp/QTExportOsiriX64bits-Component"];
//	[[NSFileManager defaultManager] removeFileAtPath: tempComponentPath handler: nil];
//	[component writeToFile: tempComponentPath atomically: YES];
//	
//	NSString	*tempDataPath = [NSString stringWithString:@"/tmp/QTExportOsiriX64bits-DataIN"];
//	[[NSFileManager defaultManager] removeFileAtPath: tempDataPath handler: nil];
//	[[[NSUserDefaults standardUserDefaults] dataForKey: prefString] writeToFile: tempDataPath atomically: YES];
//	
//	NSString	*tempDataPathOUT = [NSString stringWithString:@"/tmp/QTExportOsiriX64bits-DataOUT"];
//	[[NSFileManager defaultManager] removeFileAtPath: tempDataPathOUT handler: nil];
//	
//	[theTask setArguments: [NSArray arrayWithObjects:@"getExportSettings", @"/tmp/QTExportOsiriX64bits-Movie", tempComponentPath, tempDataPath, tempDataPathOUT, nil]];
//	
//	NSString	*stringPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"/32-bit shell.app/Contents/MacOS/32-bit shell"];
//	if( [[NSFileManager defaultManager] fileExistsAtPath: stringPath])
//	{
//		[theTask setLaunchPath: stringPath];
//		[theTask launch];
//		[theTask waitUntilExit];
//		
//		data = [NSData dataWithContentsOfFile: tempDataPathOUT];
//		if( data)
//		{
//			[[NSUserDefaults standardUserDefaults] setObject:data forKey: prefString];
//		}
//	}
//	
//	[theTask release];
//	
//    [[NSFileManager defaultManager] removeFileAtPath: @"/tmp/QTExportOsiriX64bits-Movie" handler: nil];
//    [[NSFileManager defaultManager] removeFileAtPath: @"/tmp/QTExportOsiriX64bits-DataIN" handler: nil];
//    [[NSFileManager defaultManager] removeFileAtPath: @"/tmp/QTExportOsiriX64bits-DataOUT" handler: nil];
//    [[NSFileManager defaultManager] removeFileAtPath: @"/tmp/QTExportOsiriX64bits-Component" handler: nil];
//    
//	return data;
//}
#endif

//- (BOOL) writeMovie:(QTMovie *)movie toFile:(NSString *)file withComponent:(NSDictionary *)component withExportSettings:(NSData *)exportSettings
//{
//	NSDictionary *attributes = nil;
//	
//	if( component && exportSettings)
//	{
//		attributes = [NSDictionary dictionaryWithObjectsAndKeys:
//			[NSNumber numberWithBool:YES], QTMovieExport,
//			[component objectForKey:@"subtype"], QTMovieExportType,
//			[component objectForKey:@"manufacturer"], QTMovieExportManufacturer,
//			exportSettings, QTMovieExportSettings,
//			nil];
//	}
//	else
//	{
//		attributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]  forKey:QTMovieFlatten];
//	}
//	
//	WaitRendering *wait = [[WaitRendering alloc] init: NSLocalizedString(@"Movie encoding...", nil)];
//	[wait showWindow:self];
//	
//	BOOL result = [movie writeToFile:file withAttributes:attributes];
//	if( !result) NSLog(@"Couldn't write movie to file");
//	
//	[wait close];
//	[wait release];
//	
//	return YES;
//}

//- (IBAction) changeExportType:(id) sender
//{
//	if( [exportTypes count])
//	{
//		NSInteger indexOfSelectedItem = [type indexOfSelectedItem];
//	
//		unsigned int subtype = [[[exportTypes objectAtIndex: indexOfSelectedItem] valueForKey:@"subtype"] unsignedIntValue];
//		
//		if( subtype == kQTFileTypeMovie)  [panel setRequiredFileType:@"mov"];
//		if( subtype == kQTFileTypeAVI)	[panel setRequiredFileType:@"avi"];
//		if( subtype == kQTFileTypeMP4)	[panel setRequiredFileType:@"mpg4"];
//		if( subtype == 'ASF_')	[panel setRequiredFileType:@"wmv"];
//		
//		[[NSUserDefaults standardUserDefaults] setInteger:indexOfSelectedItem forKey:@"selectedMenuQuicktimeExport"];
//	}
//}

- (NSString*) createMovieQTKit:(BOOL) openIt :(BOOL) produceFiles :(NSString*) name
{
    return [self createMovieQTKit:openIt :produceFiles :name :0];
}

- (CVPixelBufferRef) CVPixelBufferFromNSImage:(NSImage *)image
{
    CVPixelBufferRef buffer = NULL;
    
    // config
    size_t width = [image size].width;
    size_t height = [image size].height;
    size_t bitsPerComponent = 8;
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGBitmapInfo bi = kCGImageAlphaNoneSkipFirst;
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey, [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
    
    // create pixel buffer
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, k32ARGBPixelFormat, (CFDictionaryRef)d, &buffer);
    CVPixelBufferLockBaseAddress(buffer, 0);
    void *rasterData = CVPixelBufferGetBaseAddress(buffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    
    // context to draw in, set to pixel buffer's address
    CGContextRef ctxt = CGBitmapContextCreate(rasterData, width, height, bitsPerComponent, bytesPerRow, cs, bi);
    if(ctxt == NULL)
    {
        NSLog(@"could not create context");
        return NULL;
    }
    
    // draw
    NSGraphicsContext *nsctxt = [NSGraphicsContext graphicsContextWithGraphicsPort:ctxt flipped:NO];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsctxt];
    [image compositeToPoint:NSMakePoint(0.0, 0.0) operation:NSCompositeCopy];
    [NSGraphicsContext restoreGraphicsState];
    
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    CFRelease(ctxt);
    
    return buffer;
}

- (NSString*) createMovieQTKit:(BOOL) openIt :(BOOL) produceFiles :(NSString*) name :(NSInteger)fps
{
    if (fps > 0)
        [[NSUserDefaults standardUserDefaults] setInteger:fps forKey:@"quicktimeExportRateValue"];

	NSString *fileName;
	long result;

//	exportTypes = [self availableComponents];
	
	panel = [NSSavePanel savePanel];
	
    [[NSFileManager defaultManager] createDirectoryAtPath: [[[BrowserController currentBrowser] documentsDirectory] stringByAppendingFormat:@"/TEMP.noindex/"]  withIntermediateDirectories: YES attributes: nil error: nil];
    
	if( produceFiles)
	{
		result = NSFileHandlingPanelOKButton;
		
		[[NSFileManager defaultManager] removeFileAtPath: [[[[BrowserController currentBrowser] database] tempDirPath] stringByAppendingPathComponent:@"IPHOTO"] handler: nil];
		[[NSFileManager defaultManager] createDirectoryAtPath: [[[[BrowserController currentBrowser] database] tempDirPath] stringByAppendingPathComponent:@"IPHOTO"] withIntermediateDirectories: YES attributes: nil error: nil];
		
		fileName = [[[[BrowserController currentBrowser] database] tempDirPath] stringByAppendingPathComponent:@"OsiriXMovie.mov"];
	}
	else
	{
		[panel setCanSelectHiddenExtension:YES];
		[panel setRequiredFileType:@"mov"];
		
		[panel setAccessoryView: view];
		[type removeAllItems];
		
//		if( [exportTypes count])
//			[type addItemsWithTitles: [exportTypes valueForKey: @"name"]];
		
		[type selectItemAtIndex: [[NSUserDefaults standardUserDefaults] integerForKey:@"selectedMenuQuicktimeExport"]];
		if( [type indexOfSelectedItem] == -1) [type selectItemAtIndex: 0];
		
//		[self changeExportType: self];
		
		result = [panel runModalForDirectory:nil file:name];
		
		fileName = [panel filename];
	}
	
	if( result == NSFileHandlingPanelOKButton)
	{
//        if( 1)
        {
            // Set the frameDuration ivar (50/600 = 1 sec / 12 number of frames)
            CMTime frameDuration = CMTimeMake(50, 600);
            static CMTime nextPresentationTimeStamp;
            
            nextPresentationTimeStamp = kCMTimeZero;
            
            NSError *error = nil;
            AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath: fileName] fileType: AVFileTypeQuickTimeMovie error:&error];
            if (!error)
            {
                NSImage	*firstImage = [object performSelector: selector withObject: [NSNumber numberWithLong: 0] withObject:[NSNumber numberWithLong: numberOfFrames]]; 
                
                NSLog( @"width: %f height: %f", firstImage.size.width, firstImage.size.height);
                
                // Define video settings to be passed to the AVAssetWriterInput instance
                NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                               AVVideoCodecJPEG, AVVideoCodecKey, 
                                               [NSNumber numberWithInt: firstImage.size.width], AVVideoWidthKey, 
                                               [NSNumber numberWithInt: firstImage.size.height], AVVideoHeightKey, nil];
                // Instanciate the AVAssetWriterInput
                AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
                // Instanciate the AVAssetWriterInputPixelBufferAdaptor to be connected to the writer input
                AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:nil];
                // Add the writer input to the writer and begin writing
                [writer addInput:writerInput];
                [writer startWriting];
                [writer startSessionAtSourceTime:nextPresentationTimeStamp];
                
                
                Wait *wait = [[[Wait alloc] initWithString: NSLocalizedString( @"Movie Export", nil)] autorelease];
                [wait showWindow:self];
                [wait setCancel:YES];
                [[wait progress] setMaxValue: numberOfFrames];
                
                dispatch_queue_t mediaDataRequestQueue = dispatch_queue_create("Media data request queue", NULL);
                
                static int curSample;
                
                curSample = 0;
                
                [writerInput requestMediaDataWhenReadyOnQueue:mediaDataRequestQueue usingBlock:^{
                    while (writerInput.isReadyForMoreMediaData)
                    {
                        CVPixelBufferRef buffer = nil;
                        
                        if( curSample < numberOfFrames)
                        {
                            NSLog( @"AVAssetWriter frame: %d", curSample);
                            
                            NSDisableScreenUpdates();
                            @synchronized( self)
                            {
                                NSImage	*im = [object performSelector: selector withObject: [NSNumber numberWithLong: curSample++] withObject:[NSNumber numberWithLong: numberOfFrames]];    
                                
                                buffer = [self CVPixelBufferFromNSImage: im];
                            }
                            NSEnableScreenUpdates();
                        }
                        
                        if (buffer)
                        {
                            CVPixelBufferLockBaseAddress(buffer, 0);
                            [pixelBufferAdaptor appendPixelBuffer:buffer withPresentationTime:nextPresentationTimeStamp];
                            CVPixelBufferUnlockBaseAddress(buffer, 0);
                            CVPixelBufferRelease(buffer);
                            buffer = nil;
                            
                            nextPresentationTimeStamp = CMTimeAdd(nextPresentationTimeStamp, frameDuration);
                            
                            CVPixelBufferRelease(buffer);                    
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [wait incrementBy:1];
                                
                                if( [wait aborted])
                                    curSample = numberOfFrames;
                            });
                        }
                        else
                        {
                            [writerInput markAsFinished];
                            [writer finishWriting];
                            curSample = numberOfFrames;
                            dispatch_release(mediaDataRequestQueue);
                            break;
                        }
                    }
                }];
                
                while( curSample < numberOfFrames)
                    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];
                
                dispatch_sync( mediaDataRequestQueue, ^{});
                
                [wait close];
                
                return fileName;
            }
        }
//        else
//        {
//            int				maxImage, curSample = 0;
//            QTTime			curTime;
//            QTMovie			*mMovie = nil;
//            BOOL			aborted = NO;
//            
//            if( produceFiles == NO)
//            {
//                [[QTMovie movie] writeToFile: [fileName stringByAppendingString:@"temp"] withAttributes: nil];
//                
//                mMovie = [QTMovie movieWithFile:[fileName stringByAppendingString:@"temp"] error:nil];
//                [mMovie setAttribute:[NSNumber numberWithBool:YES] forKey:QTMovieEditableAttribute];
//                
//                long long timeValue = 600 / [[NSUserDefaults standardUserDefaults] integerForKey:@"quicktimeExportRateValue"];
//                long timeScale = 600;
//                
//                curTime = QTMakeTime(timeValue, timeScale);
//            }
//            
//            Wait    *wait = [[Wait alloc] initWithString: NSLocalizedString( @"Movie Export", nil) ];
//            [wait showWindow:self];
//            
//            // For each sample...
//            maxImage = numberOfFrames;
//            
//            [wait setCancel:YES];
//            [[wait progress] setMaxValue:maxImage];
//            //ImageCompression.h QTAddImageCodecType
//            NSDictionary *myDict = [NSDictionary dictionaryWithObjectsAndKeys: @"jpeg", QTAddImageCodecType, [NSNumber numberWithInt: codecHighQuality], QTAddImageCodecQuality, nil];	//qdrw , tiff, jpeg
//            
//            for (curSample = 0; curSample < maxImage; curSample++) 
//            {
//                NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
//                
//                [wait incrementBy:1];
//                
//                NSDisableScreenUpdates();
//                
//                NSImage	*im = [object performSelector: selector withObject: [NSNumber numberWithLong: curSample] withObject:[NSNumber numberWithLong: numberOfFrames]];
//                
//                if( im)
//                {
//                    if( produceFiles == NO)
//                    {
//                        [mMovie addImage:im forDuration:curTime withAttributes: myDict];
//                    }
//                    else
//                    {
//                        NSString *curFile = [[[[[BrowserController currentBrowser] database] tempDirPath] stringByAppendingPathComponent:@"IPHOTO"] stringByAppendingPathComponent:[NSString stringWithFormat:@"OsiriX-%4d.jpg", curSample]];
//                        
//                        NSData *bitmapData = [NSBitmapImageRep representationOfImageRepsInArray: [im representations] usingType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSDecimalNumber numberWithFloat:0.9] forKey:NSImageCompressionFactor]];
//                        [bitmapData writeToFile:curFile atomically:YES];
//                    }
//                }
//                
//                if( [wait aborted])
//                {
//                    curSample = maxImage;
//                    aborted = YES;
//                }
//                
//                NSEnableScreenUpdates();
//                
//                [pool release];
//            }
//            [wait close];
//            [wait release];
//            
//            // Go back to initial frame
//            [object performSelector: selector withObject: [NSNumber numberWithLong: 0] withObject:[NSNumber numberWithLong: numberOfFrames]];
//            
//            if( produceFiles == NO && aborted == NO)
//            {
//                [[NSFileManager defaultManager] removeFileAtPath:fileName handler:nil];
//                
//                if( aborted == NO)
//                {
//                    NSData	*exportSettings = nil;
//                    id		component = nil;
//                    
//                    if( [exportTypes count])
//                    {
//                        exportSettings = [self getExportSettings: mMovie component: [exportTypes objectAtIndex: [type indexOfSelectedItem]]];
//                        component = [exportTypes objectAtIndex: [type indexOfSelectedItem]];
//                    }
//                    
//                    [self writeMovie:mMovie toFile:fileName withComponent: component withExportSettings: exportSettings];
//                    
//                    if( openIt)
//                    {
//                        NSWorkspace *ws = [NSWorkspace sharedWorkspace];
//                        [ws openFile:fileName];
//                    }
//                }
//            }
//            
//            [[NSFileManager defaultManager] removeFileAtPath:[fileName stringByAppendingString:@"temp"] handler:nil];
//            
//            if( aborted == NO)
//                return fileName;
//        }
	}
	
	return nil;
}

@end
