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

#import "OSIDatabasePreferencePanePref.h"
#import <OsiriXAPI/PluginManager.h>
#import <OsiriXAPI/BrowserController.h>
#import <OsiriXAPI/PreferencesWindowController+DCMTK.h>
#import <OsiriX/DCMAbstractSyntaxUID.h>
#import <OsiriXAPI/BrowserControllerDCMTKCategory.h>

@implementation OSIDatabasePreferencePanePref

- (id) initWithBundle:(NSBundle *)bundle
{
	if( self = [super init])
	{
		NSNib *nib = [[NSNib alloc] initWithNibNamed: @"OSIDatabasePreferencePanePref" bundle: nil];
		[nib instantiateNibWithOwner:self topLevelObjects: nil];
		
		[self setMainView: [mainWindow contentView]];
		[self mainViewDidLoad];
	}
	
	return self;
}

- (NSArray*) ListOfMediaSOPClassUID
{
	NSMutableArray *l = [NSMutableArray array];
	
	for( NSString *s in [DCMAbstractSyntaxUID imageSyntaxes])
		[l addObject: [NSString stringWithFormat: @"%@ - %@", s, [BrowserController compressionString: s]]];
	
	return l;
}

- (void) dealloc
{	
	NSLog(@"dealloc OSIDatabasePreferencePanePref");
	
	[DICOMFieldsArray release];
	
	[super dealloc];
}

- (void) buildPluginsMenu
{
	int numberOfReportPlugins = 0;
	for( NSString *k in [[PluginManager reportPlugins] allKeys])
	{
		[reportsMode addItemWithTitle: k];
		[[reportsMode lastItem] setIndentationLevel:1];
		numberOfReportPlugins++;
	}
	
	if( numberOfReportPlugins <= 0)
	{
		[reportsMode removeItemAtIndex:[reportsMode indexOfItem:[reportsMode lastItem]]];
		[reportsMode removeItemAtIndex:[reportsMode indexOfItem:[reportsMode lastItem]]];
	}
	else
	{
		if(numberOfReportPlugins == 1)
			[[reportsMode itemAtIndex:4] setTitle:@"Plugin"];
		[reportsMode setAutoenablesItems:NO];
		[[reportsMode itemAtIndex:4] setEnabled:NO];
	}
}

-(void) willUnselect
{
	[[[self mainView] window] makeFirstResponder: nil];
}

- (void) mainViewDidLoad
{


//	[[scrollView verticalScroller] setFloatValue: 0]; 
////	[[scrollView verticalScroller] setFloatValue:0.0 knobProportion:0.0]; //// now with bindings
//	[scrollView setVerticalScroller: [scrollView verticalScroller]];
	
//	[[scrollView contentView] scrollToPoint: NSMakePoint(600,600)];
	
	NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	
	//setup GUI
////	[copyDatabaseOnOffButton setState:[defaults boolForKey:@"COPYDATABASE"]]; //// now with bindings
	
//	[displayAllStudies setState:[defaults boolForKey:@"KeepStudiesOfSamePatientTogether"]];
	
	long locationValue = [defaults integerForKey:@"DEFAULT_DATABASELOCATION"];
	
	[locationMatrix selectCellWithTag:locationValue];
	[locationURLField setStringValue:[defaults stringForKey:@"DEFAULT_DATABASELOCATIONURL"]];
	[locationPathField setURL: [NSURL fileURLWithPath: [defaults stringForKey:@"DEFAULT_DATABASELOCATIONURL"]]];
	
//	[copyDatabaseModeMatrix setEnabled:[defaults boolForKey:@"COPYDATABASE"]];
////	[copyDatabaseModeMatrix selectCellWithTag:[defaults integerForKey:@"COPYDATABASEMODE"]];
	[localizerOnOffButton setState:[defaults boolForKey:@"NOLOCALIZER"]];
//	[multipleScreensMatrix selectCellWithTag:[defaults integerForKey:@"MULTIPLESCREENSDATABASE"]];
	[seriesOrderMatrix selectCellWithTag:[defaults integerForKey:@"SERIESORDER"]];
	
	
	// COMMENTS
	
	[commentsAutoFill setState:[defaults boolForKey:@"COMMENTSAUTOFILL"]];
	[commentsGroup setStringValue:[NSString stringWithFormat:@"0x%04X", [[defaults stringForKey:@"COMMENTSGROUP"] intValue]]];
	[commentsElement setStringValue:[NSString stringWithFormat:@"0x%04X", [[defaults stringForKey:@"COMMENTSELEMENT"] intValue]]];
	
	// REPORTS
	[self buildPluginsMenu];
	if([[defaults stringForKey:@"REPORTSMODE"] intValue] == 3)
	{
		[reportsMode selectItemWithTitle:[defaults stringForKey:@"REPORTSPLUGIN"]];
	}
	else
	{
		[reportsMode selectItemWithTag:[[defaults stringForKey:@"REPORTSMODE"] intValue]];
	}
	
	// DATABASE AUTO-CLEANING
	
	[older setState:[defaults boolForKey:@"AUTOCLEANINGDATE"]];
	[deleteOriginal setState:[defaults boolForKey:@"AUTOCLEANINGDELETEORIGINAL"]];
	[[olderType cellWithTag:0] setState:[defaults boolForKey:@"AUTOCLEANINGDATEPRODUCED"]];
	[[olderType cellWithTag:1] setState:[defaults boolForKey:@"AUTOCLEANINGDATEOPENED"]];
	[[olderType cellWithTag:2] setState:[defaults boolForKey:@"AUTOCLEANINGCOMMENTS"]];
	
	[commentsDeleteText setStringValue: [defaults stringForKey:@"AUTOCLEANINGCOMMENTSTEXT"]];
	[commentsDeleteMatrix selectCellWithTag:[[defaults stringForKey:@"AUTOCLEANINGDONTCONTAIN"] intValue]];
	[olderThanProduced selectItemWithTag:[[defaults stringForKey:@"AUTOCLEANINGDATEPRODUCEDDAYS"] intValue]];
	[olderThanOpened selectItemWithTag:[[defaults stringForKey:@"AUTOCLEANINGDATEOPENEDDAYS"] intValue]];
	
	[freeSpace setState:[defaults boolForKey:@"AUTOCLEANINGSPACE"]];
	[[freeSpaceType cellWithTag:0] setState:[defaults boolForKey:@"AUTOCLEANINGSPACEPRODUCED"]];
	[[freeSpaceType cellWithTag:1] setState:[defaults boolForKey:@"AUTOCLEANINGSPACEOPENED"]];
	[freeSpaceSize selectItemWithTag:[[defaults stringForKey:@"AUTOCLEANINGSPACESIZE"] intValue]];
	
}

