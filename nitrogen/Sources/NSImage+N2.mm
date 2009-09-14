//
//  NSImage+Extras.m
//  Arthroplasty Templating II
//  Created by Alessandro Volz on 5/27/09.
//  Copyright (c) 2007-2009 OsiriX Team. All rights reserved.
//

#import <Nitrogen/NSImage+N2.h>
#include <Accelerate/Accelerate.h>
#include <stack>
#include <algorithm>
//#include <boost/numeric/ublas/matrix.hpp>
//#include <fftw3.h>
//#include <complex>
#import <Nitrogen/N2Operators.h>
#import <Nitrogen/NSColor+N2.h>

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


@implementation NSImage (ArthroplastyTemplating)

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
	if (box.size.width < 0) { box.origin.x += box.size.width; box.size.width = -box.size.width; } 
	if (box.size.height < 0) { box.origin.y += box.size.height; box.size.height = -box.size.height; } 
	
	NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithData:[self TIFFRepresentation]];
	NSSize imageSize = [self size];
	
	int x, y;
	// change origin.x
	for (x = box.origin.x; x < box.origin.x+box.size.width; ++x)
		for (y = box.origin.y; y < box.origin.y+box.size.height; ++y)
			if (![[bitmap colorAtX:x y:y] isEqualToColor:color])
				goto end_origin_x;
end_origin_x:
	if (x < box.origin.x+box.size.width) {
		box.size.width -= x-box.origin.x;
		box.origin.x = x;
	}
	
	// change origin.y
	for (y = box.origin.y; y < box.origin.y+box.size.height; ++y)
		for (x = box.origin.x; x < box.origin.x+box.size.width; ++x)
			if (![[bitmap colorAtX:x y:imageSize.height-y-1] isEqualToColor:color])
				goto end_origin_y;
end_origin_y:
	if (y < box.origin.y+box.size.height) {
		box.size.height -= y-box.origin.y;
		box.origin.y = y;
	}
	
	// change size.width
	for (x = box.origin.x+box.size.width-1; x >= box.origin.x; --x)
		for (y = box.origin.y; y < box.origin.y+box.size.height; ++y)
			if (![[bitmap colorAtX:x y:y] isEqualToColor:color])
				goto end_size_x;
end_size_x:
	if (x >= box.origin.x)
		box.size.width = x-box.origin.x+1;
	
	// change size.height
	for (y = box.origin.y+box.size.height-1; y >= box.origin.y; --y)
		for (x = box.origin.x; x < box.origin.x+box.size.width; ++x)
			if (![[bitmap colorAtX:x y:imageSize.height-y-1] isEqualToColor:color])
				goto end_size_y;
end_size_y:
	if (y >= box.origin.y)
		box.size.height = y-box.origin.y+1;
	
	[bitmap release];
	return box;
}

-(NSRect)boundingBoxSkippingColor:(NSColor*)color {
	NSSize imageSize = [self size];
	return [self boundingBoxSkippingColor:color inRect:NSMakeRect(0, 0, imageSize.width, imageSize.height)];
}

@end


@implementation NSBitmapImageRep (ArthroplastyTemplating)

struct P {
	int x, y;
	P(int x, int y) : x(x), y(y) {}
};

