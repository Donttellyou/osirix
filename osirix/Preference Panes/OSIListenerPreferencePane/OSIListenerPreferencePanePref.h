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
#import <SecurityInterface/SFAuthorizationView.h>

@interface OSIListenerPreferencePanePref : NSPreferencePane 
{
	IBOutlet NSForm *aeForm;
	IBOutlet NSMatrix *deleteFileModeMatrix;
	IBOutlet NSButton *listenerOnOffButton;
	IBOutlet NSFormCell *ipField;
	IBOutlet NSFormCell *nameField;
	IBOutlet NSButton *listenerOnOffAnonymize;
	IBOutlet NSButton *generateLogsButton;
	IBOutlet NSButton *decompressButton, *compressButton;
	IBOutlet NSTextField *checkIntervalField, *timeout;
	IBOutlet NSButton *singleProcessButton;
	IBOutlet NSPopUpButton *logDurationPopup;
	IBOutlet SFAuthorizationView *_authView;
	IBOutlet NSWindow *webServerSettingsWindow;
	
	IBOutlet NSWindow *TLSSettingsWindow;
}

- (void) mainViewDidLoad;
- (IBAction)setDeleteFileMode:(id)sender;
- (IBAction)setListenerOnOff:(id)sender;
- (IBAction)setAnonymizeListenerOnOff:(id)sender;
- (IBAction)setGenerateLogs:(id)sender;
- (IBAction)helpstorescp:(id) sender;
- (IBAction)setSingleProcess:(id)sender;
- (IBAction)setLogDuration:(id)sender;
- (IBAction)setCheckInterval:(id) sender;
- (IBAction)setDecompress:(id)sender;
- (IBAction)setCompress:(id)sender;
- (IBAction)webServerSettings:(id)sender;
- (IBAction)smartAlbumHelpButton:(id)sender;
- (IBAction)openKeyChainAccess:(id)sender;

#pragma mark TLS
- (IBAction)editTLS:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)ok:(id)sender;

@end
