//
//  BullsEyeView.m
//  BullsEye
//
//  Created by Antoine Rosset on 18.11.09.
//  Copyright 2009 OsiriX Team. All rights reserved.
//

#import "BullsEyeView.h"

static BullsEyeView *bullsEyeView= nil;

@implementation BullsEyeView

+ (BullsEyeView*) view
{
	return bullsEyeView;
}

- (void) dealloc
{
	[segments release];
	
	[super dealloc];
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame: frame];
    if (self)
	{
		bullsEyeView = self;
		
		segments = [[NSMutableArray alloc] init];
		
		for( int i = 0 ; i < 17; i++)
			[segments addObject: [NSMutableDictionary dictionary]];
			
		[self refresh];
    }
    return self;
}

- (IBAction) reset: (id) sender
{
	for( int i = 0 ; i < 17; i++)
		[segments replaceObjectAtIndex:i withObject: [NSMutableDictionary dictionary]];
			
	[self refresh];
}

- (NSRect) squareBounds
{
	NSRect squareBounds = [self bounds];
	
	if( squareBounds.size.width < squareBounds.size.height)
	{
		squareBounds.origin.y += (squareBounds.size.height - squareBounds.size.width)/2;
		squareBounds.size.height = squareBounds.size.width;
	}
	else
	{
		squareBounds.origin.x += (squareBounds.size.width - squareBounds.size.height)/2;
		squareBounds.size.width = squareBounds.size.height;
	}
	
	return squareBounds;
}

- (void) refresh
{
	[self setNeedsDisplay: YES];
}

- (void) setText: (int) i :(NSMutableDictionary*) seg
{
	NSString *text = @"";
	int val = [[seg objectForKey: @"state"] intValue];
	
	if( [[c presetBullsEyeArray] count] == 0)
	{
		[seg setObject: @"" forKey: @"text"];
		return;
	}
	
	if( val >= [[c presetBullsEyeArray] count])
		val = [[c presetBullsEyeArray] count] -1;
	
	if( [[[c.presetsList selection] valueForKey: @"bullsEyeDisplayLegendSegmentsNumber"] boolValue] && [[[c.presetsList selection] valueForKey: @"bullsEyeDisplayLegendSegmentsText"] boolValue])
		text = [NSString stringWithFormat: @"%d\r%@", i+1, [[[c presetBullsEyeArray] objectAtIndex: val] objectForKey: @"state"]];
		
	if( [[[c.presetsList selection] valueForKey: @"bullsEyeDisplayLegendSegmentsNumber"] boolValue] == NO && [[[c.presetsList selection] valueForKey: @"bullsEyeDisplayLegendSegmentsText"] boolValue])
		text = [NSString stringWithFormat: @"%@", [[[c presetBullsEyeArray] objectAtIndex: val] objectForKey: @"state"]];
	
	if( [[[c.presetsList selection] valueForKey: @"bullsEyeDisplayLegendSegmentsNumber"] boolValue] && [[[c.presetsList selection] valueForKey: @"bullsEyeDisplayLegendSegmentsText"] boolValue] == NO)
		text = [NSString stringWithFormat: @"%d", i];
	
	[seg setObject: text forKey: @"text"];
}

- (void) mouseDown:(NSEvent *) theEvent
{
	NSPoint event_location = [theEvent locationInWindow];
	NSPoint local_point = [self convertPoint:event_location fromView:nil];
	
	for( int i = 0 ; i < [segments count] ; i++)
	{
		NSMutableDictionary *seg = [segments objectAtIndex: i];
		
		if( [[seg objectForKey: @"drawing"] containsPoint: local_point])
		{
			int val = [[seg objectForKey: @"state"] intValue]+1;
			if( val >= [[c presetBullsEyeArray] count])
				val = 0;
				
			[seg setObject: [NSNumber numberWithInt: val] forKey: @"state"];
			
			NSString *text = nil;
			
			if( [[[c.presetsList selection] valueForKey: @"bullsEyeDisplayLegendSegmentsNumber"] boolValue] && [[[c.presetsList selection] valueForKey: @"bullsEyeDisplayLegendSegmentsText"] boolValue])
				text = [NSString stringWithFormat: @"%d\r%@", i+1, [[[c presetBullsEyeArray] objectAtIndex: val] objectForKey: @"state"]];
				
			if( [[[c.presetsList selection] valueForKey: @"bullsEyeDisplayLegendSegmentsNumber"] boolValue] == NO && [[[c.presetsList selection] valueForKey: @"bullsEyeDisplayLegendSegmentsText"] boolValue])
				text = [NSString stringWithFormat: @"%@", [[[c presetBullsEyeArray] objectAtIndex: val] objectForKey: @"state"]];
			
			if( [[[c.presetsList selection] valueForKey: @"bullsEyeDisplayLegendSegmentsNumber"] boolValue] && [[[c.presetsList selection] valueForKey: @"bullsEyeDisplayLegendSegmentsText"] boolValue] == NO)
				text = [NSString stringWithFormat: @"%d", i];
			
			[seg setObject: text forKey: @"text"];
		}
	}
	
	[[self window] makeFirstResponder: self];
	[self setNeedsDisplay: YES];
}

-(IBAction) copy:(id) sender
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
	
	[pb declareTypes: [NSArray arrayWithObject: NSPDFPboardType] owner:self];
	[pb setData: [self dataWithPDFInsideRect:[self squareBounds]] forType: NSPDFPboardType];
}

