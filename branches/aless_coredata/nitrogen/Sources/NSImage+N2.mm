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


#import "NSImage+N2.h"
#include <algorithm>
#import <Accelerate/Accelerate.h>
//#include <boost/numeric/ublas/matrix.hpp>
//#include <fftw3.h>
//#include <complex>
#import "N2Operators.h"
#import "NSColor+N2.h"
#import <QuartzCore/QuartzCore.h>

@implementation N2Image
@synthesize inchSize = _inchSize, portion = _portion;

-(id)initWithContentsOfFile:(NSString*)path {
	self = [super initWithContentsOfFile:path];
	NSSize size = [self size];
	_inchSize = NSMakeSize(size.width/72, size.height/72);
	_portion.size = NSMakeSize(1,1);
	return self;
}

-(id)initWithSize:(NSSize)size inches:(NSSize)inches {
	self = [super initWithSize:size];
	_inchSize = inches;
	return self;
}

-(id)initWithSize:(NSSize)size inches:(NSSize)inches portion:(NSRect)portion {
	self = [self initWithSize:size inches:inches];
	_portion = portion;
	return self;
}

-(NSSize)originalInchSize {
	return _inchSize/_portion.size;
}

-(NSPoint)convertPointFromPageInches:(NSPoint)p {
	return (p-_portion.origin*[self originalInchSize])*[self resolution];
}

-(void)setSize:(NSSize)size {
	NSSize oldSize = [self size];
	if (![self scalesWhenResized])
		_inchSize = NSMakeSize(_inchSize.width/oldSize.width*size.width, _inchSize.height/oldSize.height*size.height);
	[super setSize:size];
}

-(N2Image*)crop:(NSRect)cropRect {
	NSSize size = [self size];
	
	NSRect portion;
	portion.size = _portion.size*(cropRect.size/size);// NSMakeSize(_portion.size.width*(cropRect.size.width/size.width), _portion.size.height*(cropRect.size.height/size.height));
	portion.origin = _portion.origin+_portion.size*(cropRect.origin/size);//, _portion.origin.y+_portion.size.height*(cropRect.origin.y/size.height));
	
	N2Image* croppedImage = [[N2Image alloc] initWithSize:cropRect.size inches:NSMakeSize(_inchSize.width/size.width*cropRect.size.width, _inchSize.height/size.height*cropRect.size.height) portion:portion];
	
	[croppedImage lockFocus];
	[self compositeToPoint:NSZeroPoint fromRect:cropRect operation:NSCompositeSourceOver fraction:0];
	[croppedImage unlockFocus];
	
	return [croppedImage autorelease];
}

-(float)resolution {
	NSSize size = [self size];
	return (size.width+size.height)/(_inchSize.width+_inchSize.height);
}

@end


@implementation NSImage (N2)

-(NSImage*)shadowImage {
	NSUInteger w = self.size.width, h = self.size.height;
	NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithData:[self TIFFRepresentation]];
	
	for (NSUInteger y = 0; y < h; ++y)
		for (NSUInteger x = 0; x < w; ++x) {
			NSColor* c = [bitmap colorAtX:x y:y];
			c = [c shadowWithLevel:[c alphaComponent]/4];
			[bitmap setColor:c atX:x y:y];
		}
	
	NSImage* dark = [[NSImage alloc] initWithSize:[self size]];
	[dark lockFocus];
	[bitmap draw]; [bitmap release];
	[dark unlockFocus];
	return [dark autorelease];
}

- (void)flipImageHorizontally {
	// dimensions
	NSSize size = [self size];
	// bitmap init
	NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithData:[self TIFFRepresentation]];
	// flip
	vImage_Buffer src, dest;
	src.height = dest.height = size.height;
	src.width = dest.width = size.width;
	src.rowBytes = dest.rowBytes = [bitmap bytesPerRow];
	src.data = dest.data = [bitmap bitmapData];
	vImageHorizontalReflect_ARGB8888(&src, &dest, 0L);
	// draw
	[self lockFocus];
	[bitmap draw];
	[self unlockFocus];
	// release
	[bitmap release];
}

