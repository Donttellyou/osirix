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


#import <Cocoa/Cocoa.h>
/*
#import "DCMView.h"
#import "MyOutlineView.h"
#import "PreviewView.h"
#import "QueryController.h"
#import "AnonymizerWindowController.h"
*/

@class MPR2DController;
@class NSCFDate;
@class BurnerWindowController;
@class ViewerController;
@class BonjourPublisher;
@class BonjourBrowser;
@class AnonymizerWindowController;
@class QueryController;
@class LogWindowController;
@class PreviewView;
@class MyOutlineView;
@class DCMView;
@class DCMPix;
@class StructuredReportController;
@class BrowserMatrix;

enum RootTypes{PatientRootType, StudyRootType, RandomRootType};
enum simpleSearchType {PatientNameSearch, PatientIDSearch};
enum queueStatus{QueueHasData, QueueEmpty};
enum dbObjectSelection {oAny,oMiddle,oFirstForFirst};

@interface BrowserController : NSWindowController//NSObject
{
	NSManagedObjectModel			*managedObjectModel;
    NSManagedObjectContext			*managedObjectContext;
	NSPersistentStoreCoordinator	*persistentStoreCoordinator;
	
	NSDateFormatter			*DBDateFormat, *DBDateOfBirthFormat, *TimeFormat;
	
	
	NSString				*currentDatabasePath;
	BOOL					isCurrentDatabaseBonjour;
	NSString				*transferSyntax;
    NSArray                 *dirArray;
    NSToolbar               *toolbar;
	
	NSMutableArray			*sendQueue;
	NSMutableDictionary		*bonjourReportFilesToCheck;
	
    NSMutableArray          *previewPix, *previewPixThumbnails;
	
	NSMutableArray			*draggedItems;
		
	NSMutableDictionary		*activeSends;
	NSMutableArray			*sendLog;
	NSMutableDictionary		*activeReceives;
	NSMutableArray			*receiveLog;
	
	AnonymizerWindowController	*anonymizerController;
	BurnerWindowController		*burnerWindowController;
	LogWindowController			*logWindowController;
	
	NSNumberFormatter		*numFmt;
    
//	NSData					*notFoundDataThumbnail;
	
    DCMPix                  *curPreviewPix;
    
    NSTimer                 *timer, *IncomingTimer, *matrixDisplayIcons, *refreshTimer, *databaseCleanerTimer, *bonjourTimer, *bonjourRunLoopTimer, *deleteQueueTimer, *autoroutingQueueTimer;
	long					loadPreviewIndex, previousNoOfFiles;
	NSManagedObject			*previousItem;
    
	long					previousBonjourIndex;
	
    long                    COLUMN;
	IBOutlet NSSplitView	*splitViewHorz, *splitViewVert;
    
	BOOL					setDCMDone, mountedVolume, needDBRefresh, dontLoadSelectionSource;
	
	NSMutableArray			*albumNoOfStudiesCache;
	
    volatile BOOL           shouldDie, bonjourDownloading;
	
	NSArray							*outlineViewArray, *originalOutlineViewArray;
	NSArray							*matrixViewArray;
	
	NSString						*_searchString;
	
	IBOutlet NSTextField			*databaseDescription;
	IBOutlet MyOutlineView          *databaseOutline;
	NSMenu							*columnsMenu;
	IBOutlet BrowserMatrix			*oMatrix;
	IBOutlet NSTableView			*albumTable;
	IBOutlet NSSegmentedControl		*segmentedAlbumButton;
	
	IBOutlet NSSplitView			*sourcesSplitView;
	IBOutlet NSBox					*bonjourSourcesBox;
	
	IBOutlet NSTextField			*bonjourServiceName, *bonjourPassword;
	IBOutlet NSTableView			*bonjourServicesList;
	IBOutlet NSButton				*bonjourSharingCheck, *bonjourPasswordCheck;
	BonjourPublisher				*bonjourPublisher;
	BonjourBrowser					*bonjourBrowser;
	
	IBOutlet NSSlider				*animationSlider;
	IBOutlet NSButton				*animationCheck;
    
    IBOutlet PreviewView			*imageView;
	
	int								subFrom, subTo, subInterval, subMax;
	
	IBOutlet NSWindow				*subOpenWindow;
	IBOutlet NSMatrix				*subOpenMatrix3D, *subOpenMatrix4D, *supOpenButtons;
	
	IBOutlet NSWindow				*subSeriesWindow;
	IBOutlet NSButton				*subSeriesOKButton;
	IBOutlet NSTextField			*memoryMessage;
	IBOutlet NSBox					*enoughMem, *notEnoughMem;
	
