/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://homepage.mac.com/rossetantoine/osirix/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/




#import "ROIWindow.h"
#import "HistogramWindow.h"
#import "PlotWindow.h"
#import "DCMView.h"
#import "DCMPix.h"

@implementation ROIWindow

- (void)comboBoxWillPopUp:(NSNotification *)notification
{
	NSLog(@"will display...");
	roiNames = [curController generateROINamesArray];
	[[notification object] setDataSource: self];
	
	[[notification object] noteNumberOfItemsChanged];
	[[notification object] reloadData];
}

- (unsigned int)comboBox:(NSComboBox *)aComboBox indexOfItemWithStringValue:(NSString *)aString
{
	if( roiNames == 0L) roiNames = [curController generateROINamesArray];
	
	long i;
	
	for(i = 0; i < [roiNames count]; i++)
	{
		if( [[roiNames objectAtIndex: i] isEqualToString: aString]) return i;
	}
	
	return NSNotFound;
}

- (int)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
	if( roiNames == 0L) roiNames = [curController generateROINamesArray];
	return [roiNames count];
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index
{
    if ( index > -1 )
    {
		if( roiNames == 0L) roiNames = [curController generateROINamesArray];
		return [roiNames objectAtIndex: index];
    }
    
    return nil;
}


- (IBAction) roiSaveCurrent: (id) sender
{
	NSSavePanel     *panel = [NSSavePanel savePanel];
    short           i;
	
	NSMutableArray  *selectedROIs = [NSMutableArray  arrayWithObject:curROI];
	
	[panel setCanSelectHiddenExtension:NO];
	[panel setRequiredFileType:@"roi"];
	
	if( [panel runModalForDirectory:0L file:[[selectedROIs objectAtIndex:0] name]] == NSFileHandlingPanelOKButton)
	{
		[NSArchiver archiveRootObject: selectedROIs toFile :[panel filename]];
	}
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[super dealloc];
}

- (void) removeROI :(NSNotification*) note
{
	if( [note object] == curROI )
	{
		[self release];
	}
}

- (IBAction) recalibrate:(id) sender
{
    int		modalVal;
	float	pixels;
	float   newResolution;
	
    [NSApp beginSheet:recalibrateWindow 
            modalForWindow: [self window]
            modalDelegate:self 
            didEndSelector:NULL 
            contextInfo:NULL];
	
	[recalibrateValue setStringValue: [NSString stringWithFormat:@"%0.3f", (float) [curROI MesureLength :&pixels]] ];
	
    modalVal = [NSApp runModalForWindow:recalibrateWindow];
	
	if( modalVal)
	{
		newResolution = [recalibrateValue floatValue] / pixels;
		newResolution *= 10.0;
		NSLog(@"%2.2f", newResolution);
		
		NSMutableArray  *array = [curController pixList];
		
		long i;
		
		for( i = 0; i < [array count]; i++)
		{
			[[array objectAtIndex: i] setPixelSpacingX: newResolution];
			[[array objectAtIndex: i] setPixelSpacingY: newResolution];
		}
		
		[[NSNotificationCenter defaultCenter] postNotificationName: @"recomputeROI" object:curController userInfo: 0L];
	}
	
    [NSApp endSheet:recalibrateWindow];
    [recalibrateWindow orderOut:NULL];   
}

- (IBAction)acceptSheet:(id)sender
{
    [NSApp stopModalWithCode: [sender tag]];
}

- (void) setAllWithSameName: (BOOL) s {
	allWithSameName = s;
}

- (BOOL) allWithSameName {
	return allWithSameName;
}

- (IBAction) setSameName: (id) sender {
	allWithSameName = [sender state] == NSOnState;
}

- (void) setROI: (ROI*) iroi :(ViewerController*) c
{
	[curROI setComments: [comments string]];
	[curROI setName: [name stringValue]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: @"roiChange" object:curROI userInfo: 0L];

	curController = c;
	curROI = iroi;
	
	RGBColor	rgb = [curROI rgbcolor];
	NSColor		*color = [NSColor colorWithDeviceRed:rgb.red/65535. green: rgb.green/65535. blue:rgb.blue/65535. alpha:1.0];
	
	[colorButton setColor: color];
	
	NSNotificationCenter *nc;
    nc = [NSNotificationCenter defaultCenter];
    [nc addObserver: self
           selector: @selector(removeROI:)
               name: @"removeROI"
             object: nil];
	
	[thicknessSlider setFloatValue: [curROI thickness]];
	[opacitySlider setFloatValue: [curROI opacity]];
	
	[name setStringValue:[curROI name]];
	[comments setString:[curROI comments]];
		
	if( [curROI type] == tMesure) [recalibrate setEnabled: YES];
	else [recalibrate setEnabled: NO];
	
	if( [curROI type] == tMesure) [xyPlot setEnabled: YES];
	else [xyPlot setEnabled: NO];
	
	[self setAllWithSameName: NO];

}