-(NSRect)boundingBoxSkippingColor:(NSColor*)color inRect:(NSRect)box {
	if (box.size.width < 0) {
		box.origin.x += box.size.width;
		box.size.width = -box.size.width;
	}
	if (box.size.height < 0) {
		box.origin.y += box.size.height;
		box.size.height = -box.size.height;
	}
	
	NSSize size = [self size];
	
	if (box.origin.x < 0) {
		box.size.width += box.origin.x;
		box.origin.x = 0;
	}
	if (box.origin.y < 0) {
		box.size.height += box.origin.y;
		box.origin.y = 0;
	}
	if (box.origin.x+box.size.width > size.width)
		box.size.width = size.width-box.origin.x;
	if (box.origin.y+box.size.height > size.height)
		box.size.height = size.height-box.origin.y;
	
//	if (![self isFlipped])
		box.origin.y = size.height-box.origin.y-box.size.height;
	
	NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithData:[self TIFFRepresentation]];
	uint8* data = [bitmap bitmapData];
	
	if ([color colorSpaceName] != NSCalibratedRGBColorSpace)
		color = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSInteger componentsCount = [color numberOfComponents];
	CGFloat components[componentsCount];
	[color getComponents:components];
	
	const size_t rowBytes = [bitmap bytesPerRow], pixelBytes = [bitmap bitsPerPixel]/8;
#define P(x,y) (y*rowBytes+x*pixelBytes)

	int x, y;
#define Match(x,y) ( (data[P(x,y)] == data[P(x,y)+3]*components[0]) && (data[P(x,y)+1] == data[P(x,y)+3]*components[1]) && (data[P(x,y)+2] == data[P(x,y)+3]*components[2]) )
	
	// change origin.x
	for (x = box.origin.x; x < box.origin.x+box.size.width; ++x)
		for (y = box.origin.y; y <= box.origin.y+box.size.height; ++y)
			if (!Match(x,y))
				goto end_origin_x;
end_origin_x:
	if (x < box.origin.x+box.size.width) {
		box.size.width -= x-box.origin.x;
		box.origin.x = x;
	}
	
	// change origin.y
	for (y = box.origin.y; y < box.origin.y+box.size.height; ++y)
		for (x = box.origin.x; x <= box.origin.x+box.size.width; ++x)
			if (!Match(x,y))
				goto end_origin_y;
end_origin_y:
	if (y < box.origin.y+box.size.height) {
		box.size.height -= y-box.origin.y;
		box.origin.y = y;
	}
	
	// change size.width
	for (x = box.origin.x+box.size.width-1; x >= box.origin.x; --x)
		for (y = box.origin.y; y <= box.origin.y+box.size.height; ++y)
			if (!Match(x,y))
				goto end_size_x;
end_size_x:
	if (x >= box.origin.x)
		box.size.width = x-box.origin.x+1;
	
	// change size.height
	for (y = box.origin.y+box.size.height-1; y >= box.origin.y; --y)
		for (x = box.origin.x; x <= box.origin.x+box.size.width; ++x)
			if (!Match(x,y))
				goto end_size_y;
end_size_y:
	if (y >= box.origin.y)
		box.size.height = y-box.origin.y+1;
	
	[bitmap release];
	
	//if (![self isFlipped])
		box.origin.y = size.height-box.origin.y-box.size.height;
	
	return box;
	
#undef Match
#undef P
}

-(NSRect)boundingBoxSkippingColor:(NSColor*)color {
	NSSize imageSize = [self size];
	return [self boundingBoxSkippingColor:color inRect:NSMakeRect(0, 0, imageSize.width, imageSize.height)];
}

-(NSImage*)imageWithHue:(CGFloat)hue {
	NSImageRep *rep = [NSCIImageRep imageRepWithCIImage: [[CIFilter filterWithName:@"CIHueAdjust" keysAndValues:@"inputAngle", [NSNumber numberWithFloat: hue*2*M_PI] , @"inputImage", [CIImage imageWithData:[self TIFFRepresentation]], nil] valueForKey:@"outputImage"]];
	NSImage *image = [[NSImage alloc] initWithSize:[rep size]];
	[image addRepresentation:rep];
	return [image autorelease];
}

-(NSSize)sizeByScalingProportionallyToSize:(NSSize)targetSize {
	NSSize imageSize = self.size;
	if (NSEqualSizes(imageSize, targetSize))
		return targetSize;
	return imageSize * MIN(targetSize.width/imageSize.width, targetSize.height/imageSize.height);
}

