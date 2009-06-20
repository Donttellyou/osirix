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


#import "WaitRendering.h"
#import "BurnerWindowController.h"
#import <OsiriX/DCM.h>
#import "MutableArrayCategory.h"
#import "AnonymizerWindowController.h"
#import <DiscRecordingUI/DRSetupPanel.h>
#import <DiscRecordingUI/DRBurnSetupPanel.h>
#import <DiscRecordingUI/DRBurnProgressPanel.h>
#import  "BrowserController.h"

extern BrowserController  *browserWindow;

NSString* asciiString (NSString* name);

@implementation BurnerWindowController

- (void) createDMG:(NSString*) imagePath withSource:(NSString*) directoryPath
{
	NSFileManager *manager = [NSFileManager defaultManager];
	
	[manager removeFileAtPath:imagePath handler:nil];
	
	NSTask* makeImageTask = [[[NSTask alloc]init]autorelease];

	[makeImageTask setLaunchPath: @"/bin/sh"];

	NSString* cmdString = [NSString stringWithFormat: @"hdiutil create '%@' -srcfolder '%@'",
													  imagePath,
													  directoryPath];

	NSArray *args = [NSArray arrayWithObjects: @"-c", cmdString, nil];

	[makeImageTask setArguments:args];
	[makeImageTask launch];
	[makeImageTask waitUntilExit];
}

- (void)writeDMG:(id)object
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setRequiredFileType:@"dmg"];
	[savePanel setTitle:@"Save as DMG"];
	
	if( [savePanel runModalForDirectory:nil file: [[self folderToBurn] lastPathComponent]] == NSFileHandlingPanelOKButton)
	{
		WaitRendering		*wait = [[WaitRendering alloc] init: NSLocalizedString(@"Writing DMG file...", nil)];
		[wait showWindow:self];
		
		[self createDMG:[[savePanel URL] path] withSource:[self folderToBurn]];
		
		[wait close];
		[wait release];
		
		[sizeField setStringValue: NSLocalizedString( @"DMG writing is finished !", nil)];
	}
	
	NSFileManager *manager = [NSFileManager defaultManager];
	[manager removeFileAtPath:[self folderToBurn] handler:nil];
	
	[nameField setEnabled: YES];
	[compressionMode setEnabled: YES];
	[anonymizedCheckButton setEnabled: YES];
	[misc1 setEnabled: YES];
	[misc2 setEnabled: YES];
	[misc3 setEnabled: YES];
	[misc4 setEnabled: YES];
}

- (void) copyDefaultsSettings
{
	burnSuppFolder = [[NSUserDefaults standardUserDefaults] boolForKey: @"BurnSupplementaryFolder"];
	burnOsiriX = [[NSUserDefaults standardUserDefaults] boolForKey: @"BurnOsirixApplication"];
	burnHtml = [[NSUserDefaults standardUserDefaults] boolForKey: @"BurnHtml"];
}

- (void) restoreDefaultsSettings
{
	[[NSUserDefaults standardUserDefaults] setBool: burnSuppFolder forKey:@"BurnSupplementaryFolder"];
	[[NSUserDefaults standardUserDefaults] setBool: burnOsiriX forKey:@"BurnOsirixApplication"];
	[[NSUserDefaults standardUserDefaults] setBool: burnHtml forKey:@"BurnHtml"];
}

-(id) initWithFiles:(NSArray *)theFiles
{
    if (self = [super initWithWindowNibName:@"BurnViewer"]) {
		
		[self copyDefaultsSettings];
		
		[[NSFileManager defaultManager] removeFileAtPath:[self folderToBurn] handler:nil];
		
		files = [theFiles retain];
		burning = NO;
		
		[[self window] center];
		
		NSLog( @"Burner allocated");
	}
	return self;
}

- (id)initWithFiles:(NSArray *)theFiles managedObjects:(NSArray *)managedObjects
{
	if (self = [super initWithWindowNibName:@"BurnViewer"])
	{
		[self copyDefaultsSettings];
		
		[[NSFileManager defaultManager] removeFileAtPath:[self folderToBurn] handler:nil];
		
		files = [theFiles retain];
		dbObjects = [managedObjects retain];
		id managedObject;
		id patient = nil;
		_multiplePatients = NO;
		
		[[[BrowserController currentBrowser] managedObjectContext] lock];
		
		for (managedObject in managedObjects)
		{
			id newPatient = [managedObject valueForKeyPath:@"series.study.patientUID"];
			
			if (patient == nil)
				patient = newPatient;
			else if (![patient isEqualToString:newPatient])
			{
				_multiplePatients = YES;
				break;
			}
			patient = newPatient;
		}
		
		[[[BrowserController currentBrowser] managedObjectContext] unlock];
		
		burning = NO;
		
		[[self window] center];
		
		NSLog( @"Burner allocated");
	}
	return self;
}