- (id) initWithROI: (ROI*) iroi :(ViewerController*) c
{
	self = [super initWithWindowNibName:@"ROI"];
	
	[[self window] setFrameAutosaveName:@"ROIInfoWindow"];
	
	roiNames = 0L;
	
	[self setROI: iroi :c];
		
	return self;
}

- (void)windowWillClose:(NSNotification *)notification
{
	[curROI setComments: [comments string]];
	[curROI setName: [name stringValue]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: @"roiChange" object:curROI userInfo: 0L];
	
	[self release];
}

- (void) setAllMatchingROIsToSameParamsAs: (ROI*) iROI withNewName: (NSString*) newName {
	
	NSArray *roiSeriesList = [curController roiList];
	
	int i;
	
	for ( i = 0; i < [roiSeriesList count]; i++ ) {
		NSArray *roiImageList = [roiSeriesList objectAtIndex: i];
		int j;
		
		for ( j = 0; j < [roiImageList count]; j++ ) {
			ROI *roi = [roiImageList objectAtIndex: j ];
			
			if ( roi == curROI ) continue;
			
			if ( [[roi name] isEqualToString: [iROI name]] ) {
				[roi setColor: [iROI rgbcolor]];
				[roi setThickness: [iROI thickness]];
				[roi setOpacity: [iROI opacity]];
				if ( newName ) [roi setName: newName];
				[[NSNotificationCenter defaultCenter] postNotificationName: @"roiChange" object:roi userInfo: 0L];
			}
		}
	}
}

- (void) removeAllROIsWithName: (NSString*) roiName {
		
	NSArray *roiSeriesList = [curController roiList];
	
	int i;
	
	for ( i = 0; i < [roiSeriesList count]; i++ ) {
		NSMutableArray *roiImageList = [roiSeriesList objectAtIndex: i];
		int j;
		
		for ( j = 0; j < [roiImageList count]; j++ ) {
			ROI *roi = [roiImageList objectAtIndex: j ];
			
			if ( [[roi name] isEqualToString: roiName] ) {
				[roiImageList removeObjectAtIndex: j];
				j--;
			}
		}
	}
	[[curController imageView] setNeedsDisplay: YES];
	[self release];
}

//- (IBAction) deleteROI:(id) sender {
//	
//	[[NSNotificationCenter defaultCenter] removeObserver: self name: @"removeROI" object: nil];
//	
//	if ( allWithSameName ) {
//		[self removeAllROIsWithName: [curROI name]];
//		return;
//	}
//	
//	NSMutableArray *roiImageList = [[curController roiList] objectAtIndex: [[curROI curView] curImage]];
//	[roiImageList removeObject: curROI];
//
//	[[curController imageView] setNeedsDisplay: YES];
//	[self release];
//				
//}

- (IBAction) setTextData:(id) sender
{
	if ( allWithSameName ) [self setAllMatchingROIsToSameParamsAs: curROI withNewName: [sender stringValue]];
	
	[curROI setName: [sender stringValue]];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"roiChange" object:curROI userInfo: 0L];
}

- (IBAction) setThickness:(NSSlider*) sender
{
	[curROI setThickness: [sender floatValue]];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"roiChange" object:curROI userInfo: 0L];
	
	if ( allWithSameName ) [self setAllMatchingROIsToSameParamsAs: curROI withNewName: [curROI name]];
}

- (IBAction) setOpacity:(NSSlider*) sender
{
	[curROI setOpacity: [sender floatValue]];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"roiChange" object:curROI userInfo: 0L];
	
	if ( allWithSameName ) [self setAllMatchingROIsToSameParamsAs: curROI withNewName: [curROI name]];
}

- (IBAction) setColor:(NSColorWell*) sender
{
//	if( loaded == NO) return;
	
	float r, g, b;
	
	[[sender color] getRed:&r green:&g blue:&b alpha:0L];
	
	RGBColor c;
	
	c.red = r * 65535.;
	c.green = g * 65535.;
	c.blue = b * 65535.;
	
	[curROI setColor:c];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"roiChange" object:curROI userInfo: 0L];
	
	if ( allWithSameName ) [self setAllMatchingROIsToSameParamsAs: curROI withNewName: [curROI name]];

	[comments setTextColor:0L];
}