- (void)didSelect
{
	DICOMFieldsArray = [[[[[self mainView] window] windowController] prepareDICOMFieldsArrays] retain];
	
	NSMenu *DICOMFieldsMenu = [dicomFieldsMenu menu];
	[DICOMFieldsMenu setAutoenablesItems:NO];
	[dicomFieldsMenu removeAllItems];
	
	NSMenuItem *item;
	item = [[[NSMenuItem alloc] init] autorelease];
	[item setTitle:NSLocalizedString( @"DICOM Fields", nil)];
	[item setEnabled:NO];
	[DICOMFieldsMenu addItem:item];
	int i;
	for (i=0; i<[DICOMFieldsArray count]; i++)
	{
		item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:[[DICOMFieldsArray objectAtIndex:i] title]];
		[item setRepresentedObject:[DICOMFieldsArray objectAtIndex:i]];
		[DICOMFieldsMenu addItem:item];
	}
	[dicomFieldsMenu setMenu:DICOMFieldsMenu];
}

- (IBAction) setReportMode:(id) sender
{
	// report mode int value
	// 0 : Microsoft Word
	// 1 : TextEdit
	// 2 : Pages
	// 3 : Plugin
	// 4 : DICOM SR
	// 5 : OO
	
	NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	
	int indexOfPluginsLabel = [reportsMode indexOfItemWithTitle:@"Plugins"];
	int indexOfPluginLabel = [reportsMode indexOfItemWithTitle:@"Plugin"];
	int indexOfLabel = (indexOfPluginsLabel>indexOfPluginLabel)?indexOfPluginsLabel:indexOfPluginLabel;
	
	indexOfLabel = (indexOfLabel<=0)? 10000 : indexOfLabel ;
	
	if([reportsMode indexOfSelectedItem] >= indexOfLabel) // in this case it is a plugin
	{
		[defaults setInteger:3 forKey:@"REPORTSMODE"];
		[defaults setObject:[[reportsMode selectedItem] title] forKey:@"REPORTSPLUGIN"];
	}
	else
	{
		[defaults setInteger:[[reportsMode selectedItem] tag] forKey:@"REPORTSMODE"];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"reportModeChanged" object:nil];
}

// - (IBAction) setDisplayAllStudiesAlbum:(id) sender
// {
//	[[NSUserDefaults standardUserDefaults] setBool:[sender state] forKey:@"KeepStudiesOfSamePatientTogether"];
// }

