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

#import "OrthogonalMPRController.h"
#import "OrthogonalMPRPETCTView.h"
#import "OrthogonalMPRPETCTController.h"
#import "Notifications.h"


@implementation OrthogonalMPRPETCTView

- (void) drawTextualData:(NSRect) size annotationsLevel:(long) annotations fullText: (BOOL) fullText onlyOrientation: (BOOL) onlyOrientation
{
	if( isKeyView == NO)
		[super drawTextualData: size annotationsLevel: annotations fullText: NO onlyOrientation: YES];
	else
		[super drawTextualData: size annotationsLevel: annotations fullText: NO onlyOrientation: NO];
}

- (void) dealloc
{
	[super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	blendingFactor = 0.5f;
	return self;
}

- (void) setCrossPosition: (float) x: (float) y
{
	if(crossPositionX == x && crossPositionY == y)
		return;
	crossPositionX = x;
	crossPositionY = y;
	[(OrthogonalMPRPETCTController*)controller setCrossPosition: x: y: self];
}

-(void) setBlendingFactor:(float) f
{
	[controller setBlendingFactor:f];
}

-(void) superSetBlendingFactor:(float) f
{
	[super setBlendingFactor:f];
}

- (void) flipVertical:(id) sender
{
	[(OrthogonalMPRPETCTController*)controller flipVertical: sender : self];
}

- (void) superFlipVertical:(id) sender
{
	[super flipVertical: sender];
}

- (void) flipHorizontal:(id) sender
{
	[(OrthogonalMPRPETCTController*)controller flipHorizontal: sender : self];
}

- (void) superFlipHorizontal:(id) sender
{
	[super flipHorizontal: sender];
}

- (BOOL) becomeFirstResponder
{
	[[NSNotificationCenter defaultCenter] postNotificationName: OsirixUpdateCLUTMenuNotification object: curCLUTMenu userInfo: nil];
	[[NSNotificationCenter defaultCenter] postNotificationName: OsirixUpdateWLWWMenuNotification object: curWLWWMenu userInfo: nil];
	[[NSNotificationCenter defaultCenter] postNotificationName: OsirixUpdateOpacityMenuNotification object: curOpacityMenu userInfo: nil];
	
	return [super becomeFirstResponder];
}

@end