- (void)windowDidLoad{	
	NSLog(@"BurnViewer did load");
	
	[[self window] setDelegate:self];
	[self setup:nil];
	
	[compressionMode selectCellWithTag: [[NSUserDefaults standardUserDefaults] integerForKey: @"Compression Mode for Burning"]];
}

- (void)dealloc
{
	runBurnAnimation = NO;

	[browserWindow setBurnerWindowControllerToNIL];
		
	[anonymizedFiles release];
	[filesToBurn release];
	[dbObjects release];
	[cdName release];
	NSLog(@"Burner dealloc");	
	[super dealloc];
}


//------------------------------------------------------------------------------------------------------------------------------------
#pragma mark•

- (NSArray *)filesToBurn
{
	return filesToBurn;
}

- (void)setFilesToBurn:(NSArray *)theFiles
{
	[filesToBurn release];
	//filesToBurn = [self extractFileNames:theFiles];
	filesToBurn = [theFiles retain];
	//[filesTableView reloadData];
}

- (void)setIsBurning: (BOOL)value{
	burning = value;
}
- (BOOL)isBurning{
	return burning;
}



- (NSArray *)extractFileNames:(NSArray *)filenames
{
    NSString *pname;
    NSString *fname;
    NSString *pathName;
    BOOL isDir;

    NSMutableArray *fileNames = [[[NSMutableArray alloc] init] autorelease];
	//NSLog(@"Extract");
    for (fname in filenames)
	{ 
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		//NSLog(@"fname %@", fname);
        NSFileManager *manager = [NSFileManager defaultManager];
        if ([manager fileExistsAtPath:fname isDirectory:&isDir] && isDir)
		{
            NSDirectoryEnumerator *direnum = [manager enumeratorAtPath:fname];
            //Loop Through directories
            while (pname = [direnum nextObject])
			{
                pathName = [fname stringByAppendingPathComponent:pname]; //make pathanme
                if ([manager fileExistsAtPath:pathName isDirectory:&isDir] && !isDir)
				{ //check for directory
					if ([DCMObject objectWithContentsOfFile:pathName decodingPixelData:NO])
					{
                        [fileNames addObject:pathName];
					}
                }
            } //while pname
                
        } //if
        //else if ([dicomDecoder dicomCheckForFile:fname] > 0) {
		else if ([DCMObject objectWithContentsOfFile:fname decodingPixelData:NO]) {	//Pathname
				[fileNames addObject:fname];
        }
		[pool release];
    } //while
    return fileNames;
}

//Actions
-(IBAction)burn:(id)sender
{
	if (!(isExtracting || isSettingUpBurn || burning))
	{
		[[NSFileManager defaultManager] removeFileAtPath:[self folderToBurn] handler:nil];
		
		[cdName release];
		cdName = [[nameField stringValue] retain];
		
		if( [cdName length] <= 0)
		{
			[cdName release];
			cdName = [[NSString stringWithString: @"UNTITLED"] retain];
		}
		
		[[NSFileManager defaultManager] removeFileAtPath:[self folderToBurn] handler:nil];
		[[NSFileManager defaultManager] removeFileAtPath:[NSString stringWithFormat:@"/tmp/burnAnonymized"] handler:nil];
		
		[nameField setEnabled: NO];
		[compressionMode setEnabled: NO];
		[anonymizedCheckButton setEnabled: NO];
		[misc1 setEnabled: NO];
		[misc2 setEnabled: NO];
		[misc3 setEnabled: NO];
		[misc4 setEnabled: NO];

		writeDMG = NO;
		if ([[[NSApplication sharedApplication] currentEvent] modifierFlags]  & NSShiftKeyMask) writeDMG = YES;

		if( [[NSUserDefaults standardUserDefaults] boolForKey:@"anonymizedBeforeBurning"])
		{
			AnonymizerWindowController	*anonymizer = [[AnonymizerWindowController alloc] init];
			
			[anonymizer setFilesToAnonymize:files :dbObjects];
			[anonymizer showWindow:self];
			
			[[NSFileManager defaultManager] createDirectoryAtPath: [NSString stringWithFormat:@"/tmp/burnAnonymized"] attributes:nil];
			[anonymizer anonymizeToThisPath: [NSString stringWithFormat:@"/tmp/burnAnonymized"]];
			
			[anonymizedFiles release];
			anonymizedFiles = [[anonymizer producedFiles] retain];
		}
		else
		{
			[anonymizedFiles release];
			anonymizedFiles = nil;
		}
		
		if (cdName != nil && [cdName length] > 0)
		{
			runBurnAnimation = YES;
			[NSThread detachNewThreadSelector:@selector(burnAnimation:) toTarget:self withObject:nil];
			[NSThread detachNewThreadSelector:@selector(performBurn:) toTarget:self withObject:nil];
		}
		else
			NSBeginAlertSheet( NSLocalizedString( @"Burn Warning", nil) , NSLocalizedString( @"OK", nil), nil, nil, nil, nil, nil, nil, nil, NSLocalizedString( @"Please add CD name", nil));
	}
}

