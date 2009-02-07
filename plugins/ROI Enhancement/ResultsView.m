//
//  ResultsView.m
//  ROI-Enhancement
//
//  Created by rossetantoine on Thu Jun 17 2004.
//  Copyright (c) 2004 Antoine Rosset. All rights reserved.
//

#import "ResultsView.h"

@implementation ResultsView

- (void) dealloc
{
	[super dealloc];
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
		
    }
    return self;
}

-(void) setArrays: (long) nb :(float*) meanPtr :(float*)minPtr :(float*)maxPtr
{
	arraySize = nb;
	meanValues = meanPtr;
	maxValues = maxPtr;
	minValues = minPtr;
	
	[self setNeedsDisplay: YES];
}

- (void)drawRect:(NSRect)rect
{
    // Drawing code here.
	NSRect  boundsRect = [self bounds];
	long	i;
	float   maxValue, minValue;
	
	[[NSColor colorWithDeviceRed:1.0 green:1.0 blue:0.2 alpha:1.0] set];
	NSRectFill( rect);

	if( minValues == 0L) return;
	
	// Find the max and min values of the arrays
	minValue = maxValue = minValues[ 0];
	for( i = 0; i < arraySize; i++)
	{
		if( minValue > minValues[ i]) minValue = minValues[ i];
		if( maxValue < minValues[ i]) maxValue = minValues[ i];
		if( minValue > maxValues[ i]) minValue = maxValues[ i];
		if( maxValue < maxValues[ i]) maxValue = maxValues[ i];
		if( minValue > meanValues[ i]) minValue = meanValues[ i];
		if( maxValue < meanValues[ i]) maxValue = meanValues[ i];
	}
	
	// Draw the 3 curves	
	NSBezierPath *curveMin = [NSBezierPath bezierPath];
	NSBezierPath *curveMax = [NSBezierPath bezierPath];
	NSBezierPath *curveMean = [NSBezierPath bezierPath];
	
	for( i = 0; i < arraySize; i++)
	{
		float   xx, yy;
		
		xx = (i * boundsRect.size.width) / (arraySize-1);
		
		yy = minValues[ i] - minValue;
		yy = (yy * boundsRect.size.height) / (maxValue-minValue);
		
		if( i == 0) [curveMin moveToPoint: NSMakePoint( xx, yy)];
		else [curveMin lineToPoint: NSMakePoint( xx, yy)];
	}
	
	for( i = 0; i < arraySize; i++)
	{
		float   xx, yy;
		
		xx = (i * boundsRect.size.width) / (arraySize-1);
		
		yy = maxValues[ i] - minValue;
		yy = (yy * boundsRect.size.height) / (maxValue-minValue);
		
		if( i == 0) [curveMax moveToPoint: NSMakePoint( xx, yy)];
		else [curveMax lineToPoint: NSMakePoint( xx, yy)];
	}
	
	for( i = 0; i < arraySize; i++)
	{
		float   xx, yy;
		
		xx = (i * boundsRect.size.width) / (arraySize-1);
		
		yy = meanValues[ i] - minValue;
		yy = (yy * boundsRect.size.height) / (maxValue-minValue);
		
		if( i == 0) [curveMean moveToPoint: NSMakePoint( xx, yy)];
		else [curveMean lineToPoint: NSMakePoint( xx, yy)];
	}
	
	[curveMax setLineWidth: 2];
	[curveMin setLineWidth: 2];
	[curveMean setLineWidth: 3];
	
	[[NSColor blackColor] set];
	
	[curveMax stroke];
	[curveMin stroke];
	[curveMean stroke];
	
	[[NSColor blackColor] set];
	[NSBezierPath strokeRect:[self bounds]];
}

@end
