/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/




#import <AppKit/AppKit.h>
#import "ViewerController.h"

/** Window Controller for Toolbar */
@interface ToolbarPanelController : NSWindowController {
	
	NSToolbar               *toolbar;
	long					screen;
	NSToolbar				*emptyToolbar;
	ViewerController		*viewer;
}

@property (readonly) ViewerController *viewer;

+ (long) fixedHeight;
- (void) setToolbar :(NSToolbar*) tb viewer:(ViewerController*) v;
- (void) fixSize;
- (void) toolbarWillClose :(NSToolbar*) tb;
- (id)initForScreen: (long) s;
- (NSToolbar*) toolbar;

@end
