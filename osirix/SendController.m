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

#import "BrowserController.h"
#import "SendController.h"
#import "Wait.h"
#import <OsiriX/DCMNetServiceDelegate.h>
#import <OsiriX/DCM.h>
#import "PluginFilter.h"
#import "PluginManager.h"
#import "DCMTKStoreSCU.h"
#import "MutableArrayCategory.h"
#import "Notifications.h"

static volatile int sendControllerObjects = 0;

@implementation SendController

+(int) sendControllerObjects
{
	return sendControllerObjects;
}

+ (void)sendFiles:(NSArray *)files toNode: (NSDictionary*) node
{
	BOOL s = [[NSUserDefaults standardUserDefaults] boolForKey: @"sendROIs"];

	[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"sendROIs"];
	
	SendController *sendController = [[SendController alloc] initWithFiles:files];
	
	[sendController sendToNode: node];
	
	[NSThread detachNewThreadSelector: @selector(releaseSelfWhenDone:) toTarget:sendController withObject: nil];
	
	[[NSUserDefaults standardUserDefaults] setBool: s forKey: @"sendROIs"];
}

+ (void)sendFiles:(NSArray *)files
{
	if( [[NSUserDefaults standardUserDefaults] boolForKey: @"DICOMSENDALLOWED"] == NO)
	{
		NSRunCriticalAlertPanel(NSLocalizedString(@"DICOM Send",nil),NSLocalizedString( @"DICOM Sending is not activated. Contact your PACS manager for more information about DICOM Send.",nil),NSLocalizedString( @"OK",nil), nil, nil);
		return;
	}

	if( [files  count])
	{
		if( [[DCMNetServiceDelegate DICOMServersListSendOnly: YES QROnly: NO] count] > 0)
		{
			SendController *sendController = [[SendController alloc] initWithFiles:files];
			[NSApp beginSheet: [sendController window] modalForWindow:[NSApp mainWindow] modalDelegate:sendController didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
			[NSThread detachNewThreadSelector: @selector(releaseSelfWhenDone:) toTarget:sendController withObject: nil];
		}
		else
		{
			NSRunCriticalAlertPanel(NSLocalizedString(@"DICOM Send",nil),NSLocalizedString( @"No DICOM destinations available. See Preferences to add DICOM locations.",nil),NSLocalizedString( @"OK",nil), nil, nil);
		}
	}
	else NSRunCriticalAlertPanel(NSLocalizedString(@"DICOM Send",nil),NSLocalizedString( @"No files are selected...",nil),NSLocalizedString( @"OK",nil), nil, nil);
}

- (id)initWithFiles:(NSArray *)files
{
	if (self = [super initWithWindowNibName:@"Send"])
	{
		NSLog( @"SendController initWithFiles");
		
		sendControllerObjects++;
		
		_abort = NO;
		_files = [files copy];
		int count = [_files  count];
		if(count == 1)
			[self setNumberFiles: [NSString stringWithFormat:NSLocalizedString(@"%d image", nil), count]];
		else if (count > 1)
			[self setNumberFiles: [NSString stringWithFormat:NSLocalizedString(@"%d images", nil), count]];
		
		
		_serverIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"lastSendServer"];	
		
		if( _serverIndex >= [[DCMNetServiceDelegate DICOMServersListSendOnly:YES QROnly: NO] count])
			_serverIndex = 0;
		
		_keyImageIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"lastSendWhat"];
		
		_readyForRelease = NO;
		_lock = [[NSRecursiveLock alloc] init];
		[_lock  lock];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setSendMessage:) name:OsirixDCMSendStatusNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												selector: @selector( updateDestinationPopup:)
												name: OsirixServerArrayChangedNotification
												object: nil];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												selector: @selector( updateDestinationPopup:)
												name: @"DCMNetServicesDidChange"
												object: nil];
	}
	return self;
}