- (void)performBurn: (id) object
{	 
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	isSettingUpBurn = YES;
	[self addDicomdir];
	isSettingUpBurn = NO;
	
	int no = 0;
	
	if( anonymizedFiles) no = [anonymizedFiles count];
	else no = [files count];
	
	if( no)
	{
		if( writeDMG) [self performSelectorOnMainThread:@selector(writeDMG:) withObject:nil waitUntilDone:YES];
		else [self performSelectorOnMainThread:@selector(burnCD:) withObject:nil waitUntilDone:YES];
	}
	
	burning = NO;
	runBurnAnimation = NO;

	[pool release];
}

- (IBAction) setAnonymizedCheck: (id) sender
{
	if( [anonymizedCheckButton state] == NSOnState)
	{
		if( [[nameField stringValue] isEqualToString: [self defaultTitle]])
		{
			NSDate *date = [NSDate date];
			[self setCDTitle: [NSString stringWithFormat:@"Archive-%@",  [date descriptionWithCalendarFormat:@"%Y%m%d" timeZone:nil locale:nil]]];
		}
	}
}

- (void)setCDTitle: (NSString *)title
{
	if (title)
	{
		[cdName release];
		//if ([title length] > 8)
		//	title = [title substringToIndex:8];
		cdName = [asciiString([title uppercaseString]) retain];
		[nameField setStringValue: cdName];
	}
}

-(IBAction)setCDName:(id)sender
{
	NSString *name = [[nameField stringValue] uppercaseString];
	[self setCDTitle:name];
	NSLog(cdName);
}

-(NSString *)folderToBurn
{
	return [NSString stringWithFormat:@"/tmp/%@",cdName];
}

- (void)burnCD:(id)object
{
	BOOL continueToBurn = YES;
	
	sizeInMb = [[self getSizeOfDirectory: [self folderToBurn]] intValue] / 1024;
	
	if( continueToBurn)
	{
		DRTrack*	track = [self createTrack];

		if (track)
		{
			DRBurnSetupPanel*	bsp = [DRBurnSetupPanel setupPanel];

			// We'll be the delegate for the setup panel. This allows us to show off some 
			// of the customization you can do.
			[bsp setDelegate:self];
			
			if ([bsp runSetupPanel] == NSOKButton)
			{
				DRBurnProgressPanel*	bpp = [DRBurnProgressPanel progressPanel];

				[bpp setDelegate:self];
				
				// If you wanted to run this as a sheet you would have sent
				[bpp beginProgressSheetForBurn:[bsp burnObject] layout:track modalForWindow: [self window]];
			}
			else
				runBurnAnimation = NO;
		}
	}
	
	[nameField setEnabled: YES];
	[compressionMode setEnabled: YES];
	[anonymizedCheckButton setEnabled: YES];
	[misc1 setEnabled: YES];
	[misc2 setEnabled: YES];
	[misc3 setEnabled: YES];
	[misc4 setEnabled: YES];
}


- (DRTrack *) createTrack
{
	DRFolder* rootFolder = [DRFolder folderWithPath:[self folderToBurn]];		
	return [DRTrack trackForRootFolder:rootFolder];
}


//------------------------------------------------------------------------------------------------------------------------------------
#pragma mark•