- (NSImage*)imageByScalingProportionallyToSize:(NSSize)targetSize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSImage* sourceImage = self;
	NSImage* newImage = nil;
	
	@synchronized( [NSImage class])
	{
		if( [sourceImage isValid])
		{
			NSSize imageSize = [sourceImage size];
			float width  = imageSize.width;
			float height = imageSize.height;
			
			if( width <= 0 || height <= 0)
				NSLog( @"***** imageByScalingProportionallyToSize : width == 0 || height == 0");
			
			float targetWidth  = targetSize.width;
			float targetHeight = targetSize.height;
			
			if( targetWidth <= 0 || targetHeight <= 0)
				NSLog( @"***** imageByScalingProportionallyToSize : targetWidth == 0 || targetHeight == 0");
			
			float scaleFactor  = 0.0;
			float scaledWidth  = targetWidth;
			float scaledHeight = targetHeight;
			
			NSPoint thumbnailPoint = NSZeroPoint;
			
			if( NSEqualSizes( imageSize, targetSize) == NO)
			{
				float widthFactor  = targetWidth / width;
				float heightFactor = targetHeight / height;
				
				if ( widthFactor < heightFactor )
					scaleFactor = widthFactor;
				else
					scaleFactor = heightFactor;
				
				scaledWidth  = width  * scaleFactor;
				scaledHeight = height * scaleFactor;
				
				if ( widthFactor < heightFactor )
					thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
				
				else if ( widthFactor > heightFactor )
					thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
			}
			
			//***** QuartzCore
			
			//if( thumbnailPoint.x < 1 && thumbnailPoint.y < 1)
			{
				NSSize size = [sourceImage size];
				
				[sourceImage lockFocus];
				
				NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect: NSMakeRect(0, 0, size.width, size.height)];
				CIImage *bitmap = [[CIImage alloc] initWithBitmapImageRep: rep];
				
				CIFilter *scaleTransformFilter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
				
				[scaleTransformFilter setDefaults];
				[scaleTransformFilter setValue: bitmap forKey:@"inputImage"];
				[scaleTransformFilter setValue:[NSNumber numberWithFloat: scaleFactor] forKey:@"inputScale"];
				
				CIImage *outputCIImage = [scaleTransformFilter valueForKey:@"outputImage"];
				
				CGRect extent = [outputCIImage extent];
				if (CGRectIsInfinite(extent))
				{
					NSLog( @"****** imageByScalingProportionallyToSize : OUTPUT IMAGE HAS INFINITE EXTENT");
				}
				else
				{
					newImage = [[[NSImage alloc] initWithSize: targetSize] autorelease];
					
					if( [newImage size].width > 0 && [newImage size].height > 0)
					{
						[newImage lockFocus];
						
						[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
						
						NSRect thumbnailRect;
						thumbnailRect.origin = thumbnailPoint;
						thumbnailRect.size.width = extent.size.width;
						thumbnailRect.size.height = extent.size.height;
						
						[outputCIImage drawInRect: thumbnailRect
										 fromRect: NSMakeRect( extent.origin.x , extent.origin.y, extent.size.width, extent.size.height)
										operation: NSCompositeCopy
										 fraction: 1.0];
						
						[newImage unlockFocus];
					}
				}
				
				[sourceImage unlockFocus];
				
				[rep release];
				[bitmap release];
			}
			//		else
			//
			////		***** NSImage
			//		{
			//			newImage = [[[NSImage alloc] initWithSize: targetSize] autorelease];
			//			
			//			if( [newImage size].width > 0 && [newImage size].height > 0)
			//			{
			//				[newImage lockFocus];
			//				
			//				[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
			//				
			//				NSRect thumbnailRect;
			//				thumbnailRect.origin = thumbnailPoint;
			//				thumbnailRect.size.width = scaledWidth;
			//				thumbnailRect.size.height = scaledHeight;
			//				
			//				[sourceImage drawInRect: thumbnailRect
			//							   fromRect: NSZeroRect
			//							  operation: NSCompositeCopy
			//							   fraction: 1.0];
			//				
			//				[newImage unlockFocus];
			//			}
			//		}
		}
	}
	
	NSImage *returnImage = nil;
	
	if( newImage)
		returnImage = [[NSImage alloc] initWithData: [newImage TIFFRepresentation]];
	
	[pool release];
	
		
	return [returnImage autorelease];
}

@end