- (void)drawRect:(NSRect)dirtyRect
{
	// Set up
	c = [[self window] windowController];
	
	for( int i = 0 ; i < 17; i++)
		[self setText: i :[segments objectAtIndex: i]];
	
	NSRect frame = [self frame];
	
	frame.origin.x += 5;
	frame.origin.y += 5;
	
	frame.size.height -= 10;
	frame.size.width -= 10;
	
	if( frame.size.height > frame.size.width)
		frame.size.height = frame.size.width;
	else 
		frame.size.width = frame.size.height;
	
	NSPoint center = NSMakePoint( [self frame].origin.x + [self frame].size.width/2., [self frame].origin.y + [self frame].size.height/2.);
	float radius = frame.size.width/2.;
	
	int a = 0;
	float segRadius = 60;
	for( int i = 0 ; i < 6; i++)
	{
		NSBezierPath* s = [[[NSBezierPath alloc] init] autorelease];
		[s appendBezierPathWithArcWithCenter: center radius: radius startAngle: segRadius+60 endAngle: segRadius clockwise: YES];
		[s appendBezierPathWithArcWithCenter: center radius: radius*5/7 startAngle: segRadius endAngle: segRadius+60];
		[s closePath];
		[s setLineWidth: 0.5];
		[s setLineJoinStyle:NSRoundLineJoinStyle];
		
		segRadius += 60;
		
		[[segments objectAtIndex: a++] setObject: s forKey: @"drawing"];
	}
	segRadius = 60;
	for( int i = 0 ; i < 6; i++)
	{
		NSBezierPath* s = [[[NSBezierPath alloc] init] autorelease];
		[s appendBezierPathWithArcWithCenter: center radius: radius*5/7 startAngle: segRadius+60 endAngle: segRadius clockwise: YES];
		[s appendBezierPathWithArcWithCenter: center radius: radius*3/7 startAngle: segRadius endAngle: segRadius+60];
		[s closePath];
		[s setLineWidth: 0.5];
		[s setLineJoinStyle:NSRoundLineJoinStyle];
		
		segRadius += 60;
		
		[[segments objectAtIndex: a++] setObject: s forKey: @"drawing"];
	}
	segRadius = 45;
	for( int i = 0 ; i < 4; i++)
	{
		NSBezierPath* s = [[[NSBezierPath alloc] init] autorelease];
		[s appendBezierPathWithArcWithCenter: center radius: radius*3/7 startAngle: segRadius+90 endAngle: segRadius clockwise: YES];
		[s appendBezierPathWithArcWithCenter: center radius: radius*1/7 startAngle: segRadius endAngle: segRadius+90];
		[s closePath];
		[s setLineWidth: 0.5];
		[s setLineJoinStyle:NSRoundLineJoinStyle];
		
		segRadius += 90;
		
		[[segments objectAtIndex: a++] setObject: s forKey: @"drawing"];
	}
	
	NSBezierPath* s = [[[NSBezierPath alloc] init] autorelease];
	[s appendBezierPathWithArcWithCenter: center radius: radius*1/7 startAngle: 0 endAngle: 180 clockwise: YES];
	[s appendBezierPathWithArcWithCenter: center radius: radius*1/7 startAngle: 180 endAngle: 360 clockwise: YES];
	[s closePath];
	[s setLineWidth: 0.5];
	[s setLineJoinStyle:NSRoundLineJoinStyle];
	[[segments objectAtIndex: a++] setObject: s forKey: @"drawing"];
	
	NSFont *font = [[NSFontManager sharedFontManager] fontWithFamily:@"Helvetica" traits:NSBoldFontMask weight:9 size:12.];
	NSMutableParagraphStyle *para = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[para setAlignment: NSCenterTextAlignment];
	
	NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys: font, NSFontAttributeName, para, NSParagraphStyleAttributeName, nil];
	
   // Drawing
   for( int i = 0; i < [segments count]; i++)
   {
		NSMutableDictionary* s = [segments objectAtIndex: i];
		
		if( [[s objectForKey: @"state"] intValue] >= [[c presetBullsEyeArray] count] && [[c presetBullsEyeArray] count] > 0)
			[s setObject: [NSNumber numberWithInt: [[c presetBullsEyeArray] count]-1] forKey: @"state"];
		
		NSColor *color = [NSColor whiteColor];
		
		if( [[c presetBullsEyeArray] count])
			color = [NSUnarchiver unarchiveObjectWithData: [[[c presetBullsEyeArray] objectAtIndex: [[s objectForKey: @"state"] intValue]] objectForKey: @"color"]];
		
		[color set];
		[[s objectForKey: @"drawing"] fill];
		
		[[NSColor blackColor] set];
		[[s objectForKey: @"drawing"] stroke];
		
		NSSize size = [[s objectForKey: @"text"] sizeWithAttributes: attr];
		
		NSRect bounds = [[s objectForKey: @"drawing"] bounds];
		#define D 25.
		if( i+1 == 2)
			bounds = NSOffsetRect( bounds, -radius/D, radius/D);
		if( i+1 == 6)
			bounds = NSOffsetRect( bounds, radius/D, radius/D);
		if( i+1 == 3)
			bounds = NSOffsetRect( bounds, -radius/D, -radius/D);
		if( i+1 == 5)
			bounds = NSOffsetRect( bounds, radius/D, -radius/D);
			
		NSRect rect;
		rect.origin = NSMakePoint( bounds.origin.x + bounds.size.width/2 - size.width/2, bounds.origin.y + bounds.size.height/2 - size.height/2);
		rect.size = size;
		
		[[s objectForKey: @"text"] drawInRect: rect withAttributes: attr];
   }
}

@end