- (BOOL) validateMenuItem:(id)sender
{

	if ([sender action] == @selector(terminate:))
		return (burning == NO);		// No quitting while a burn is going on

	return YES;
}


//#pragma mark Setup Panel Delegate Methods
/* We're implementing some of these setup panel delegate methods to illustrate what you could do to control a
	burn setup. */
	

/* This delegate method is called when a device is plugged in and becomes available for use. It's also
	called for each device connected to the machine when the panel is first shown. 
	
	Its's possible to query the device and ask it just about anything to determine if it's a device
	that should be used.
	
	Just return YES for a device you want and NO for those you don't. */
	
/*
- (BOOL) setupPanel:(DRSetupPanel*)aPanel deviceCouldBeTarget:(DRDevice*)device
{

#if 0
	// This bit of code shows how to filter devices bases on the properties of the device
	// For example, it's possible to limit the drives displayed to only those hooked up over
	// firewire, or converesely, you could NOT show drives if there was some reason to. 
	NSDictionary*	deviceInfo = [device info];
	if ([[deviceStatus objectForKey:DRDevicePhysicalInterconnectKey] isEqualToString:DRDevicePhysicalInterconnectFireWire])
		return YES;
	else
		return NO;
#else
	return YES;
#endif

}
 */ 
 
/*" This delegate method is called whenever the state of the media changes. This includes
	not only inserting and ejecting media, but also if some other app grabs the reservation,
	starts using it, etc.
	
	When we get sent this we're going to do a little bit of work to try to play nice with
	the rest of the world, but it essentially comes down to "is it a CDR or CDRW" that we
	care about. We could also check to see if there's enough room for our data (maybe the
	user stuck in a mini 2" CD or we need an 80 min CD).
	
	allows the delegate to determine if the media inserted in the 
	device is suitable for whatever operation is to be performed. The delegate should
	return a string to be used in the setup panel to inform the user of the 
	media status. If this method returns %NO, the default button will be disabled.
"*/

- (BOOL) setupPanel:(DRSetupPanel*)aPanel deviceContainsSuitableMedia:(DRDevice*)device promptString:(NSString**)prompt; 
{
	NSDictionary *status = [device status];
	
	int freeSpace = [[[status objectForKey: DRDeviceMediaInfoKey] objectForKey: DRDeviceMediaBlocksFreeKey] longLongValue] * 2UL / 1024UL;
	
	if( freeSpace > 0 && sizeInMb >= freeSpace)
	{
		*prompt = [NSString stringWithFormat: NSLocalizedString(@"The data to burn is larger than a media size (%d MB), you need a DVD to burn this amount of data (%d MB).", nil), freeSpace, sizeInMb];
		return NO;
	}
	else if( freeSpace > 0)
	{
		*prompt = [NSString stringWithFormat: NSLocalizedString(@"Data to burn: %d MB (Media size: %d MB), representing %2.2f %%.", nil), sizeInMb, freeSpace, (float) sizeInMb * 100. / (float) freeSpace];
	}
	
	return YES;

}

//#pragma mark Progress Panel Delegate Methods

/* Here we are setting up this nice little instance variable that prevents the app from
	quitting while a burn is in progress. This gets checked up in validateMenu: and we'll
	set it to NO in burnProgressPanelDidFinish: */
	
	
- (void) burnProgressPanelWillBegin:(NSNotification*)aNotification
{

	burning = YES;	// Keep the app from being quit from underneath the burn.
	isThrobbing = NO;
	burnAnimationIndex = 0;

}

- (void) burnProgressPanelDidFinish:(NSNotification*)aNotification
{
	NSFileManager *manager = [NSFileManager defaultManager];
	[manager removeFileAtPath:[self folderToBurn] handler:nil];
	burning = NO;	// OK we can quit now.
	runBurnAnimation = NO;
}

- (BOOL) burnProgressPanel:(DRBurnProgressPanel*)theBurnPanel burnDidFinish:(DRBurn*)burn
{
	NSDictionary*	burnStatus = [burn status];
	NSString*		state = [burnStatus objectForKey:DRStatusStateKey];
	
	if ([state isEqualToString:DRStatusStateFailed])
	{
		NSDictionary*	errorStatus = [burnStatus objectForKey:DRErrorStatusKey];
		NSString*		errorString = [errorStatus objectForKey:DRErrorStatusErrorStringKey];
		
		NSRunCriticalAlertPanel( NSLocalizedString( @"Burning failed", nil), errorString, NSLocalizedString( @"OK", nil), nil, nil);
	}
	else
		[sizeField setStringValue: NSLocalizedString( @"Burning is finished !", nil)];
	
	burning = NO;
	
	[[self window] performClose:nil];
	
	return YES;
}