- (void) windowDidLoad
{
	if 	([_files  count])
	{
		[self updateDestinationPopup: nil];
		
		int count = [[DCMNetServiceDelegate DICOMServersListSendOnly:YES QROnly:NO] count];
		if (_serverIndex < count)
			[newServerList selectItemAtIndex: _serverIndex];
			
//		[DICOMSendTool selectCellWithTag: _serverToolIndex];
		[keyImageMatrix selectCellWithTag: _keyImageIndex];
		
		[self selectServer: newServerList];
	}

}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	NSLog(@"SendController Released");
	[_destinationServer release];
	[_files release];
	[_transferSyntaxString release];
	[_numberFiles release];
	[_lock lock];
	[_lock unlock];
	[_lock release];
	
	[super dealloc];
}

- (void)releaseSelfWhenDone:(id)sender
{
	[_lock lock];
	[_lock unlock];
	[self release];
}

- (NSString *)numberFiles{
	return _numberFiles;
}

- (void)setNumberFiles:(NSString *)numberFiles
{
	[_numberFiles release];
	_numberFiles = [numberFiles retain];
}

- (id)server
{
	if( _destinationServer)
		return _destinationServer;
	
	return [self serverAtIndex:_serverIndex];
}


#pragma mark Accessors functions

- (id)serverAtIndex:(int)index
{
	NSArray *serversArray = [DCMNetServiceDelegate DICOMServersListSendOnly: YES QROnly:NO];
	
	if(	index > -1 && index < [serversArray count]) return [serversArray objectAtIndex:index];
	
	return nil;
}

- (IBAction)selectServer: (id)sender
{
	//NSLog(@"select server: %@", [sender description]);
	_serverIndex = [sender indexOfSelectedItem];
	
	[[NSUserDefaults standardUserDefaults] setInteger:_serverIndex forKey:@"lastSendServer"];
	
	if ([[self server] isKindOfClass:[NSDictionary class]])
	{
		int preferredTS = [[[self server] objectForKey:@"TransferSyntax"] intValue];
				
		if (preferredTS ==  SendExplicitLittleEndian || 
			preferredTS == SendImplicitLittleEndian || 
			preferredTS == SendRLE ||
			preferredTS == SendJPEGLossless)
				 [[NSUserDefaults standardUserDefaults] setInteger: preferredTS forKey:@"syntaxListOffis"];
	
	}	
	
	[addressAndPort setStringValue: [NSString stringWithFormat:@"%@ : %@", [[self server] objectForKey:@"Address"], [[self server] objectForKey:@"Port"]]];
}

- (int)keyImageIndex{
	return _keyImageIndex;
}

