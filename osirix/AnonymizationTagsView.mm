//
//  AnonymizationTagsView.mm
//  OsiriX
//
//  Created by Alessandro Volz on 5/25/10.
//  Copyright 2010 OsiriX Team. All rights reserved.
//

#import "AnonymizationTagsView.h"
#import "DCMAttributeTag.h"
#import "N2HighlightImageButtonCell.h"
#import "AnonymizationViewController.h"
#import "AnonymizationTagsPopUpButton.h"
#include <algorithm>
#include <cmath>

@implementation AnonymizationTagsView

-(id)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	
	viewGroups = [[NSMutableArray alloc] init];
	intercellSpacing = NSMakeSize(13,1);
	
	dcmTagsPopUpButton = [[AnonymizationTagsPopUpButton alloc] initWithSize:NSZeroSize];
	[dcmTagsPopUpButton.cell setControlSize:NSMiniControlSize];
	[dcmTagsPopUpButton setFont:[NSFont labelFontOfSize:[NSFont smallSystemFontSize]-2]];
	[self addSubview:dcmTagsPopUpButton];
	
	NSButtonCell* addButtonCell = [[N2HighlightImageButtonCell alloc] initWithImage:[NSImage imageNamed:@"PlusButton"]];
	dcmTagAddButton = [[NSButton alloc] initWithSize:NSZeroSize];
	dcmTagAddButton.cell = addButtonCell;
	[addButtonCell release];
	dcmTagAddButton.target = self;
	dcmTagAddButton.action = @selector(addButtonAction:);
	[self addSubview:dcmTagAddButton];
	
	return self;
}

-(NSArray*)groupForView:(id)view {
	for (NSArray* group in viewGroups)
		for (id obj in group)
			if (view == obj || [obj isEqual:view])
				return group;
	return NULL;
}

-(void)addButtonAction:(NSButton*)sender {
	[anonymizationViewController addTag:dcmTagsPopUpButton.selectedTag];
	[[anonymizationViewController.tagsView checkBoxForTag:dcmTagsPopUpButton.selectedTag] setState:NSOnState];
	[self.window makeFirstResponder:[anonymizationViewController.tagsView textFieldForTag:dcmTagsPopUpButton.selectedTag]];
	[dcmTagsPopUpButton setSelectedTag:NULL];
}

-(void)rmButtonAction:(NSButton*)sender {
	[anonymizationViewController removeTag:[[self groupForView:sender] objectAtIndex:3]];
}

-(void)awakeFromNib {
	[self resizeSubviewsWithOldSize:self.frame.size];
}

-(BOOL)isFlipped {
	return YES;
}

-(void)dealloc {
	NSLog(@"AnonymizationTagsView dealloc");
	[dcmTagsPopUpButton release];
	[dcmTagAddButton release];
	[viewGroups release];
	[super dealloc];
}

-(NSInteger)columnCount {
	return 2;
}

-(NSInteger)rowCount {
	return std::ceil(CGFloat(viewGroups.count+1)/self.columnCount);
}

-(NSRect)cellFrameForIndex:(NSInteger)index {
	NSInteger column = index%self.columnCount, row = std::floor(CGFloat(index)/self.columnCount);
	return NSMakeRect((cellSize.width+intercellSpacing.width)*column, (cellSize.height+intercellSpacing.height)*row, cellSize.width, cellSize.height);
}

#define kMaxTextFieldWidth 200.f
#define kButtonSpace 15.f

-(NSRect)checkBoxFrameForCellFrame:(NSRect)frame {
	CGFloat textFieldWidth = std::min((frame.size.width-kButtonSpace)/2, kMaxTextFieldWidth);
	frame.size.width -= frame.size.height+textFieldWidth;
	return frame;
}

-(NSRect)textFieldFrameForCellFrame:(NSRect)frame {
	CGFloat textFieldWidth = std::min((frame.size.width-kButtonSpace)/2, kMaxTextFieldWidth);
	frame.origin.x += frame.size.width - textFieldWidth - frame.size.height;
	frame.size.width = textFieldWidth;
	return frame;
}

-(NSRect)buttonFrameForCellFrame:(NSRect)frame {
	frame.origin.x += frame.size.width-10;
	frame.origin.y += 4;
	frame.size = NSMakeSize(10,10);
	return frame;
}

-(NSRect)popUpButtonFrameForCellFrame:(NSRect)frame {
	frame.size.width -= kButtonSpace;
	return frame;
}

-(void)repositionGroupViews:(NSArray*)group {
	NSRect cellFrame = [self cellFrameForIndex:[viewGroups indexOfObject:group]];
	[[group objectAtIndex:0] setFrame:[self checkBoxFrameForCellFrame:cellFrame]];
	[[group objectAtIndex:1] setFrame:[self textFieldFrameForCellFrame:cellFrame]];
	[[group objectAtIndex:2] setFrame:[self buttonFrameForCellFrame:cellFrame]];
}