- (void)windowWillClose:(NSNotification *)notification
{
	[[NSUserDefaults standardUserDefaults] setInteger: [compressionMode selectedTag] forKey:@"Compression Mode for Burning"];
	
	NSLog(@"Burner windowWillClose");
	
	[self restoreDefaultsSettings];
	
	[[self window] setDelegate: nil];
	
	isIrisAnimation = NO;
	isThrobbing = NO;
	isExtracting = NO;
	isSettingUpBurn = NO;
	burning = NO;
	runBurnAnimation = NO;
	
	[self release];
}

- (BOOL)windowShouldClose:(id)sender
{
	NSLog(@"Burner windowShouldClose");
	
	if ((isExtracting || isSettingUpBurn || burning))
		return NO;
	else
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		[manager removeFileAtPath: [self folderToBurn] handler:nil];
		[manager removeFileAtPath: [NSString stringWithFormat:@"/tmp/burnAnonymized"] handler:nil];
		[manager removeFileAtPath: [self folderToBurn] handler:nil];
		
		[filesToBurn release];
		filesToBurn = nil;
		[files release];
		files = nil;
		[anonymizedFiles release];
		anonymizedFiles = nil;
		
		//[filesTableView reloadData];
		
		NSLog(@"Burner windowShouldClose YES");
		
		return YES;
	}
}


//------------------------------------------------------------------------------------------------------------------------------------
#pragma mark•

- (BOOL)dicomCheck:(NSString *)filename{
	//DicomDecoder *dicomDecoder = [[[DicomDecoder alloc] init] autorelease];
	DCMObject *dcmObject = [DCMObject objectWithContentsOfFile:filename decodingPixelData:NO];
	return (dcmObject) ? YES : NO;
}

- (void)importFiles:(NSArray *)filenames{
}

- (NSString*) defaultTitle
{
	NSString *title = nil;
	
	if ([files count] > 0)
	{
		NSString *file = [files objectAtIndex:0];
		DCMObject *dcmObject = [DCMObject objectWithContentsOfFile:file decodingPixelData:NO];
		title = [dcmObject attributeValueWithName:@"PatientsName"];
	}
	else title = @"UNTITLED";
	
	return asciiString([title uppercaseString]);
}

- (void)setup:(id)sender
{
	//NSLog(@"Set up burn");
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	isThrobbing = NO;
	runBurnAnimation = NO;
	[burnButton setEnabled:NO];
	isExtracting = YES;
	
	[self performSelectorOnMainThread:@selector(estimateFolderSize:) withObject:nil waitUntilDone:YES];
	isExtracting = NO;
	[NSThread detachNewThreadSelector:@selector(irisAnimation:) toTarget:self withObject:nil];
	[burnButton setEnabled:YES];
	
	NSString *title = nil;
	
	if (_multiplePatients || [[NSUserDefaults standardUserDefaults] boolForKey:@"anonymizedBeforeBurning"])
	{
		NSDate *date = [NSDate date];
		title = [NSString stringWithFormat:@"Archive-%@",  [date descriptionWithCalendarFormat:@"%Y%m%d" timeZone:nil locale:nil]];
	}
	else title = [[self defaultTitle] uppercaseString];
	
	[self setCDTitle: title];
	[pool release];
}


//------------------------------------------------------------------------------------------------------------------------------------
#pragma mark•

- (void)addDICOMDIRUsingDCMTK
{
	NSString *burnFolder = [self folderToBurn];
	
	NSTask              *theTask;
	//NSMutableArray *theArguments = [NSMutableArray arrayWithObjects:@"+r", @"-W", @"-Nxc", @"*", nil];
	NSMutableArray *theArguments = [NSMutableArray arrayWithObjects:@"+r", @"-Pfl", @"-W", @"-Nxc",@"+I",@"+id", burnFolder,  nil];
	//NSLog(@"burn args: %@", [theArguments description]);
	theTask = [[NSTask alloc] init];
	[theTask setEnvironment:[NSDictionary dictionaryWithObject:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"/dicom.dic"] forKey:@"DCMDICTPATH"]];	// DO NOT REMOVE !
	[theTask setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"/dcmmkdir"]];
	[theTask setCurrentDirectoryPath:[self folderToBurn]];
	[theTask setArguments:theArguments];		

	[theTask launch];
	[theTask waitUntilExit];
	[theTask release];
}