-(void)setKeyImageIndex:(int)index{
	_keyImageIndex = index;
	[[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"lastSendWhat"];
}

#pragma mark sheet functions

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo{
}

- (IBAction) endSelectServer:(id) sender
{
	NSLog(@"end select server");
	[[self window] orderOut:sender];
	[NSApp endSheet: [self window] returnCode:[sender tag]];
	NSArray *objectsToSend = _files;
	
	if( [sender tag])   //User clicks OK Button
    {		
		if (_keyImageIndex == 1)
		{
			NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isKeyImage == YES"];
			objectsToSend = [_files filteredArrayUsingPredicate:predicate];
		}
		
		if (_keyImageIndex == 2)
		{
			NSPredicate *predicate = [NSPredicate predicateWithFormat:@"modality CONTAINS[c] %@", @"SC"];
			objectsToSend = [objectsToSend filteredArrayUsingPredicate:predicate];
		}

		NSMutableArray	*files2Send = [objectsToSend valueForKey: @"completePath"];
		
		if( files2Send != nil && [files2Send count] > 0)
		{
//			if( !([[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSCommandKeyMask && [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSAlternateKeyMask))
//			{
//				// DONT REMOVE THESE LINES - THANX ANTOINE
//				if( [[PluginManager plugins] valueForKey:@"ComPACS"] != 0)
//				{
//					long result = [[[PluginManager plugins] objectForKey:@"ComPACS"] prepareFilter: nil];
//					
//					result = [[[PluginManager plugins] objectForKey:@"ComPACS"] filterImage: [NSString stringWithFormat:@"dicomSEND%@", [[objectsToSend objectAtIndex: 0] valueForKeyPath:@"series.study.patientUID"]]];
//					if( result != 0)
//					{
//						NSRunCriticalAlertPanel(NSLocalizedString(@"DICOM Send",nil),NSLocalizedString( @"Smart card authentification is required for DICOM sending.",nil),NSLocalizedString( @"OK",nil), nil, nil);
//						files2Send = nil;
//					}
//				}
//			}
			
			if( files2Send)
			{
				_waitSendWindow = [[Wait alloc] initWithString: NSLocalizedString(@"Sending files...", nil) :NO];
				[_waitSendWindow  setTarget:self];
				[_waitSendWindow showWindow:self];
				[[_waitSendWindow progress] setMaxValue:[files2Send count]];
				
				[_waitSendWindow setCancel:YES];
				
				sendROIs = [[NSUserDefaults standardUserDefaults] boolForKey:@"sendROIs"];
				[NSThread detachNewThreadSelector: @selector(sendDICOMFilesOffis:) toTarget:self withObject: objectsToSend];
			}
			else [_lock unlock];	// Will release the object
		}
		else [_lock unlock];	// Will release the object
	}
	else // Cancel
	{
		[_lock unlock];	// Will release the object
		sendControllerObjects--;
	}
}

- (void) sendToNode: (NSDictionary*) node
{
	_destinationServer = [node retain];
	
	_waitSendWindow = [[Wait alloc] initWithString: NSLocalizedString(@"Sending files...", nil) :NO];
	[_waitSendWindow  setTarget:self];
	[_waitSendWindow showWindow:self];
	[[_waitSendWindow progress] setMaxValue:[_files count]];
	
	[_waitSendWindow setCancel:YES];
	sendROIs = [[NSUserDefaults standardUserDefaults] boolForKey:@"sendROIs"];
	[NSThread detachNewThreadSelector: @selector(sendDICOMFilesOffis:) toTarget:self withObject: _files];
}

#pragma mark Sending functions	

- (void) showErrorMessage:(NSException*) ne
{
	NSString	*message = [NSString stringWithFormat:@"%@\r\r%@\r%@", NSLocalizedString( @"DICOM StoreSCU operation failed.", nil), [ne name], [ne reason]];

	NSRunCriticalAlertPanel(NSLocalizedString(@"DICOM Send Error",nil), message, NSLocalizedString( @"OK",nil), nil, nil);
}

- (void) executeSend :(NSArray*) samePatientArray
{
	if( _abort) return;
	
	NSArray	*files = [samePatientArray valueForKey: @"completePathResolved"];
	
	if( sendROIs)
	{
		NSLog( @"add ROIs for DICOM sending");
		NSMutableArray	*roiFiles = [NSMutableArray array];
		
		for( id loopItem in samePatientArray)
		{
			[roiFiles addObjectsFromArray: [loopItem valueForKey: @"SRPaths"]];
		}
		
		files = [files arrayByAddingObjectsFromArray: roiFiles];
	}
	
	// Send the collected files from the same patient
	
	NSString *calledAET = [[self server] objectForKey:@"AETitle"];
	NSString *hostname = [[self server] objectForKey:@"Address"];
	NSString *destPort = [[self server] objectForKey:@"Port"];
	
	storeSCU = [[DCMTKStoreSCU alloc] initWithCallingAET:[[NSUserDefaults standardUserDefaults] stringForKey: @"AETITLE"] 
			calledAET:calledAET 
			hostname:hostname 
			port:[destPort intValue] 
			filesToSend:files
			transferSyntax: [[NSUserDefaults standardUserDefaults] integerForKey:@"syntaxListOffis"]
			compression: 1.0
			extraParameters:nil];
	
	@try
	{
		[storeSCU run:self];
	}
	
	@catch( NSException *ne)
	{
		if( _waitSendWindow)
		{
			[self performSelectorOnMainThread:@selector(showErrorMessage:) withObject:ne waitUntilDone: NO];
		}
	}
	
	[storeSCU release];
	storeSCU = nil;
}

- (void) sendDICOMFilesOffis:(NSArray *) tempObjectsToSend
{
	NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];

	@try
	{
		NSSortDescriptor	*sort = [[[NSSortDescriptor alloc] initWithKey:@"series.study.patientUID" ascending:YES] autorelease];
		NSArray				*sortDescriptors = [NSArray arrayWithObject: sort];
		
		tempObjectsToSend = [tempObjectsToSend sortedArrayUsingDescriptors: sortDescriptors];

		NSString *calledAET = [[self server] objectForKey:@"AETitle"];
		
		if( calledAET == nil)
			calledAET = @"AETITLE";
		
		// Remove duplicated files 
		NSMutableArray *objectsToSend = [NSMutableArray arrayWithArray: tempObjectsToSend];
		NSMutableArray *paths = [NSMutableArray arrayWithArray: [objectsToSend valueForKey: @"completePathResolved"]];
		
		[paths removeDuplicatedStringsInSyncWithThisArray: objectsToSend];
		
		NSLog(@"Server destination: %@", [[self server] description]);	
				
		NSString			*previousPatientUID = nil;
		NSMutableArray		*samePatientArray = [NSMutableArray arrayWithCapacity: [objectsToSend count]];
		
		for( id loopItem in objectsToSend)
		{
			[[[BrowserController currentBrowser] managedObjectContext] lock];
			NSString *patientUID = [loopItem valueForKeyPath:@"series.study.patientUID"];
			[[[BrowserController currentBrowser] managedObjectContext] unlock];
			
			if( [previousPatientUID isEqualToString: patientUID])
			{
				[samePatientArray addObject: loopItem];
			}
			else
			{
				if( [samePatientArray count])
					[self executeSend: samePatientArray];
				
				// Reset
				[samePatientArray removeAllObjects];
				[samePatientArray addObject: loopItem];
				
				previousPatientUID = [[patientUID copy] autorelease];
			}
		}
		
		if( [samePatientArray count]) [self executeSend: samePatientArray];
		
		NSMutableDictionary *info = [NSMutableDictionary dictionary];
		[info setObject:[NSNumber numberWithInt:[objectsToSend count]] forKey:@"SendTotal"];
		[info setObject:[NSNumber numberWithInt:[objectsToSend count]] forKey:@"NumberSent"];
		[info setObject:[NSNumber numberWithBool:YES] forKey:@"Sent"];
		[info setObject:calledAET forKey:@"CalledAET"];
		
		sendControllerObjects--;
		
		[self performSelectorOnMainThread:@selector(closeSendPanel:) withObject:nil waitUntilDone: YES];	
	}
	@catch (NSException *e)
	{
		NSLog( @"***** sendDICOMFilesOffis exception: %@", e);
	}
	
	[pool release];
	
	//need to unlock to allow release of self after send complete
	[_lock performSelectorOnMainThread:@selector(unlock) withObject:nil waitUntilDone: NO];
}