	IBOutlet NSWindow				*bonjourPasswordWindow;
	IBOutlet NSTextField			*password;
	
	IBOutlet NSWindow				*newAlbum;
	IBOutlet NSTextField			*newAlbumName;
	
	IBOutlet NSWindow				*editSmartAlbum;
	IBOutlet NSTextField			*editSmartAlbumName, *editSmartAlbumQuery;
	
	IBOutlet NSDrawer				*albumDrawer;
	
	IBOutlet NSWindow				*rebuildWindow;
	IBOutlet NSMatrix				*rebuildType;
	IBOutlet NSTextField			*estimatedTime, *noOfFilesToRebuild, *warning;
	
	IBOutlet NSPopUpButton			*timeIntervalPopup;
	IBOutlet NSWindow				*customTimeIntervalWindow;
	IBOutlet NSDatePicker			*customStart, *customEnd, *customStart2, *customEnd2;
	IBOutlet NSView					*timeIntervalView;
	int								timeIntervalType;
	NSDate							*timeIntervalStart, * timeIntervalEnd;
	
	IBOutlet NSView					*searchView;
	IBOutlet NSSearchField			*searchField;
	NSToolbarItem					*toolbarSearchItem;
	int								searchType;
	
	IBOutlet NSWindow				*mainWindow;
	IBOutlet NSMenu					*imageTileMenu;
	IBOutlet NSWindow				*urlWindow;
	IBOutlet NSTextField			*urlString;
	
	IBOutlet NSForm					*rdPatientForm;
	IBOutlet NSForm					*rdPixelForm;
	IBOutlet NSForm					*rdVoxelForm;
	IBOutlet NSForm					*rdOffsetForm;
	IBOutlet NSMatrix				*rdPixelTypeMatrix;
	IBOutlet NSView					*rdAccessory;
	
	IBOutlet NSView					*exportQuicktimeView;
	IBOutlet NSButton				*exportHTMLButton;
	
	IBOutlet NSView					*exportAccessoryView;
	IBOutlet NSButton				*addDICOMDIRButton;
	IBOutlet NSMatrix				*compressionMatrix;
    IBOutlet NSMatrix				*folderTree;
	
	NSRecursiveLock					*checkIncomingLock;
	NSLock							*checkBonjourUpToDateThreadLock;
	NSTimeInterval					lastSaved;
	
    BOOL							showAllImages, DatabaseIsEdited, isNetworkLogsActive;
	NSConditionLock					*queueLock;
	
	IBOutlet NSScrollView			*thumbnailsScrollView;
	
	NSPredicate						*_fetchPredicate;
	NSPredicate						*_filterPredicate;
	NSString						*_filterPredicateDescription;
	
	NSString						*fixedDocumentsDirectory;
	
	char							cfixedDocumentsDirectory[ 1024];
	
	NSTimeInterval					databaseLastModification;
	
	StructuredReportController		*structuredReportController;
	
	NSMutableArray					*deleteQueueArray;
	NSLock							*deleteQueue, *deleteInProgress;
	
	NSMutableArray					*autoroutingQueueArray;
	NSLock							*autoroutingQueue, *autoroutingInProgress, *matrixLoadIconsLock;
	
	NSConditionLock					*processorsLock;
	NSLock							*decompressArrayLock, *decompressThreadRunning;
	NSMutableArray					*decompressArray;
	
	NSMutableString					*pressedKeys;
	
	IBOutlet NSView					*reportTemplatesView;
	IBOutlet NSImageView			*reportTemplatesImageView;
	IBOutlet NSPopUpButton			*reportTemplatesListPopUpButton;
	
	NSConditionLock					*newFilesConditionLock;
	NSMutableArray					*viewersListToReload, *viewersListToRebuild;
	
	NSImage							*notFoundImage;
	
	volatile BOOL					newFilesInIncoming;
	NSImage							*standardOsiriXIcon;
	NSImage							*downloadingOsiriXIcon;
	NSImage							*currentIcon;
	
	BOOL							rtstructProgressBar;  // make visible
	float							rtstructProgressPercent;
	
	int								DicomDirScanDepth;
}