- (void) produceHtml:(NSString*) burnFolder
{
	[[BrowserController currentBrowser] exportQuicktimeInt:dbObjects :burnFolder :YES];
}

- (NSNumber*)getSizeOfDirectory:(NSString*)path
{
	if( [[NSFileManager defaultManager] fileExistsAtPath: path] == NO) return [NSNumber numberWithLong: 0];

	if( [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:NO]fileType]!=NSFileTypeSymbolicLink || [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:NO]fileType]!=NSFileTypeUnknown)
	{
		NSArray *args;
		NSPipe *fromPipe;
		NSFileHandle *fromDu;
		NSData *duOutput;
		NSString *size;
		NSArray *stringComponents;
		char aBuffer[70];

		args = [NSArray arrayWithObjects:@"-ks",path,nil];
		fromPipe=[NSPipe pipe];
		fromDu=[fromPipe fileHandleForWriting];
		NSTask *duTool=[[[NSTask alloc] init] autorelease];

		[duTool setLaunchPath:@"/usr/bin/du"];
		[duTool setStandardOutput:fromDu];
		[duTool setArguments:args];
		[duTool launch];
		[duTool waitUntilExit];
		
		duOutput=[[fromPipe fileHandleForReading] availableData];
		[duOutput getBytes:aBuffer];
		
		size=[NSString stringWithCString:aBuffer];
		stringComponents=[size pathComponents];
		
		
		size=[stringComponents objectAtIndex:0];
		size=[size substringToIndex:[size length]-1];
		
		return [NSNumber numberWithUnsignedLongLong:(unsigned long long)[size doubleValue]];
	}
	else return [NSNumber numberWithUnsignedLongLong:(unsigned long long)0];
}