- (IBAction) exportData:(id) sender
{
	NSSavePanel     *panel = [NSSavePanel savePanel];
	
	[panel setCanSelectHiddenExtension:NO];
	[panel setRequiredFileType:@"xml"];
	
	if( [panel runModalForDirectory:0L file:[curROI name]] == NSFileHandlingPanelOKButton)
	{
		NSMutableDictionary *xml;
		NSMutableArray		*points, *temp;

		// allocate an NSMutableDictionary to hold our preference data
		xml = [[NSMutableDictionary alloc] init];
		
		[xml setObject:[curROI name] forKey:@"Name"];
		
		if ( allWithSameName ) {
			NSArray *roiSeriesList = [curController roiList];
			NSMutableArray *roiArray = [NSMutableArray arrayWithCapacity: 0];
			
			int i;			
			for ( i = 0; i < [roiSeriesList count]; i++ ) {
				NSArray *roiImageList = [roiSeriesList objectAtIndex: i];
				int j;
				
				for ( j = 0; j < [roiImageList count]; j++ ) {
					ROI *roi = [roiImageList objectAtIndex: j ];
										
					if ( [[roi name] isEqualToString: [curROI name]] ) {
						NSMutableDictionary *roiData = [[NSMutableDictionary alloc] init];
						
						[roiData setObject:[NSNumber numberWithInt: i + 1] forKey: @"Slice"];
						[roiData setObject:[roi comments] forKey:@"Comments"];
						
						// Points composing the ROI
						points = [roi points];
						temp = [NSMutableArray arrayWithCapacity:0];
						
						int k;
						for( k = 0 ; k < [points count]; k++)
							[temp addObject: NSStringFromPoint( [[points objectAtIndex: k] point]) ];

						[roiData setObject:temp forKey:@"ROIPoints"];
						
						[roiArray addObject: roiData];
						
					}
				}
			}
			
			[xml setObject: roiArray forKey: @"ROI array"];
		}
		
		else {  // Output curROI only
		
			[xml setObject:[curROI comments] forKey:@"Comments"];
			
			// Points composing the ROI
			points = [curROI points];
			temp = [NSMutableArray arrayWithCapacity:0];
			
			int i;
			for( i = 0 ; i < [points count]; i++)
			{
				[temp addObject: NSStringFromPoint( [[points objectAtIndex: i] point]) ];
			}
			[xml setObject:temp forKey:@"ROIPoints"];
			
			// Data composing the ROI
			[xml setObject:[curROI dataString] forKey:@"DataSummary"];
			[xml setObject:[curROI dataValues] forKey:@"DataValues"];
		}
		
		[xml writeToFile:[panel filename] atomically: TRUE];
		
		[xml release];
	}
}

- (IBAction) histogram:(id) sender
{
	NSArray *winList = [NSApp windows];
	BOOL	found = NO;
	long	i;
	
	for( i = 0; i < [winList count]; i++)
	{
		if( [[[[winList objectAtIndex:i] windowController] windowNibName] isEqualToString:@"Histogram"])
		{
			if( [[[winList objectAtIndex:i] windowController] curROI] == curROI)
			{
				found = YES;
				[[[[winList objectAtIndex:i] windowController] window] makeKeyAndOrderFront:self];
			}
		}
	}
	
	if( found == NO)
	{
		if( [[curROI points] count] > 0L)
		{
			HistoWindow* roiWin = [[HistoWindow alloc] initWithROI: curROI];
			[roiWin showWindow:self];
		}
		else NSRunAlertPanel(NSLocalizedString(@"Error", nil), NSLocalizedString(@"Cannot create an histogram from this ROI.", nil), nil, nil, nil);
	}
}

- (IBAction) plot:(id) sender
{
	NSArray *winList = [NSApp windows];
	BOOL	found = NO;
	long	i;
	
	for( i = 0; i < [winList count]; i++)
	{
		if( [[[[winList objectAtIndex:i] windowController] windowNibName] isEqualToString:@"Plot"])
		{
			if( [[[winList objectAtIndex:i] windowController] curROI] == curROI)
			{
				found = YES;
				[[[[winList objectAtIndex:i] windowController] window] makeKeyAndOrderFront:self];
			}
		}
	}
	
	if( found == NO)
	{
		PlotWindow* roiWin = [[PlotWindow alloc] initWithROI: curROI];
		[roiWin showWindow:self];
	}
}

-(ROI*) curROI {return curROI;}

@end
