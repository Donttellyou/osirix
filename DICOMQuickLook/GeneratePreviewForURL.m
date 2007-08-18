#import <Cocoa/Cocoa.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <QuickLook/QuickLook.h>

#import "DCMPix.h"
#import "dicomFile.h"

static PapyInitDone = NO;

NSString* stringFromData( NSString *a, NSString *b)
{
	if( [a isEqualTo:@""]) a = 0L;
	if( [b isEqualTo:@""]) b = 0L;
	if( a && b) return [NSString stringWithFormat:@" %@ - %@", a, b];
	if( a) return [NSString stringWithFormat:@" %@", a];
	if( b) return [NSString stringWithFormat:@" %@", b];
	return @"";
}

void drawTextualData(NSString* path, float width) 
{
	DicomFile	*file = [[DicomFile alloc] init: path];
		   
	if( file)
	{
		NSDateFormatter		*date = [[[NSDateFormatter alloc] init] autorelease];
		[date setDateStyle: NSDateFormatterShortStyle];
		
		NSDateFormatter		*time = [[[NSDateFormatter alloc] init] autorelease];
		[time setTimeStyle: NSDateFormatterShortStyle];
		
		NSShadow	*shadow = [[[NSShadow alloc] init] autorelease];
		[shadow setShadowColor: [NSColor blackColor]];
		[shadow setShadowOffset: NSMakeSize(-2, -2)];
		[shadow setShadowBlurRadius: 4];
		
		float fontSize = 14.*width/512.;
//		if( fontSize < 10) fontSize = 10;
		
		NSDictionary	*attributes = [NSDictionary dictionaryWithObjectsAndKeys: shadow, NSShadowAttributeName, [NSFont fontWithName:@"Helvetica" size:fontSize], NSFontAttributeName, [NSColor whiteColor], NSForegroundColorAttributeName, 0L];
		
		NSMutableString	*text = [NSMutableString string];
		
		[text appendString: stringFromData( [file elementForKey:@"patientName"], [date stringFromDate: [file elementForKey:@"patientBirthDate"]])];
		[text appendString: @"\r"];
		[text appendString: stringFromData( [file elementForKey:@"accessionNumber"], [file elementForKey:@"patientID"])];
		[text appendString: @"\r"];
		
		NSString *s = 0L;
		if( [file elementForKey:@"studyDate"]) s = [NSString stringWithFormat: @"%@ / %@", [date stringFromDate: [file elementForKey:@"studyDate"]], [time stringFromDate: [file elementForKey:@"studyDate"]]];
		[text appendString: stringFromData( [file elementForKey:@"studyDescription"], s)];
		
		[text drawAtPoint: NSMakePoint(0, 0) withAttributes: attributes];
		
		[file release];
	}
}

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	if( PapyInitDone == NO)
	{
		PapyInitDone = YES;
		Papy3Init();
	}
	
	NSURL *nsurl = (NSURL*) url;
	
	DCMPix	*pix = [[DCMPix alloc] myinit:[nsurl path] :0 :1 :0L :0 :0];
	[pix CheckLoad];
	[pix changeWLWW:[pix savedWL] :[pix savedWW]];
	NSImage *image = [pix image];
	
	NSSize canvasSize = [image size];
	
	if( canvasSize.width != maxSize.width)
	{
		float ratio = maxSize.width / canvasSize.width;
		
		canvasSize.width *= ratio;
		canvasSize.height *= ratio;
	}
	
	if( canvasSize.height > maxSize.height)
	{
		float ratio = maxSize.height / canvasSize.height;
		
		canvasSize.width *= ratio;
		canvasSize.height *= ratio;
	}
	 
    CGContextRef cgContext = QLThumbnailRequestCreateContext(thumbnail, *(CGSize *)&canvasSize, true, NULL);
    if(cgContext) {
        NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)cgContext flipped:NO];
        if(context) {
			[NSGraphicsContext setCurrentContext: context];
            [context setImageInterpolation: NSImageInterpolationHigh];
		   [image setScalesWhenResized: YES];
		   [image setSize: canvasSize];
           [image drawAtPoint: NSMakePoint(0, 0) fromRect: NSMakeRect(0, 0, canvasSize.width, canvasSize.height) operation:NSCompositeCopy fraction:1.0];
			
			drawTextualData( [nsurl path], [image size].width);
        }
        QLThumbnailRequestFlushContext(thumbnail, cgContext);
        CFRelease(cgContext);
    }
	
	[pix release];
    [pool release];
	
    return noErr;
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	if( PapyInitDone == NO)
	{
		PapyInitDone = YES;
		Papy3Init();
	}
	
	NSURL *nsurl = (NSURL*) url;

	DCMPix	*pix = [[DCMPix alloc] myinit:[nsurl path] :0 :1 :0L :0 :0];
	[pix CheckLoad];
	[pix changeWLWW:[pix savedWL] :[pix savedWW]];
	NSImage *image = [pix image];
	
	NSSize canvasSize = [image size];
	
	if( canvasSize.width < 1024)
	{
		float ratio = 1024 / canvasSize.width;
		
		canvasSize.width *= ratio;
		canvasSize.height *= ratio;
	}
	
    CGContextRef cgContext = QLPreviewRequestCreateContext(preview, *(CGSize *)&canvasSize, true, NULL);
    if(cgContext)
	{
        NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)cgContext flipped:NO];
        if(context)
		{
		   [NSGraphicsContext setCurrentContext: context];
		   [context setImageInterpolation: NSImageInterpolationHigh];
		   [image setScalesWhenResized: YES];
		   [image setSize: canvasSize];
           [image drawAtPoint: NSMakePoint(0, 0) fromRect: NSMakeRect(0, 0, canvasSize.width, canvasSize.height) operation:NSCompositeCopy fraction:1.0];
		   
		   drawTextualData( [nsurl path], canvasSize.width);
        }
        QLPreviewRequestFlushContext(preview, cgContext);
        CFRelease(cgContext);
    }
	
	[pix release];
	
    [pool release];
	
    return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}
