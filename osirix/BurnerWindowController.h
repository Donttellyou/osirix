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

#import <Cocoa/Cocoa.h>

enum burnerDestination
{
    CDDVD = 0,
    USBKey = 1,
    DMGFile = 2
};

@class DRTrack;
@class DicomDatabase;

/** \brief Window Controller for DICOM disk burning */
@interface BurnerWindowController : NSWindowController <NSWindowDelegate>
{
	volatile BOOL burning;
	NSMutableArray *nodeArray;
	NSMutableArray *files, *anonymizedFiles, *dbObjects, *originalDbObjects;
	float burnSize;
	IBOutlet NSTextField *nameField;
	IBOutlet NSTextField *sizeField, *finalSizeField;
	IBOutlet NSMatrix	 *compressionMode;
	IBOutlet NSButton *burnButton;
	IBOutlet NSButton *anonymizedCheckButton;
	NSString *cdName;
	NSString *folderSize;
	NSTimer *burnAnimationTimer;
	volatile BOOL runBurnAnimation, isExtracting, isSettingUpBurn, isThrobbing, windowWillClose;
	NSArray *filesToBurn;
	BOOL _multiplePatients;
	BOOL cancelled;
    NSString *writeDMGPath, *writeVolumePath;
    NSUInteger selectedUSB;
	NSArray *anonymizationTags;
    int sizeInMb;
	NSString *password;
	IBOutlet NSWindow *passwordWindow;
	
	BOOL buttonsDisabled;
	BOOL burnSuppFolder, burnOsiriX, burnHtml, burnWeasis;
    
	int burnAnimationIndex;
    int irisAnimationIndex;
    NSTimer *irisAnimationTimer;
    
    DicomDatabase* idatabase;
}

@property BOOL buttonsDisabled;
@property NSUInteger selectedUSB;
@property (retain) NSString *password;

- (NSArray*) volumes;
- (IBAction) ok:(id)sender;
- (IBAction) cancel:(id)sender;
- (IBAction) setAnonymizedCheck: (id) sender;
- (id) initWithFiles:(NSArray *)theFiles;
- (id)initWithFiles:(NSArray *)theFiles managedObjects:(NSArray *)managedObjects;
- (IBAction)burn:(id)sender;
- (void)setCDTitle: (NSString *)title;
- (IBAction)setCDName:(id)sender;
- (NSString *)folderToBurn;
- (void)setFilesToBurn:(NSArray *)theFiles;
- (void)burnCD:(id)object;
- (NSArray *)extractFileNames:(NSArray *)filenames;
- (BOOL)dicomCheck:(NSString *)filename;
- (void)importFiles:(NSArray *)fileNames;
- (void)setup:(id)sender;
- (void)prepareCDContent;
- (IBAction)estimateFolderSize:(id)object;
- (void)performBurn:(id)object;
- (void)irisAnimation:(NSTimer*)object;
- (NSNumber*)getSizeOfDirectory:(NSString*)path;
- (NSString*) defaultTitle;
- (IBAction) estimateFolderSize: (id) sender;
- (void)saveOnVolume;
@end