-(void)ATMask:(float)level {
	NSSize size = [self size];
	int width = size.width, height = size.height;
	float v[width][height];
	
	unsigned char* bitmapData = [self bitmapData];
	size_t bpp = [self bytesPerPlane], bpr = [self bytesPerRow];
	assert(bpp = 4);
	NSLog(@"time1!!!!!! %f", [NSDate timeIntervalSinceReferenceDate]);
#pragma omp parallel for default(shared)
	for (int x = 0; x < width; ++x)
		for (int y = 0; y < height; ++y)
			v[x][y] = bitmapData[y*bpr+x*bpp+3];
			//v[x][y] = [[self colorAtX:x y:y] alphaComponent];
	
	NSLog(@"time2!!!!!! %f", [NSDate timeIntervalSinceReferenceDate]);
	BOOL mask[width][height];
	memset(mask, YES, sizeof(mask));
	BOOL visited[width][height];
	memset(visited, NO, sizeof(visited));

	NSLog(@"time3!!!!!! %f", [NSDate timeIntervalSinceReferenceDate]);
	std::stack<P> ps;
	for (int x = 0; x < width; ++x) {
		ps.push(P(x, 0));
		ps.push(P(x, height-1));
	} for (int y = 1; y < height-1; ++y) {
		ps.push(P(0, y));
		ps.push(P(width-1, y));
	}
	
	NSLog(@"time4!!!!!! %f", [NSDate timeIntervalSinceReferenceDate]);
	while (!ps.empty()) {
		P p = ps.top();
		ps.pop();
		
		if (visited[p.x][p.y]) continue;
		visited[p.x][p.y] = YES;
		
		if (!v[p.x][p.y]) {
			mask[p.x][p.y] = NO;
			if (p.x > 0 && !visited[p.x-1][p.y]) ps.push(P(p.x-1, p.y));
			if (p.y > 0 && !visited[p.x][p.y-1]) ps.push(P(p.x, p.y-1));
			if (p.x < width-1 && !visited[p.x+1][p.y]) ps.push(P(p.x+1, p.y));
			if (p.y < height-1 && !visited[p.x][p.y+1]) ps.push(P(p.x, p.y+1));
		}
	}
	
	NSLog(@"time5!!!!!! %f", [NSDate timeIntervalSinceReferenceDate]);
#pragma omp parallel for default(shared)
	for (int y = 0; y < height/2; ++y)
		for (int x = 0; x < width; ++x)
			if (mask[x][y])
				bitmapData[y*bpr+x*bpp+3] = std::max(v[x][y], level);
	NSLog(@"time6!!!!!! %f", [NSDate timeIntervalSinceReferenceDate]);
}



-(NSBitmapImageRep*)smoothen:(NSUInteger)kernelSize {
	return self;;
	
	assert(kernelSize%2 == 1 && [self bitsPerSample] == 8 && [self samplesPerPixel] == 4);
	
	NSSize selfSize = [self size];
	vImage_Buffer selfBuff = {[self bitmapData], selfSize.width, selfSize.height, [self bytesPerRow]};
	
	NSSize outputSize = selfSize;
	NSBitmapImageRep* outputBitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:outputSize.width pixelsHigh:outputSize.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:outputSize.width*4 bitsPerPixel:32];
	vImage_Buffer outputBuff = {[outputBitmap bitmapData], outputSize.width, outputSize.height, [outputBitmap bytesPerRow]};
	
	Pixel_8888 backgroundColor = {0,0,0,0};
	vImageBoxConvolve_ARGB8888(&selfBuff, &outputBuff, NULL, 0, 0, kernelSize, kernelSize, backgroundColor, kvImageBackgroundColorFill);
	
	return outputBitmap;
}