- (void)addDicomdir
{
	[finalSizeField performSelectorOnMainThread:@selector(setStringValue:) withObject:@"" waitUntilDone:YES];

	//NSLog(@"add Dicomdir");
	NS_DURING
	NSEnumerator *enumerator;
	if( anonymizedFiles) enumerator = [anonymizedFiles objectEnumerator];
	else enumerator = [files objectEnumerator];
	
	NSString *file;
	NSString *burnFolder = [self folderToBurn];
	NSString *dicomdirPath = [NSString stringWithFormat:@"%@/DICOMDIR",burnFolder];
	NSString *subFolder = [NSString stringWithFormat:@"%@/IMAGES",burnFolder];
	NSFileManager *manager = [NSFileManager defaultManager];
	int i = 0;

//create burn Folder and dicomdir.
	
	if (![manager fileExistsAtPath:burnFolder])
		[manager createDirectoryAtPath:burnFolder attributes:nil];
	if (![manager fileExistsAtPath:subFolder])
		[manager createDirectoryAtPath:subFolder attributes:nil];
	if (![manager fileExistsAtPath:dicomdirPath])
		[manager copyPath:[[NSBundle mainBundle] pathForResource:@"DICOMDIR" ofType:nil] toPath:dicomdirPath handler:nil];
		
	NSMutableArray *newFiles = [NSMutableArray array];
	NSMutableArray *compressedArray = [NSMutableArray array];
	
	while (file = [enumerator nextObject])
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSString *newPath = [NSString stringWithFormat:@"%@/%05d", subFolder, i++];
		DCMObject *dcmObject = [DCMObject objectWithContentsOfFile:file decodingPixelData:NO];
		//Don't want Big Endian, May not be readable
		if ([[dcmObject transferSyntax] isEqualToTransferSyntax:[DCMTransferSyntax ExplicitVRBigEndianTransferSyntax]])
			[dcmObject writeToFile:newPath withTransferSyntax:[DCMTransferSyntax ImplicitVRLittleEndianTransferSyntax] quality: DCMLosslessQuality atomically:YES];
		else
			[manager copyPath:file toPath:newPath handler:nil];
			
		if( dcmObject)	// <- it's a DICOM file
		{
			switch( [compressionMode selectedTag])
			{
				case 0:
				break;
				
				case 1:
					[compressedArray addObject: newPath];
				break;
				
				case 2:
					[compressedArray addObject: newPath];
				break;
			}
		}
		
		[newFiles addObject:newPath];
		[pool release];
	}
	
	if( [newFiles count] > 0)
	{	
		switch( [compressionMode selectedTag])
		{
			case 1:
				[browserWindow decompressArrayOfFiles: compressedArray work: [NSNumber numberWithChar: 'C']];
			break;
			
			case 2:
				[browserWindow decompressArrayOfFiles: compressedArray work: [NSNumber numberWithChar: 'D']];
			break;
		}
		
		[self addDICOMDIRUsingDCMTK];
		
		// Both these supplementary burn data are optional and controlled from a preference panel [DDP]
		
		if ([[NSUserDefaults standardUserDefaults] boolForKey: @"BurnOsirixApplication"])
		{
			NSString *OsiriXPath = [[NSBundle mainBundle] bundlePath];
			[manager copyPath:OsiriXPath toPath: [NSString stringWithFormat:@"%@/Osirix.app", burnFolder] handler:nil];
			
			// Remove 64-bit binaries
			
			NSString	*pathExecutable = [[NSBundle bundleWithPath: [NSString stringWithFormat:@"%@/Osirix.app", burnFolder]] executablePath];
			NSString	*pathLightExecutable = [[pathExecutable stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"light"];
			
			// **********
			
			@try
			{
				NSTask		*todo = [[[NSTask alloc]init]autorelease];
				[todo setLaunchPath: @"/usr/bin/lipo"];
				
				NSArray *args = [NSArray arrayWithObjects: pathExecutable, @"-remove", @"x86_64", @"-remove", @"ppc64", @"-output", pathLightExecutable, nil];

				[todo setArguments:args];
				[todo launch];
				[todo waitUntilExit];
				
				// **********
				
				todo = [[[NSTask alloc]init]autorelease];
				[todo setLaunchPath: @"/usr/bin/mv"];

				args = [NSArray arrayWithObjects:pathLightExecutable, pathExecutable, @"-f", nil];

				[todo setArguments:args];
				[todo launch];
				[todo waitUntilExit];
			}
			
			@catch( NSException *ne)
			{
				NSLog( @"lipo / mv exception");
			}
			
			if( [[NSFileManager defaultManager] fileExistsAtPath: pathLightExecutable])
			{
				[[NSFileManager defaultManager] removeFileAtPath: pathExecutable handler: nil];
				[[NSFileManager defaultManager] movePath: pathLightExecutable toPath: pathExecutable handler: nil];
			}
			// **********
		}
		
		if ( [[NSUserDefaults standardUserDefaults] boolForKey: @"BurnHtml"] == YES && [[NSUserDefaults standardUserDefaults] boolForKey:@"anonymizedBeforeBurning"] == NO)
		{
			[self performSelectorOnMainThread:@selector(produceHtml:) withObject:burnFolder waitUntilDone:YES];
		}
			
		// Look for and if present copy a second folder for eg windows viewer or html files.

		if ([[NSUserDefaults standardUserDefaults] boolForKey: @"BurnSupplementaryFolder"])
		{
			NSString *supplementaryBurnPath=[[NSUserDefaults standardUserDefaults] stringForKey: @"SupplementaryBurnPath"];
			if (supplementaryBurnPath)
			{
				supplementaryBurnPath=[supplementaryBurnPath stringByExpandingTildeInPath];
				if ([manager fileExistsAtPath: supplementaryBurnPath])
				{
					NSEnumerator *enumerator=[manager enumeratorAtPath: supplementaryBurnPath];
					while (file=[enumerator nextObject])
					{
						[manager copyPath: [NSString stringWithFormat:@"%@/%@", supplementaryBurnPath,file] toPath: [NSString stringWithFormat:@"%@/%@", burnFolder,file] handler:nil]; 
					}
				}
			}
		}
		
		if ([[NSUserDefaults standardUserDefaults] boolForKey: @"copyReportsToCD"])
		{
			NSMutableArray *studies = [NSMutableArray array];
			
			[[[BrowserController currentBrowser] managedObjectContext] lock];
			
			for( NSManagedObject *im in dbObjects)
			{
				if( [im valueForKeyPath:@"series.study.reportURL"])
				{
					if( [studies containsObject: [im valueForKeyPath:@"series.study"]] == NO)
						[studies addObject: [im valueForKeyPath:@"series.study"]];
				}
			}
			
			for( NSManagedObject *study in studies)
			{
				[manager copyPath: [study valueForKey:@"reportURL"] toPath: [NSString stringWithFormat:@"%@/Report-%@ %@.%@", burnFolder, [study valueForKey:@"modality"], [BrowserController DateTimeWithSecondsFormat: [study valueForKey:@"date"]], [[study valueForKey:@"reportURL"] pathExtension]] handler:nil]; 
			}
			
			[[[BrowserController currentBrowser] managedObjectContext] unlock];
		}
		
		[finalSizeField performSelectorOnMainThread:@selector(setStringValue:) withObject:[NSString stringWithFormat:@"Final files size to burn: %3.2fMB", (float) ([[self getSizeOfDirectory: burnFolder] longLongValue] / 1024)] waitUntilDone:YES];
	}
	
	NS_HANDLER
		NSLog(@"Exception while creating DICOMDIR: %@", [localException name]);
	NS_ENDHANDLER
}


