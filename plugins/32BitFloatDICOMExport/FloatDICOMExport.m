//
//  FloatDICOMExport.m
//  FloatDICOMExport
//
//  Copyright (c) 2009 Antoine Rosset. All rights reserved.
//

#import "FloatDICOMExport.h"
#import "OsiriX/DCMObject.h"
#import "OsiriX/DCMTransferSyntax.h"
#import "DCMPix.h"

@implementation FloatDICOMExport

-(void) compress:(DCMTransferSyntax*) tsx quality: (int) quality fromFile: (NSString*) from toFile:(NSString*) dest 
{
	DCMObject *dcmObject = [[DCMObject alloc] initWithContentsOfFile: from decodingPixelData: NO];
	
	BOOL succeed = NO;
	
	@try
	{
		succeed = [dcmObject writeToFile: dest withTransferSyntax: tsx quality: quality AET:@"OsiriX" atomically:YES];
	}
	@catch (NSException *e)
	{
		NSLog( @"dcmObject writeToFile failed: %@", e);
	}
	[dcmObject release];
}

- (void) subtract: (float*) dest :(float*) mask :(long) size
{
	long s = size/sizeof(float);
	
	while( s-->0)
		*dest++ -= *mask++;
}

- (long) filterImage:(NSString*) menuName
{
	int newTotal;
	unsigned char *emptyData;
	ViewerController *new2DViewer;
	
	// Contains a list of DCMPix objects: they contain the pixels of current series
	NSArray *pixList = [viewerController pixList];	
	
	// Current image
	DCMPix *curPix = [pixList objectAtIndex: [[viewerController imageView] curImage]];
	
	if( [curPix isRGB])
	{
		NSRunAlertPanel(NSLocalizedString(@"RGB", nil), NSLocalizedString(@"This plugin is not compatible with RGB images.", nil), nil, nil, nil);
		return 0;
	}
	
	if( [curPix SUVConverted])
	{
		NSRunAlertPanel(NSLocalizedString(@"SUV", nil), NSLocalizedString(@"This plugin is not compatible with SUV converted images. Turn off SUV conversion to use it.", nil), nil, nil, nil);
		return 0;
	}
	
	// Export it in JPEG
	NSString *srcFile = [curPix sourceFile];
	NSString *destFile = @"/tmp/jpegtest";
	
	// Display a waiting window
	id waitWindow = [viewerController startWaitWindow:@"I'm working for you! FOR FREE !"];
	
	newTotal = 0;
	
	[[NSFileManager defaultManager] removeItemAtPath: [destFile stringByAppendingString: @".nocompression"] error: nil];
	[self compress: [DCMTransferSyntax ExplicitVRLittleEndianTransferSyntax] quality: 0 fromFile: srcFile toFile: [destFile stringByAppendingString: @".nocompression"]];
	newTotal++;
	
	[[NSFileManager defaultManager] removeItemAtPath: [destFile stringByAppendingString: @".jp2k-lossless"] error: nil];
	[self compress: [DCMTransferSyntax JPEG2000LosslessTransferSyntax] quality: 0 fromFile: srcFile toFile: [destFile stringByAppendingString: @".jp2k-lossless"]];
	newTotal++;
	
	[[NSFileManager defaultManager] removeItemAtPath: [destFile stringByAppendingString: @".jp2k-lossy-1"] error: nil];
	[self compress: [DCMTransferSyntax JPEG2000LossyTransferSyntax] quality: 1 fromFile: srcFile toFile: [destFile stringByAppendingString: @".jp2k-lossy-1"]];
	newTotal++;
	
	[[NSFileManager defaultManager] removeItemAtPath: [destFile stringByAppendingString: @".jp2k-lossy-2"] error: nil];
	[self compress: [DCMTransferSyntax JPEG2000LossyTransferSyntax] quality: 2 fromFile: srcFile toFile: [destFile stringByAppendingString: @".jp2k-lossy-2"]];
	newTotal++;
	
	[[NSFileManager defaultManager] removeItemAtPath: [destFile stringByAppendingString: @".jp2k-lossy-3"] error: nil];
	[self compress: [DCMTransferSyntax JPEG2000LossyTransferSyntax] quality: 3 fromFile: srcFile toFile: [destFile stringByAppendingString: @".jp2k-lossy-3"]];
	newTotal++;
	
//	[[NSFileManager defaultManager] removeItemAtPath: [destFile stringByAppendingString: @".jpeg-lossless"] error: nil];
//	[self compress: [DCMTransferSyntax JPEGLossless14TransferSyntax] quality: 0 fromFile: srcFile toFile: [destFile stringByAppendingString: @".jpeg-lossless"]];
//	newTotal++;
	
	// CREATE A NEW SERIES WITH ALL IMAGES, subtracted to the original image
	long imageSize = sizeof( float) * [curPix pwidth] * [curPix pheight];
	long size = newTotal * imageSize;
	
	emptyData = malloc( size);
	if( emptyData)
	{
		NSMutableArray	*newPixList = [NSMutableArray arrayWithCapacity: 0];
		NSMutableArray	*newDcmList = [NSMutableArray arrayWithCapacity: 0];
		
		NSData	*newData = [NSData dataWithBytesNoCopy:emptyData length: size freeWhenDone:YES];
		
		[newPixList addObject: [[[DCMPix alloc] initWithContentsOfFile: [destFile stringByAppendingString: @".nocompression"]] autorelease]];
		[[newPixList lastObject] setTot: newTotal];
		[[newPixList lastObject] setFrameNo: [newPixList count]-1];
		[newDcmList addObject: [[viewerController fileList] objectAtIndex: [[viewerController imageView] curImage]]];
		
		[newPixList addObject: [[[DCMPix alloc] initWithContentsOfFile: [destFile stringByAppendingString: @".jp2k-lossless"]] autorelease]];
		[[newPixList lastObject] setTot: newTotal];
		[[newPixList lastObject] setFrameNo: [newPixList count]-1];
		[newDcmList addObject: [[viewerController fileList] objectAtIndex: [[viewerController imageView] curImage]]];
		
		[newPixList addObject: [[[DCMPix alloc] initWithContentsOfFile: [destFile stringByAppendingString: @".jp2k-lossy-1"]] autorelease]];
		[[newPixList lastObject] setTot: newTotal];
		[[newPixList lastObject] setFrameNo: [newPixList count]-1];
		[newDcmList addObject: [[viewerController fileList] objectAtIndex: [[viewerController imageView] curImage]]];
		
		[newPixList addObject: [[[DCMPix alloc] initWithContentsOfFile: [destFile stringByAppendingString: @".jp2k-lossy-2"]] autorelease]];
		[[newPixList lastObject] setTot: newTotal];
		[[newPixList lastObject] setFrameNo: [newPixList count]-1];
		[newDcmList addObject: [[viewerController fileList] objectAtIndex: [[viewerController imageView] curImage]]];
		
		[newPixList addObject: [[[DCMPix alloc] initWithContentsOfFile: [destFile stringByAppendingString: @".jp2k-lossy-3"]] autorelease]];
		[[newPixList lastObject] setTot: newTotal];
		[[newPixList lastObject] setFrameNo: [newPixList count]-1];
		[newDcmList addObject: [[viewerController fileList] objectAtIndex: [[viewerController imageView] curImage]]];
		
		float ww = 0;
		
		for( DCMPix *p in newPixList)
		{
			[p CheckLoad];
			[self subtract: p.fImage :curPix.fImage :imageSize];
			
			[p computePixMinPixMax];
			
			if( [p fullww] > ww)
				ww = [p fullww];
		}
		
		// CREATE A SERIES
		new2DViewer = [viewerController newWindow :newPixList :newDcmList :newData];
		
		[new2DViewer roiDeleteAll: self];
		[new2DViewer setWL:0 WW: ww];
		
		int i;
		for( i = 0 ; i < newTotal ; i++)
		{
			NSMutableArray  *roiSeriesList;
			NSMutableArray  *roiImageList;
			ROI				*newROI;
			
			// All rois contained in the current series
			roiSeriesList = [new2DViewer roiList];
			
			// All rois contained in the current image
			roiImageList = [roiSeriesList objectAtIndex: i];
			
			newROI = [new2DViewer newROI: tText];
			
			float fileSize, originalSize = [[NSData dataWithContentsOfFile: [destFile stringByAppendingString: @".nocompression"]] length];
			NSString *s = nil;
			
			switch( i)
			{
				case 0: fileSize = [[NSData dataWithContentsOfFile: [destFile stringByAppendingString: @".nocompression"]] length];	s = [NSString stringWithFormat:@"%@ ratio: %2.2fx - %2.0f Kb / %2.0f Kb", @"no compression", originalSize / fileSize, fileSize / 1024., originalSize / 1024.]; break;
				case 1: fileSize = [[NSData dataWithContentsOfFile: [destFile stringByAppendingString: @".jp2k-lossless"]] length];	s = [NSString stringWithFormat:@"%@ ratio: %2.2fx - %2.0f Kb / %2.0f Kb", @"jp2k-lossless", originalSize / fileSize, fileSize / 1024., originalSize / 1024.]; break;
				case 2: fileSize = [[NSData dataWithContentsOfFile: [destFile stringByAppendingString: @".jp2k-lossy-1"]] length];	s = [NSString stringWithFormat:@"%@ ratio: %2.2fx - %2.0f Kb / %2.0f Kb", @"jp2k-lossy-1", originalSize / fileSize, fileSize / 1024., originalSize / 1024.];	break;
				case 3: fileSize = [[NSData dataWithContentsOfFile: [destFile stringByAppendingString: @".jp2k-lossy-2"]] length];	s = [NSString stringWithFormat:@"%@ ratio: %2.2fx - %2.0f Kb / %2.0f Kb", @"jp2k-lossy-2", originalSize / fileSize, fileSize / 1024., originalSize / 1024.];	break;
				case 4: fileSize = [[NSData dataWithContentsOfFile: [destFile stringByAppendingString: @".jp2k-lossy-3"]] length];	s = [NSString stringWithFormat:@"%@ ratio: %2.2fx - %2.0f Kb / %2.0f Kb", @"jp2k-lossy-3", originalSize / fileSize, fileSize / 1024., originalSize / 1024.];	break;
			}
			
			[newROI setName: s];
			
			NSRect r = [newROI rect];
			
			r.origin.x = [curPix pwidth]/2.;
			r.origin.y = [curPix pheight]/2.;
			
			newROI.rect = r;
			
			[roiImageList addObject: newROI];
			
			////
			
			newROI = [new2DViewer newROI: tROI];
			
			r = [newROI rect];
			
			r.origin.x = 0;
			r.origin.y = 0;
			r.size.width = [curPix pwidth];
			r.size.height = [curPix pheight];
			
			newROI.rect = r;
			
			[roiImageList addObject: newROI];
		}
				
		[new2DViewer needsDisplayUpdate];
	}
	
	// Close the waiting window
	[viewerController endWaitWindow: waitWindow];
	
	// We modified the pixels: OsiriX please update the display!
	[viewerController needsDisplayUpdate];
	
	return 0;   // No Errors
}

@end