- (void)closeSendPanel:(id)sender
{
	[_waitSendWindow close];			
	[_waitSendWindow release];			
	_waitSendWindow = nil;	
}

- (void) setSendMessageThread:(NSDictionary*) info
{
	if( _waitSendWindow)
	{
		[_waitSendWindow incrementBy:1];
		[[[_waitSendWindow window] contentView] setNeedsDisplay:YES];
	}
}

- (void)setSendMessage: (NSNotification *)note
{
	if( [note object] == storeSCU)
		[self performSelectorOnMainThread:@selector(setSendMessageThread:) withObject:[note userInfo] waitUntilDone:YES]; // <- GUI operations are permitted ONLY on the main thread
}

#pragma mark serversArray functions

- (void) updateDestinationPopup: (NSNotification *)note
{
	NSString *currentTitle = [[[newServerList selectedItem] title] retain];
	
	[newServerList removeAllItems];
	for( NSDictionary *d in [DCMNetServiceDelegate DICOMServersListSendOnly:YES QROnly:NO])
	{
		[newServerList addItemWithTitle: [NSString stringWithFormat:@"%@ - %@",[d objectForKey:@"AETitle"],[d objectForKey:@"Description"]]];
	}
	
	for( NSMenuItem *d in [newServerList itemArray])
	{
		if( [[d title] isEqualToString: currentTitle])
			[newServerList selectItem: d];
	}
	
	[currentTitle release];
}

- (void)listenForAbort:(id)handler
{
	[[_waitSendWindow window] orderOut:self];
	[storeSCU abort];
}

- (void)abort
{
	[self listenForAbort:nil];
	_abort = YES;
}


@end