+ (BrowserController*) currentBrowser;
+ (void) replaceNotAdmitted:(NSMutableString*) name;
+ (NSArray*) statesArray;
+ (void) updateActivity;
+ (NSData*) produceJPEGThumbnail:(NSImage*) image;
- (IBAction) createDatabaseFolder:(id) sender;
- (void) openDatabasePath: (NSString*) path;
- (BOOL) shouldTerminate: (id) sender;
- (void) databaseOpenStudy: (NSManagedObject*) item;
- (IBAction) databaseDoublePressed:(id)sender;
- (void) setDBDate;
- (void) setDockIcon;
- (void) showEntireDatabase;
- (IBAction) querySelectedStudy:(id) sender;
- (NSPredicate*) smartAlbumPredicate:(NSManagedObject*) album;
- (NSPredicate*) smartAlbumPredicateString:(NSString*) string;
- (void) emptyDeleteQueueThread;
- (void) emptyDeleteQueue:(id) sender;
- (void) addFileToDeleteQueue:(NSString*) file;
- (NSString*) getNewFileDatabasePath: (NSString*) extension;
- (NSString*) getNewFileDatabasePath: (NSString*) extension dbFolder: (NSString*) dbFolder;
- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;
- (NSArray*) childrenArray: (NSManagedObject*) item;
- (NSArray*) childrenArray: (NSManagedObject*) item onlyImages:(BOOL) onlyImages;
- (NSArray*) imagesArray: (NSManagedObject*) item;
- (NSArray*) imagesArray: (NSManagedObject*) item preferredObject: (int) preferredObject;
- (NSArray*) imagesArray: (NSManagedObject*) item onlyImages:(BOOL) onlyImages;
- (NSArray*) imagesArray: (NSManagedObject*) item preferredObject: (int) preferredObject onlyImages:(BOOL) onlyImages;
- (NSManagedObjectContext *) managedObjectContextLoadIfNecessary:(BOOL) loadIfNecessary;
- (void) setNetworkLogs;
- (BOOL) isNetworkLogsActive;
- (NSTimeInterval) databaseLastModification;
- (IBAction) matrixDoublePressed:(id)sender;
- (void) addURLToDatabaseEnd:(id) sender;
- (void) addURLToDatabase:(id) sender;
- (NSArray*) addURLToDatabaseFiles:(NSArray*) URLs;
-(BOOL) findAndSelectFile: (NSString*) path image: (NSManagedObject*) curImage shouldExpand: (BOOL) expand;
-(BOOL) findAndSelectFile: (NSString*) path image: (NSManagedObject*) curImage shouldExpand: (BOOL) expand extendingSelection: (BOOL) extendingSelection;
- (IBAction) sendiDisk:(id) sender;
- (void) selectServer: (NSArray*) files;
- (void) loadDICOMFromiPod;
- (long) saveDatabase:(NSString*) path;
- (void) addDICOMDIR:(NSString*) dicomdir :(NSMutableArray*) files;
-(NSMutableArray*) copyFilesIntoDatabaseIfNeeded:(NSMutableArray*) filesInput;
-(NSMutableArray*) copyFilesIntoDatabaseIfNeeded:(NSMutableArray*) filesInput async: (BOOL) async;
-(void) loadSeries :(NSManagedObject *)curFile :(ViewerController*) viewer :(BOOL) firstViewer keyImagesOnly:(BOOL) keyImages;
-(void) loadNextPatient:(NSManagedObject *) curImage :(long) direction :(ViewerController*) viewer :(BOOL) firstViewer keyImagesOnly:(BOOL) keyImages;
-(void) loadNextSeries:(NSManagedObject *) curImage :(long) direction :(ViewerController*) viewer :(BOOL) firstViewer keyImagesOnly:(BOOL) keyImages;
- (void) openViewerFromImages:(NSArray*) toOpenArray movie:(BOOL) movieViewer viewer:(ViewerController*) viewer keyImagesOnly:(BOOL) keyImages;
- (void) export2PACS:(id) sender;
- (void) queryDICOM:(id) sender;
-(void) exportQuicktimeInt:(NSArray*) dicomFiles2Export :(NSString*) path :(BOOL) html;
- (IBAction) delItem:(id) sender;
- (void) delItemMatrix: (NSManagedObject*) obj;
- (IBAction) selectFilesAndFoldersToAdd:(id) sender;
- (void) showDatabase:(id)sender;
-(IBAction) matrixPressed:(id)sender;
-(void) loadDatabase:(NSString*) path;
- (NSArray*) matrixViewArray;
- (void) viewerDICOMInt:(BOOL) movieViewer dcmFile:(NSArray *)selectedLines viewer:(ViewerController*) viewer;
- (void) viewerDICOMInt:(BOOL) movieViewer dcmFile:(NSArray *)selectedLines viewer:(ViewerController*) viewer tileWindows: (BOOL) tileWindows;
- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem;
- (NSArray*) exportDICOMFileInt:(NSString*) location files:(NSArray*) filesToExport objects:(NSArray*) dicomFiles2Export;

- (void) setupToolbar;