- (IBAction) estimateFolderSize: (id) sender
{
	NSString				*file;
	long					size = 0;
	NSFileManager			*manager = [NSFileManager defaultManager];
	NSDictionary			*fattrs;
	
	for (file in files)
	{
		fattrs = [manager fileAttributesAtPath:file traverseLink:YES];
		size += [fattrs fileSize]/1024;
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"BurnOsirixApplication"])
	{
		size += [[self getSizeOfDirectory: [[NSBundle mainBundle] bundlePath]] longLongValue];
		
		#if __LP64__				// Remove the 64-bit binary
		size -= 44 * 1024;			// About 44 MB
		#endif
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"BurnSupplementaryFolder"])
	{
		size += [[self getSizeOfDirectory: [[NSUserDefaults standardUserDefaults] stringForKey: @"SupplementaryBurnPath"]] longLongValue];
	}
	
	[sizeField setStringValue:[NSString stringWithFormat:@"%@ %d  %@ %3.2fMB", NSLocalizedString(@"No of files:", nil), [files count], NSLocalizedString(@"Files size (without compression):", nil), size/1024.0]];
}


//------------------------------------------------------------------------------------------------------------------------------------
#pragma mark•

- (void)burnAnimation:(NSTimer *)timer
{
	isThrobbing = NO;
	while (runBurnAnimation)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSString *animation = [NSString stringWithFormat:@"burn_anim%02d", burnAnimationIndex++];
		NSString *path = [[NSBundle mainBundle] pathForResource:animation ofType:@"tif"];
		NSImage *image = [ [[NSImage alloc]  initWithContentsOfFile:path] autorelease];
		[burnButton setImage:image];
		if (burnAnimationIndex > 11)
			burnAnimationIndex = 0;
		
		[NSThread  sleepForTimeInterval:0.05];
		[pool release];
	}
}

-(void)irisAnimation:(id)object
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	int index = 0;
	isIrisAnimation = YES;
	while (index <= 13 && isIrisAnimation) {
		NSString *animation = [NSString stringWithFormat:@"burn_iris%02d", index++];
		NSString *path = [[NSBundle mainBundle] pathForResource:animation ofType:@"tif"];
		NSImage *image = [ [[NSImage alloc]  initWithContentsOfFile:path] autorelease];
		[burnButton setImage:image];
		[NSThread  sleepForTimeInterval:0.075];		
	}
	
	if( isIrisAnimation)
		[NSThread detachNewThreadSelector:@selector(throbAnimation:) toTarget:self withObject:nil];
		
	isIrisAnimation = NO;
	[pool release];
}

- (void)throbAnimation:(id)object
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	isThrobbing = YES;
	while (isThrobbing) {
		NSAutoreleasePool *subpool = [[NSAutoreleasePool alloc] init];
		NSString *path1 = [[NSBundle mainBundle] pathForResource:@"burn_anim00" ofType:@"tif"];
		NSImage *image = [ [[NSImage alloc]  initWithContentsOfFile:path1] autorelease];
		[burnButton setImage:image];
		[NSThread  sleepForTimeInterval:0.6];
		NSString *path2 = [[NSBundle mainBundle] pathForResource:@"burn_throb" ofType:@"tif"];
		NSImage *image2 = [[[NSImage alloc]  initWithContentsOfFile:path2] autorelease];
		
		[burnButton setImage:image2];
		[NSThread  sleepForTimeInterval:0.4];
		[subpool release];
	}
	[pool release];
}
@end