- (IBAction)regenerateAutoComments:(id) sender
{
	[[BrowserController currentBrowser] regenerateAutoComments: sender];
}

- (IBAction) setAutoComments:(id) sender
{
	// COMMENTS
	
	[[NSUserDefaults standardUserDefaults] setBool: [commentsAutoFill state] forKey:@"COMMENTSAUTOFILL"];
	
	unsigned		val;
	NSScanner	*hexscanner;
	
	val = 0;
	hexscanner = [NSScanner scannerWithString:[commentsGroup stringValue]];
	[hexscanner scanHexInt:&val];
	[[NSUserDefaults standardUserDefaults] setInteger:val forKey:@"COMMENTSGROUP"];
	
	val = 0;
	hexscanner = [NSScanner scannerWithString:[commentsElement stringValue]];
	[hexscanner scanHexInt:&val];
	[[NSUserDefaults standardUserDefaults] setInteger:val forKey:@"COMMENTSELEMENT"];
	
	[commentsGroup setStringValue:[NSString stringWithFormat:@"0x%04X", [[[NSUserDefaults standardUserDefaults] stringForKey:@"COMMENTSGROUP"] intValue]]];
	[commentsElement setStringValue:[NSString stringWithFormat:@"0x%04X", [[[NSUserDefaults standardUserDefaults] stringForKey:@"COMMENTSELEMENT"] intValue]]];
}

- (IBAction) setDICOMFieldMenu: (id) sender;
{
	[commentsGroup setStringValue: [[[sender selectedItem] title] substringWithRange: NSMakeRange( 1, 6)]];
	[commentsElement setStringValue: [[[sender selectedItem] title] substringWithRange: NSMakeRange( 8, 6)]];
	
	[self setAutoComments: sender];
}

- (IBAction) databaseCleaning:(id)sender
{
	NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];

	if( [[olderType cellWithTag:0] state] == NSOffState && [[olderType cellWithTag:1] state] == NSOffState)
	{
		[older setState: NSOffState];
	}
	
	[defaults setBool:[older state] forKey:@"AUTOCLEANINGDATE"];
	[defaults setBool:[deleteOriginal state] forKey:@"AUTOCLEANINGDELETEORIGINAL"];
	
	[defaults setBool:[[olderType cellWithTag:0] state] forKey:@"AUTOCLEANINGDATEPRODUCED"];
	[defaults setBool:[[olderType cellWithTag:1] state] forKey:@"AUTOCLEANINGDATEOPENED"];
	[defaults setBool:[[olderType cellWithTag:2] state] forKey:@"AUTOCLEANINGCOMMENTS"];
	
	[defaults setInteger:[[commentsDeleteMatrix selectedCell] tag] forKey:@"AUTOCLEANINGDONTCONTAIN"];
	[defaults setObject:[commentsDeleteText stringValue] forKey:@"AUTOCLEANINGCOMMENTSTEXT"];
	
	[defaults setInteger:[[olderThanProduced selectedItem] tag] forKey:@"AUTOCLEANINGDATEPRODUCEDDAYS"];
	[defaults setInteger:[[olderThanOpened selectedItem] tag] forKey:@"AUTOCLEANINGDATEOPENEDDAYS"];


	[defaults setBool:[freeSpace state] forKey:@"AUTOCLEANINGSPACE"];
	[defaults setBool:[[freeSpaceType cellWithTag:0] state] forKey:@"AUTOCLEANINGSPACEPRODUCED"];
	[defaults setBool:[[freeSpaceType cellWithTag:1] state] forKey:@"AUTOCLEANINGSPACEOPENED"];
	[defaults setInteger:[[freeSpaceSize selectedItem] tag] forKey:@"AUTOCLEANINGSPACESIZE"];
}

//- (IBAction)setMultipleScreens:(id)sender{
//	[[NSUserDefaults standardUserDefaults] setInteger:[(NSMatrix *)[sender selectedCell] tag] forKey:@"MULTIPLESCREENSDATABASE"];
//}

- (IBAction)setSeriesOrder:(id)sender{
	[[NSUserDefaults standardUserDefaults] setInteger:[(NSMatrix *)[sender selectedCell] tag] forKey:@"SERIESORDER"];
}