- (NSString*) getDatabaseFolderFor: (NSString*) path;
- (NSString*) getDatabaseIndexFileFor: (NSString*) path;

- (void) setCurrentBonjourService:(int) index;
- (IBAction)customize:(id)sender;
- (IBAction)showhide:(id)sender;
- (IBAction) selectAll3DSeries:(id) sender;
- (IBAction) selectAll4DSeries:(id) sender;
- (void) exportDICOMFile:(id) sender;
- (void) viewerDICOM:(id) sender;
- (void)newViewerDICOM:(id) sender;
- (void) viewerDICOMKeyImages:(id) sender;
- (void) viewerDICOMMergeSelection:(id) sender;
- (void) burnDICOM:(id) sender;
- (IBAction) anonymizeDICOM:(id) sender;
- (IBAction)addSmartAlbum: (id)sender;
- (IBAction)search: (id)sender;
- (IBAction)setSearchType: (id)sender;
- (void) setDraggedItems:(NSArray*) pbItems;
- (IBAction)setTimeIntervalType: (id)sender;
- (IBAction) endCustomInterval:(id) sender;
- (IBAction) customIntervalNow:(id) sender;
- (NSMatrix*) oMatrix;
- (IBAction) openDatabase:(id) sender;
- (IBAction) createDatabase:(id) sender;
- (void) openDatabaseIn:(NSString*) a Bonjour:(BOOL) isBonjour;

- (IBAction) endReBuildDatabase:(id) sender;
- (IBAction) ReBuildDatabase:(id) sender;
- (IBAction) ReBuildDatabaseSheet: (id)sender;
- (long) COLUMN;
- (BOOL) is2DViewer;
- (void) previewSliderAction:(id) sender;
- (void) addHelpMenu;

+ (BOOL) isItCD:(NSArray*) pathFilesComponent;
- (void)storeSCPComplete:(id)sender;
- (NSMutableArray *) filesForDatabaseOutlineSelection :(NSMutableArray*) correspondingDicomFile;
- (NSMutableArray *) filesForDatabaseOutlineSelection :(NSMutableArray*) correspondingManagedObjects onlyImages:(BOOL) onlyImages;
- (NSMutableArray *) filesForDatabaseMatrixSelection :(NSMutableArray*) correspondingManagedObjects;
- (NSMutableArray *) filesForDatabaseMatrixSelection :(NSMutableArray*) correspondingManagedObjects onlyImages:(BOOL) onlyImages;

- (void) resetListenerTimer;
- (IBAction) smartAlbumHelpButton:(id) sender;

- (NSArray*) addFilesToDatabase:(NSArray*) newFilesArray;
- (NSArray*) addFilesAndFolderToDatabase:(NSArray*) filenames;
- (NSArray*) addFilesToDatabase:(NSArray*) newFilesArray onlyDICOM:(BOOL) onlyDICOM safeRebuild:(BOOL) safeProcess produceAddedFiles:(BOOL) produceAddedFiles;
- (NSArray*) addFilesToDatabase:(NSArray*) newFilesArray onlyDICOM:(BOOL) onlyDICOM safeRebuild:(BOOL) safeProcess produceAddedFiles:(BOOL) produceAddedFiles parseExistingObject:(BOOL) parseExistingObject;
- (NSArray*) addFilesToDatabase:(NSArray*) newFilesArray onlyDICOM:(BOOL) onlyDICOM safeRebuild:(BOOL) safeProcess produceAddedFiles:(BOOL) produceAddedFiles parseExistingObject:(BOOL) parseExistingObject context: (NSManagedObjectContext*) context dbFolder:(NSString*) dbFolder;

//- (short) createAnonymizedFile:(NSString*) srcFile :(NSString*) dstFile;

//- (void)runSendQueue:(id)object;
//- (void)addToQueue:(NSArray *)array;
- (MyOutlineView*) databaseOutline;

-(void) previewPerformAnimation:(id) sender;
-(void) matrixDisplayIcons:(id) sender;
//- (void)reloadSendLog:(id)sender;
- (void) pdfPreview:(id)sender;
- (IBAction)importRawData:(id)sender;
- (void) setBurnerWindowControllerToNIL;

- (void) refreshColumns;
- (void) outlineViewRefresh;
- (void) matrixInit:(long) noOfImages;
- (IBAction) albumButtons: (id)sender;
- (NSArray*) albumArray;
- (void) refreshSmartAlbums;
- (void) waitForRunningProcesses;

- (NSArray*) imagesPathArray: (NSManagedObject*) item;

- (void) autoCleanDatabaseFreeSpace:(id) sender;
- (void) autoCleanDatabaseDate:(id) sender;

