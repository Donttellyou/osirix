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

@interface OSIDatabasePreferencePanePref : NSPreferencePane 
{
	IBOutlet NSMatrix		*locationMatrix;
	IBOutlet NSTextField	*locationURLField;
	IBOutlet NSPathControl	*locationPathField;
	IBOutlet NSMatrix		*copyDatabaseModeMatrix;
	IBOutlet NSButton		*copyDatabaseOnOffButton;
	IBOutlet NSButton		*localizerOnOffButton;
	IBOutlet NSMatrix		*seriesOrderMatrix;
	IBOutlet NSPopUpButton	*reportsMode;
	
	NSArray					*DICOMFieldsArray;
	IBOutlet NSPopUpButton	*dicomFieldsMenu;
	
	IBOutlet NSMatrix		*commentsDeleteMatrix;
	IBOutlet NSTextField	*commentsDeleteText;
	
	IBOutlet NSButton		*commentsAutoFill;
	IBOutlet NSTextField	*commentsGroup, *commentsElement;
	
	// Auto-Cleaning

	IBOutlet NSButton		*older, *deleteOriginal;
	IBOutlet NSMatrix		*olderType;
	IBOutlet NSPopUpButton	*olderThanProduced, *olderThanOpened;
	
	IBOutlet NSButton		*freeSpace;
	IBOutlet NSMatrix		*freeSpaceType;
	IBOutlet NSPopUpButton	*freeSpaceSize;
}

- (void) mainViewDidLoad;
- (IBAction)setLocation:(id)sender;
- (IBAction)setLocationURL:(id)sender;
- (IBAction)setCopyDatabaseMode:(id)sender;
- (IBAction)setCopyDatabaseOnOff:(id)sender;
- (IBAction)setLocalizerOnOff:(id)sender;
- (IBAction)databaseCleaning:(id)sender;
- (IBAction)setSeriesOrder:(id)sender;
- (IBAction)setAutoComments:(id) sender;
- (IBAction)regenerateAutoComments:(id) sender;
- (IBAction)setReportMode:(id) sender;
- (IBAction) resetDate:(id) sender;
- (IBAction) resetDateOfBirth:(id) sender;
- (IBAction) setDICOMFieldMenu: (id) sender;
- (BOOL)useSeriesDescription;
- (void)setUseSeriesDescription:(BOOL)value;
- (BOOL)splitMultiEchoMR;
- (void)setSplitMultiEchoMR:(BOOL)value;
@end