/*-(NSBitmapImageRep*)convolveWithFilter:(const boost::numeric::ublas::matrix<float>&)filter fillPixel:(NSUInteger[])fillPixel {
	const NSSize filterSize = NSMakeSize(filter.size1(), filter.size2());
	assert(int(filterSize.width)%2 == 1 && int(filterSize.height)%2 == 1); // only for odd sizes
	const int offsetX = (filterSize.width-1)/2, offsetY = (filterSize.height-1)/2;
	const NSSize originalSize = [self size], size = NSMakeSize(originalSize.width+filterSize.width-1, originalSize.height+filterSize.height-1);
	
	const NSUInteger spp = [self samplesPerPixel];
	NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:size.width pixelsHigh:size.height bitsPerSample:[self bitsPerSample] samplesPerPixel:spp hasAlpha:[self hasAlpha] isPlanar:[self isPlanar] colorSpaceName:[self colorSpaceName] bitmapFormat:[self bitmapFormat] bytesPerRow:0 bitsPerPixel:[self bitsPerPixel]];
	
	for (unsigned x = 0; x < size.width; ++x)
		for (unsigned y = 0; y < size.height; ++y) {
			double pixeld[spp]; memset(pixeld, 0, sizeof(double)*spp);
			for (unsigned xi = 0; xi < filterSize.width; ++xi)
				for (unsigned yi = 0; yi < filterSize.height; ++yi) {
					const float filterValue = filter(xi,yi);
					const int xo = int(x)-offsetX+xi, yo = int(y)-offsetY+yi;
					NSUInteger pixel[spp], *pixelp = pixel;
					if (xo >= 0 && yo >= 0 && xo < originalSize.width && yo < originalSize.height)
						[self getPixel:pixel atX:xo y:yo];
					else pixelp = fillPixel;
					for (unsigned s = 0; s < spp; ++s)
						pixeld[s] += filterValue*pixelp[s];
				}

			NSUInteger pixel[spp];
			for (unsigned s = 0; s < spp; ++s)
				pixel[s] = pixeld[s];
			[bitmap setPixel:pixel atX:x y:y];
		}
	
	return [bitmap autorelease];
}

-(NSBitmapImageRep*)fftConvolveWithFilter:(const boost::numeric::ublas::matrix<float>&)filter fillPixel:(NSUInteger[])fillPixel {
	const NSSize filterSize = NSMakeSize(filter.size1(), filter.size2());
	assert(int(filterSize.width)%2 == 1 && int(filterSize.height)%2 == 1); // only for odd sizes
	const int offsetX = (filterSize.width-1)/2, offsetY = (filterSize.height-1)/2;
	const NSSize originalSize = [self size], size = NSMakeSize(originalSize.width+filterSize.width-1, originalSize.height+filterSize.height-1);
	
	const NSUInteger spp = [self samplesPerPixel];
	boost::numeric::ublas::matrix<float> layers[spp];
	for (unsigned s = 0; s < spp; ++s)
		layers[s].resize(size.width, size.height);
	boost::numeric::ublas::matrix<float> filterPadded(filter);
	filterPadded.resize(size.width, size.height, YES);
	for (unsigned x = 0; x < size.width; ++x)
		for (unsigned y = 0; y < size.height; ++y) {
			const int xo = int(x)-offsetX, yo = int(y)-offsetY;
			NSUInteger pixel[spp], *pixelp = pixel;
			if (xo >= 0 && yo >= 0 && xo < originalSize.width && yo < originalSize.height) {
				[self getPixel:pixel atX:x y:y];
			} else pixelp = fillPixel;
			for (unsigned s = 0; s < spp; ++s)
				layers[s](x,y) = pixelp[s];
			if (x >= filterSize.width || y >= filterSize.height)
				filterPadded(x,y) = 0;
		}
	
	boost::numeric::ublas::matrix< std::complex<float> > filterPaddedFreq(size.width, size.height), layersFreq[spp];
	fftwf_plan plan = fftwf_plan_dft_r2c_2d(size.width, size.height, &filterPadded(0,0), (float(*)[2])&filterPaddedFreq(0,0), FFTW_ESTIMATE);
	fftwf_execute(plan);
	fftwf_destroy_plan(plan);
	for (unsigned s = 0; s < spp; ++s) {
		layersFreq[s].resize(size.width, size.height);
		plan = fftwf_plan_dft_r2c_2d(size.width, size.height, &layers[s](0,0), (float(*)[2])&layersFreq[s](0,0), FFTW_ESTIMATE);
		fftwf_execute(plan);
		fftwf_destroy_plan(plan);
	}
	
	for (unsigned x = 0; x < size.width; ++x)
		for (unsigned y = 0; y < size.height; ++y) {
			std::complex<float> f = filterPaddedFreq(x,y);
			for (unsigned s = 0; s < spp; ++s)
				layersFreq[s](x,y) *= f;
		}
	
	for (unsigned s = 0; s < spp; ++s) {
		plan = fftwf_plan_dft_c2r_2d(size.width, size.height, (float(*)[2])&layersFreq[s](0,0), &layers[s](0,0), FFTW_ESTIMATE);
		fftwf_execute(plan);
		fftwf_destroy_plan(plan);
		// normalize
		layers[s] /= size.width*size.height;
	}
	
	NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:size.width pixelsHigh:size.height bitsPerSample:[self bitsPerSample] samplesPerPixel:spp hasAlpha:[self hasAlpha] isPlanar:[self isPlanar] colorSpaceName:[self colorSpaceName] bitmapFormat:[self bitmapFormat] bytesPerRow:0 bitsPerPixel:[self bitsPerPixel]];
	for (unsigned x = 0; x < size.width; ++x)
		for (unsigned y = 0; y < size.height; ++y) {
			NSUInteger pixel[spp];
			for (unsigned s = 0; s < spp; ++s)
				pixel[s] = layers[s](x,y);
			[bitmap setPixel:pixel atX:x y:y];
		}
	
	return bitmap;
}*/





@end