- (void) refreshDatabase:(id) sender;
- (void) syncReportsIfNecessary: (int) index;
- (void) removeAllMounted;
- (NSTableView*) albumTable;

//bonjour
- (void) getDICOMROIFiles:(NSArray*) files;
- (void) setBonjourDatabaseValue:(NSManagedObject*) obj value:(id) value forKey:(NSString*) key;
- (BOOL) isCurrentDatabaseBonjour;
- (void)setServiceName:(NSString*) title;
- (IBAction)toggleBonjourSharing:(id) sender;
- (void) setBonjourSharingEnabled:(BOOL) boo;
- (void) bonjourWillPublish;
- (void) bonjourDidStop;
- (IBAction) bonjourServiceClicked:(id)sender;
- (NSString*) currentDatabasePath;
- (void) setBonjourDownloading:(BOOL) v;
- (NSString*) getLocalDCMPath: (NSManagedObject*) obj :(long) no;
- (void) displayBonjourServices;
- (NSString*) localDatabasePath;
- (NSString*) askPassword;
- (NSString*) bonjourPassword;
- (long) currentBonjourService;
- (void) resetToLocalDatabase;
- (void) createContextualMenu;
- (NSBox*) bonjourSourcesBox;
- (NSTextField*) bonjourServiceName;
- (NSTextField*) bonjourPasswordTextField;
- (NSButton*) bonjourSharingCheck;
- (NSButton*) bonjourPasswordCheck;
- (void) bonjourRunLoop:(id) sender;
- (void) checkIncomingThread:(id) sender;
- (void) checkIncoming:(id) sender;
- (NSArray*) openSubSeries: (NSArray*) toOpenArray;
- (IBAction) checkMemory:(id) sender;
- (IBAction) buildAllThumbnails:(id) sender;

// Finding Comparisons
- (NSArray *)relatedStudiesForStudy:(id)study;

//DB plugins
- (void)executeFilterDB:(id)sender;

- (NSString *) documentsDirectory;
- (NSString *) documentsDirectoryFor:(int) mode url:(NSString*) url;
- (NSString *) fixedDocumentsDirectory;
- (char *) cfixedDocumentsDirectory;
- (NSString *) setFixedDocumentsDirectory;
- (IBAction)showLogWindow: (id)sender ;

- (NSString *)folderPathResolvingAliasAndSymLink:(NSString *)path;

- (NSString *)searchString;
- (void)setSearchString:(NSString *)searchString;
- (NSPredicate*)fetchPredicate;
- (void)setFetchPredicate:(NSPredicate *)predicate;
- (NSPredicate*)filterPredicate;
- (NSString*) filterPredicateDescription;
- (void)setFilterPredicate:(NSPredicate *)predicate description:(NSString*) desc;
- (NSPredicate *)createFilterPredicate;
- (NSString *)createFilterDescription;

- (IBAction) generateReport: (id) sender;
- (IBAction) deleteReport: (id) sender;
- (IBAction)srReports: (id)sender;

- (IBAction) rebuildThumbnails:(id) sender;

- (NSArray *)databaseSelection;

- (void) newFilesGUIUpdateRun:(int) state;
- (void) newFilesGUIUpdate:(id) sender;

- (IBAction) decompressSelectedFiles:(id) sender;
- (IBAction) compressSelectedFiles:(id) sender;
- (void) decompressArrayOfFiles: (NSArray*) array work:(NSNumber*) work;
- (void) decompressThread: (NSNumber*) typeOfWork;

-(void) compressDICOMJPEG:(NSString*) compressedPath;
-(void) decompressDICOMJPEG:(NSString*) compressedPath;

- (void)updateReportToolbarIcon:(NSNotification *)note;

- (BonjourBrowser *) bonjourBrowser;

- (void) initAnimationSlider;

+ (NSString*) DBDateOfBirthFormat:(NSDate*) d;
+ (NSString*) DBDateFormat:(NSDate*) d;
+ (NSString*) TimeFormat:(NSDate*) t;

//RTSTRUCT

- (BOOL)rtstructProgressBar;
- (void)setRtstructProgressBar: (BOOL)s;
- (float)rtstructProgressPercent;
- (void)setRtstructProgressPercent: (float)p;

/******Notifactions posted by browserController***********
@"NewStudySelectedNotification" with userinfo key @"Selected Study" posted when a newStudy is selected in the browser
@"Close All Viewers" posted when close open windows if option key pressed.	
@"DCMImageTilingHasChanged" when image tiling has changed
OsirixAddToDBNotification posted when files are added to the DB
*/

@end
