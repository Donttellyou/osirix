//
//  SpecialSplitView.mm
//  ROI Enhancement II
//
//  Created by Alessandro Volz on 4/23/09.
//  Copyright 2009 HUG. All rights reserved.
//

#import "SpecialSplitView.h"


@implementation SpecialSplitView

-(void)awakeFromNib {
	[self setDelegate:self];
	// save the right subview's standard width for future usage
	rightSubviewWidth = [(NSView*)[[self subviews] objectAtIndex:1] frame].size.width;
}

// keep the right subview's size constant
-(void)splitView:(NSSplitView*)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
	NSView* left = (NSView*)[[sender subviews] objectAtIndex:0];
	NSView* right = (NSView*)[[sender subviews] objectAtIndex:1];
	
	NSRect splitFrame = [sender frame];
	CGFloat dividerThickness = [sender dividerThickness];
	CGFloat availableWidth = splitFrame.size.width - dividerThickness;
	
	NSRect leftFrame = [left frame];
	NSRect rightFrame = [right frame];
	
	leftFrame.size.height = splitFrame.size.height;
	leftFrame.size.width = availableWidth - rightFrame.size.width;
	[left setFrame:leftFrame];
	
	rightFrame.origin.x = leftFrame.origin.x + leftFrame.size.width + dividerThickness;
	rightFrame.size.height = splitFrame.size.height;
	[right setFrame:rightFrame];
}

// constrain the divider position to either match the right subview's width or to hide it
-(CGFloat)splitView:(NSSplitView*)sender constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)offset {
	NSRect splitFrame = [sender frame];
	CGFloat dividerThickness = [sender dividerThickness];
	CGFloat availableWidth = splitFrame.size.width - dividerThickness;
	
	// we return the width of the left subview, either (availableWidth) or (availableWidth-rightSubviewWidth)
	return (proposedPosition < availableWidth-rightSubviewWidth/2)? (availableWidth-rightSubviewWidth) : availableWidth;
}

@end