- (IBAction)setLocation:(id)sender{
	
	if ([[sender selectedCell] tag] == 1)
	{
		if( [[[NSUserDefaults standardUserDefaults] stringForKey:@"DEFAULT_DATABASELOCATIONURL"] isEqualToString:@""]) [self setLocationURL: self];
		
		if( [[[NSUserDefaults standardUserDefaults] stringForKey:@"DEFAULT_DATABASELOCATIONURL"] isEqualToString:@""] == NO)
		{
			BOOL isDir;
			
			if (![[NSFileManager defaultManager] fileExistsAtPath:[[NSUserDefaults standardUserDefaults] stringForKey:@"DEFAULT_DATABASELOCATIONURL"] isDirectory:&isDir])
			{
				NSRunAlertPanel(@"OsiriX Database Location", @"This location is not valid. Select another location.", @"OK", nil, nil);
				
				[locationMatrix selectCellWithTag:0];
			}
		}
	}
	
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender selectedCell] tag] forKey:@"DEFAULT_DATABASELOCATION"];
	
	[[[[self mainView] window] windowController] reopenDatabase];
	
	[[[self mainView] window] makeKeyAndOrderFront: self];
}

- (IBAction) resetDate:(id) sender
{
	NSDateFormatter	*dateFormat = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormat setDateStyle: NSDateFormatterShortStyle];
	[dateFormat setTimeStyle: NSDateFormatterShortStyle];
	[[NSUserDefaults standardUserDefaults] setObject: [dateFormat dateFormat] forKey:@"DBDateFormat2"];
}

- (IBAction) resetDateOfBirth:(id) sender
{
	NSDateFormatter	*dateFormat = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormat setDateStyle: NSDateFormatterShortStyle];
	[[NSUserDefaults standardUserDefaults] setObject: [dateFormat dateFormat] forKey:@"DBDateOfBirthFormat2"];
}

- (IBAction)setLocationURL:(id)sender{
	//NSLog(@"setLocation URL");
		
	NSOpenPanel         *oPanel = [NSOpenPanel openPanel];
	long				result;
	
    [oPanel setCanChooseFiles:NO];
    [oPanel setCanChooseDirectories:YES];
	
	result = [oPanel runModalForDirectory:0L file:nil types: 0L];
    
    if (result == NSOKButton)
	{
		NSString	*location = [oPanel directory];
		
		if( [[location lastPathComponent] isEqualToString:@"OsiriX Data"])
		{
			NSLog( @"%@", [location lastPathComponent]);
			location = [location stringByDeletingLastPathComponent];
		}
		
		if( [[location lastPathComponent] isEqualToString:@"DATABASE"] && [[[location stringByDeletingLastPathComponent] lastPathComponent] isEqualToString:@"OsiriX Data"])
		{
			NSLog( @"%@", [location lastPathComponent]);
			location = [[location stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
		}
		
		[locationURLField setStringValue: location];
		[locationPathField setURL: [NSURL fileURLWithPath: location]];
		[[NSUserDefaults standardUserDefaults] setObject:location forKey:@"DEFAULT_DATABASELOCATIONURL"];
		[[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"DEFAULT_DATABASELOCATION"];
		[locationMatrix selectCellWithTag:1];
	}	
	else 
	{
		[locationURLField setStringValue: 0L];
		[locationPathField setURL: 0L];
		[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"DEFAULT_DATABASELOCATIONURL"];
		[[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"DEFAULT_DATABASELOCATION"];
		[locationMatrix selectCellWithTag:0];
	}
	
	[[[[self mainView] window] windowController] reopenDatabase];
	
	[[[self mainView] window] makeKeyAndOrderFront: self];
}

- (IBAction)setLocalizerOnOff:(id)sender{
	[[NSUserDefaults standardUserDefaults] setBool:[sender state] forKey:@"NOLOCALIZER"];

}

- (BOOL)useSeriesDescription{
	return  [[NSUserDefaults standardUserDefaults] boolForKey:@"useSeriesDescription"];
}

- (void)setUseSeriesDescription:(BOOL)value{
	[[NSUserDefaults standardUserDefaults] setBool:value forKey:@"useSeriesDescription"];
}

- (BOOL)splitMultiEchoMR{
	return  [[NSUserDefaults standardUserDefaults] boolForKey:@"splitMultiEchoMR"];
}

- (void)setSplitMultiEchoMR:(BOOL)value{
	[[NSUserDefaults standardUserDefaults] setBool:value forKey:@"splitMultiEchoMR"];
}
//		
//- (BOOL)combineProjectionSeries{
//	return [[NSUserDefaults standardUserDefaults] boolForKey:@"combineProjectionSeries"];
//}
//
//- (void)setCombineProjectionSeries:(BOOL)value{
//	[[NSUserDefaults standardUserDefaults] setBool:value forKey:@"combineProjectionSeries"];
//}

@end
