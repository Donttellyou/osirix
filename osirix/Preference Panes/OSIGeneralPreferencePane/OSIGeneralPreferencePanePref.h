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

#import <PreferencePanes/PreferencePanes.h>
#import <Cocoa/Cocoa.h>
#import <SecurityInterface/SFAuthorizationView.h>

@interface OSIGeneralPreferencePanePref : NSPreferencePane 
{
	IBOutlet NSButton *securityOnOff;
	IBOutlet NSMatrix *readerMatrix, *parserMatrix;
	IBOutlet SFAuthorizationView *_authView;
	IBOutlet NSArrayController *compressionSettingsArrayController;
	IBOutlet NSWindow *compressionSettingsWindow;
}

-(void) mainViewDidLoad;
-(IBAction)setUseDCMTK:(id)sender;
-(IBAction)setReader: (id) sender;
-(IBAction)setParser: (id) sender;
-(IBAction)setUseTransistion:(id)sender;
-(IBAction)setTransitionType:(id)sender;
- (IBAction) setAuthentication: (id) sender;
- (IBAction) editCompressionSettings:(id) sender
@end