-(void)repositionAddTagInterface {
	NSRect cellFrame = [self cellFrameForIndex:viewGroups.count];
	[dcmTagsPopUpButton setFrame:[self popUpButtonFrameForCellFrame:cellFrame]];
	[dcmTagAddButton setFrame:[self buttonFrameForCellFrame:cellFrame]];
}

-(void)addTag:(DCMAttributeTag*)tag {
	static const NSFont* font = [[NSFont labelFontOfSize:[NSFont smallSystemFontSize]-1] retain];

	NSButton* checkBox = [[NSButton alloc] initWithSize:NSZeroSize];
	[[checkBox cell] setControlSize:NSMiniControlSize];
	[checkBox setFont:font];
	[[checkBox cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[checkBox setButtonType:NSSwitchButton];
	[checkBox setTitle:tag.name];
	[self addSubview:checkBox];
	
	NSTextField* textField = [[NSTextField alloc] initWithSize:NSZeroSize];
	[[textField cell] setControlSize:NSMiniControlSize];
	[textField setFont:font];
	[textField setBezeled:YES];
	[textField setBezelStyle:NSTextFieldSquareBezel];
	[textField setDrawsBackground:YES];
	[[textField cell] setPlaceholderString:NSLocalizedString(@"Reset", @"Placeholder string for Anonymization Tag cells")];
	[textField setStringValue:@""];
	// TODO: formatter
	[self addSubview:textField];
	
	if ([tag.vr isEqual:@"DA"]) {
		NSDateFormatter* f = [[[NSDateFormatter alloc] init] autorelease];
		[f setTimeStyle:NSDateFormatterNoStyle];
		[f setDateStyle:NSDateFormatterShortStyle];
		[textField setFormatter:f];
	} else if ([tag.vr isEqual:@"TM"]) {
		NSDateFormatter* f = [[[NSDateFormatter alloc] init] autorelease];
		[f setTimeStyle:NSDateFormatterShortStyle];
		[f setDateStyle:NSDateFormatterNoStyle];
		[textField setFormatter:f];
	} else if ([tag.vr isEqual:@"DT"]) {
		NSDateFormatter* f = [[[NSDateFormatter alloc] init] autorelease];
		[f setTimeStyle:NSDateFormatterShortStyle];
		[f setDateStyle:NSDateFormatterShortStyle];
		[textField setFormatter:f];
	}
	
	NSButtonCell* rmButtonCell = [[N2HighlightImageButtonCell alloc] initWithImage:[NSImage imageNamed:@"MinusButton"]];
	NSButton* rmButton = [[NSButton alloc] initWithSize:NSZeroSize];
	rmButton.cell = rmButtonCell;
	[rmButtonCell release];
	rmButton.target = self;
	rmButton.action = @selector(rmButtonAction:);
	[self addSubview:rmButton];
	
	[textField bind:@"enabled" toObject:checkBox.cell withKeyPath:@"state" options:NULL];
	
	NSArray* group = [NSArray arrayWithObjects: checkBox, textField, rmButton, tag, NULL];
	[viewGroups addObject:group];
	[self resizeSubviewsWithOldSize:self.frame.size];
	
	[checkBox release];
	[textField release];
	[rmButton release];
}

-(void)removeTag:(DCMAttributeTag*)tag {
	NSArray* group = [self groupForView:tag];
	if (!group) return;
	
	[[group objectAtIndex:0] removeFromSuperview];
	[[group objectAtIndex:1] removeFromSuperview];
	[[group objectAtIndex:2] removeFromSuperview];
	
	[viewGroups removeObject:group];

	[self resizeSubviewsWithOldSize:self.frame.size];
}

-(NSButton*)checkBoxForTag:(DCMAttributeTag*)tag {
	return [[self groupForView:tag] objectAtIndex:0];
}

-(NSTextField*)textFieldForTag:(DCMAttributeTag*)tag {
	return [[self groupForView:tag] objectAtIndex:1];
}

-(NSSize)idealSize {
	NSInteger columnCount = self.columnCount, rowCount = self.rowCount;
	return NSMakeSize(cellSize.width*columnCount+intercellSpacing.width*std::max(0,columnCount-1), cellSize.height*rowCount+intercellSpacing.height*std::max(0,rowCount-1));
}

-(void)resizeSubviewsWithOldSize:(NSSize)oldSize {
	cellSize = NSMakeSize((self.frame.size.width-intercellSpacing.width*(self.columnCount-1))/2,17);
	for (NSArray* group in viewGroups)
		[self repositionGroupViews:group];
	[self repositionAddTagInterface];
}







@end