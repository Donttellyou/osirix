//
//  SpineCounterFilter.m
//  SpineCounter
//
//  Created by Jo�l Spaltenstein on Mar 20 2006.
//

#import "SpineCounterFilter.h"
#import "AppController.h"
#import "AppControllerFiltersMenu.h"
#import "ROI.h"
#import "stringNumericCompare.h"
#import "DCMView.h"
#import "ROIPixelSpacing.h"
#import <AppKit/AppKit.h>
 

//extern AppController * appController;

@implementation SpineCounterFilter

- (long) filterImage:(NSString*) menuName
{

	if ([menuName isEqualToString:@"Switch Spine Type"])
		[self switchTypes];
	else if ([menuName isEqualToString:@"Increment Count"])
		[self incrementDefaultName];
	else if ([menuName isEqualToString:@"Export Spines"])
		[self exportSpines];
	else if ([menuName isEqualToString:@"Export Lengths"])
		[self exportLengths];
	else if ([menuName isEqualToString:@"Export Distances"])
		[self exportDistances];

	return 0;
}

- (void) setMenus
{
	AppController *appController = 0L;
	NSMenuItem *spineMenu = 0L;
	NSMenuItem *switchMenuItem = 0L;
	NSMenuItem *countMenuItem = 0L;
	
	appController = [AppController sharedAppController];
	
	spineMenu = [[appController roisMenu] itemWithTitle:@"SpineCounter"];
	if (spineMenu && [spineMenu hasSubmenu])
	{
		NSMenu *spineSubMenu = 0L;
		spineSubMenu = [spineMenu submenu];
		
		switchMenuItem = [spineSubMenu itemWithTitle:@"Switch Spine Type"];
		countMenuItem = [spineSubMenu itemWithTitle:@"Increment Count"];
		
		[switchMenuItem setKeyEquivalent:@"s"];
		[switchMenuItem setKeyEquivalentModifierMask:NSAlternateKeyMask | NSCommandKeyMask];

		[countMenuItem setKeyEquivalent:@"a"];
		[countMenuItem setKeyEquivalentModifierMask:NSAlternateKeyMask | NSCommandKeyMask];
	}
}

- (void) switchTypes
{
	NSMutableArray  *pixList;
	NSMutableArray  *roiSeriesList;
	NSMutableArray  *roiImageList;
	DCMPix			*curPix;
	NSString		*roiName = 0L;
	long			i, x;
	
	// In this plugin, we will take the selected roi of the current 2D viewer
	// and search all rois with same name in other images of the series
	
	pixList = [viewerController pixList];
	
	curPix = [pixList objectAtIndex: [[viewerController imageView] curImage]];
	
	// All rois contained in the current series
	roiSeriesList = [viewerController roiList];
	
	// All rois contained in the current image
	roiImageList = [roiSeriesList objectAtIndex: [[viewerController imageView] curImage]];
	
	// Find the first selected ROI of current image
	for( i = 0; i < [roiImageList count]; i++)
	{
		if( [[roiImageList objectAtIndex: i] ROImode] == ROI_selected)
		{
			// We find it! What's his name?
			
			roiName = [NSString stringWithString:[[roiImageList objectAtIndex: i] name]];
			
			i = [roiImageList count];   //Break the loop
		}
	}
	
	if( roiName == 0L)
	{
		NSRunInformationalAlertPanel(@"Switch Types", @"You need to select a ROI!", @"OK", 0L, 0L);
		return;
	}
	
	// Now find all ROIs with the same name on other images of the series
	for( x = 0; x < [pixList count]; x++)
	{
		roiImageList = [roiSeriesList objectAtIndex: x];
		
		for( i = 0; i < [roiImageList count]; i++)
			if( [[[roiImageList objectAtIndex: i] name] isEqualToString: roiName])
				[self rotateType:[roiImageList objectAtIndex: i]];
	}
	
	[viewerController needsDisplayUpdate];
}

- (void) incrementDefaultName
{
	NSString* currentDefaultName = 0L;
	
	currentDefaultName = [ROI defaultName];
	
	[ROI setDefaultName:[NSString stringWithFormat:@"%d", ([currentDefaultName intValue] + 1)]];
	
	if ([currentDefaultName intValue] == 99)
		NSRunInformationalAlertPanel(@"Bravo Mathias", @"Va prendre un cafe!", @"OK", 0L, 0L);
}

- (void) exportSpines
{
	NSSavePanel *panel = [ NSSavePanel savePanel ];
	assert( panel != nil );

	[ panel setRequiredFileType: nil ];
	[ panel beginSheetForDirectory:nil file:nil modalForWindow: [ viewerController window ] modalDelegate:self didEndSelector: @selector(endSavePanelSpines:returnCode:contextInfo:) contextInfo: nil ];
}

- (void) exportLengths
{
	NSSavePanel *panel = [ NSSavePanel savePanel ];
	assert( panel != nil );

	[ panel setRequiredFileType: nil ];
	[ panel beginSheetForDirectory:nil file:nil modalForWindow: [ viewerController window ] modalDelegate:self didEndSelector: @selector(endSavePanelLengths:returnCode:contextInfo:) contextInfo: nil ];
}

- (void) exportDistances
{
	int i, j, k;
	
	NSSavePanel *panel = [ NSSavePanel savePanel ];
	assert( panel != nil );

	for (i=0; i < [[self viewerControllersList] count]; i++) // over the viewers
	{
		ViewerController*   currentController = 0L;
		NSMutableArray  *pixList;
		NSMutableArray  *roiSeriesList;
		NSMutableArray  *roiImageList;
		NSString		*roiName = 0L;
		int				foundAxis = NO;
			
		currentController = [[self viewerControllersList] objectAtIndex:i];
		roiSeriesList = [currentController roiList];
		pixList = [currentController pixList];
		
		for (j=0; j < [pixList count]; j++) // over the images in the viewers
		{
			roiImageList = [roiSeriesList objectAtIndex:j];
			for (k=0; k < [roiImageList count]; k++) // over each roi
			{
				ROI* currentROI = [roiImageList objectAtIndex: k];
				roiName = [currentROI name];
				
				if ([roiName isEqualToString:@"Axis"] && [currentROI type] == tOPolygon)
				{
					foundAxis = YES;
					break;
				}
			}
		
		}
		if (foundAxis == NO)
		{
			NSRunInformationalAlertPanel(@"Could not find Open Polygon ROI named \"Axis\"", [NSString stringWithFormat:@"in viewer %d", i], @"OK", 0L, 0L);
			return;
		}
	}

	[ panel setRequiredFileType: nil ];
	[ panel beginSheetForDirectory:nil file:nil modalForWindow: [ viewerController window ] modalDelegate:self didEndSelector: @selector(endSavePanelDistances:returnCode:contextInfo:) contextInfo: nil ];
}

- (ROI*) findMeasureROIWithShortnameInController: (NSString *) shortname: (ViewerController*) controller
{
	int j, k;
	
	NSMutableArray  *roiSeriesList;
	NSMutableArray  *roiImageList;
	NSString		*roiShortname = 0L;

	roiSeriesList = [controller roiList];
	
	for (j=0; j < [roiSeriesList count]; j++) // over the images in the viewers
	{
		roiImageList = [roiSeriesList objectAtIndex:j];
		
		for (k=0; k < [roiImageList count]; k++) // over each roi
		{
			ROI* currentROI = [roiImageList objectAtIndex: k];
			roiShortname = [self shortname:[[roiImageList objectAtIndex: k] name]];
			if ([roiShortname isEqualToString:shortname] && [currentROI type] == tMesure)
				return currentROI;
		}
	}
	
	return 0;
}

- (NSString *) shortname: (NSString *) name
{
	NSString* shortName = 0L;
	NSString* lastchars = @"";

	if ([name length] > 2)
	{
		lastchars = [name substringFromIndex:([name length] - 2)];
		if ([lastchars isEqualToString:@" S"] || [lastchars isEqualToString:@" M"] || [lastchars isEqualToString:@" F"])
			if ([[name substringToIndex:([name length] - 2)] intValue] > 0)
				shortName = [name substringToIndex:([name length] - 2)];
	}
	else if ([name intValue] > 0)
		shortName = [NSString stringWithString:name];
	return shortName;
}


- (void) endSavePanelLengths: (NSSavePanel *) sheet returnCode: (int) retCode contextInfo: (void *) contextInfo
{
	NSMutableArray* roiList = 0L;
	NSMutableArray* roiShortNameList = 0L;
	NSArray* sortedShortNameList = 0L;
	NSString* shortName = 0L;
	NSMutableString	*outputText = [NSMutableString stringWithCapacity: 1024];
	int i, j, k;

	if ( retCode != NSFileHandlingPanelOKButton ) return;
	
	roiList = [NSMutableArray arrayWithCapacity:[[self viewerControllersList] count]];
	
	for (i=0; i < [[self viewerControllersList] count]; i++)
		[roiList addObject:[NSMutableArray arrayWithCapacity:20]];
	
	roiShortNameList = [NSMutableArray arrayWithCapacity:20];
	
	for (i=0; i < [[self viewerControllersList] count]; i++) // over the viewers
	{
		ViewerController*   currentController = 0L;
		NSMutableArray  *pixList;
		NSMutableArray  *roiSeriesList;
		NSMutableArray  *roiImageList;
		NSString		*roiName = 0L;
			
		currentController = [[self viewerControllersList] objectAtIndex:i];
		roiSeriesList = [currentController roiList];
		pixList = [currentController pixList];
		
		for (j=0; j < [pixList count]; j++) // over the images in the viewers
		{
			roiImageList = [roiSeriesList objectAtIndex:j];
			for (k=0; k < [roiImageList count]; k++) // over each roi
			{
				ROI* currentROI = [roiImageList objectAtIndex: k];
				roiName = [currentROI name];
				shortName = [self shortname:roiName];
				if (shortName && [currentROI type] == tMesure)
				{
					if ([[roiList objectAtIndex:i] indexOfObject:roiName] == NSNotFound)
						[[roiList objectAtIndex:i] addObject:[NSString stringWithString:roiName]];
					
					if ([roiShortNameList indexOfObject:shortName] == NSNotFound)
						[roiShortNameList addObject:[NSString stringWithString:shortName]];
				}
			}

		}
	}
	
	sortedShortNameList = [roiShortNameList sortedArrayUsingSelector:@selector(numericCompare:)];
	
	for (i = 0; i < [sortedShortNameList count]; i++)
	{
		NSString* spineNumberString = [sortedShortNameList objectAtIndex:i];
		int spineNumber = [spineNumberString intValue];
		[outputText appendFormat:@"%d", spineNumber];
		for (j=0; j < [[self viewerControllersList] count]; j++) // over the viewers
		{
			ViewerController*   currentController = 0L;
			ROI* theROI;
			
			currentController = [[self viewerControllersList] objectAtIndex:j];
			theROI = [self findMeasureROIWithShortnameInController:spineNumberString:currentController];
			
			if (theROI)
				[outputText appendFormat:@"\t%0.3f", ([theROI MesureLength:0] * 10000.0)];
			else
				[outputText appendFormat:@"\t"];
		}
		[outputText appendFormat:@"\n"];
	}
		
	NSMutableString *fname = [ NSMutableString stringWithString: [ sheet filename ] ];
	
	const char *str = [outputText cStringUsingEncoding: NSASCIIStringEncoding ];
	NSData *data = [ NSData dataWithBytes: str length: strlen( str ) ];
	[data writeToFile: fname atomically: YES];
}

- (void) endSavePanelDistances: (NSSavePanel *) sheet returnCode: (int) retCode contextInfo: (void *) contextInfo
{
	NSMutableArray* axisList = 0L;
	NSMutableArray* roiList = 0L;
	NSMutableArray* roiShortNameList = 0L;
	NSArray* sortedShortNameList = 0L;
	NSString* shortName = 0L;
	NSMutableString	*outputText = [NSMutableString stringWithCapacity: 1024];
	int i, j, k;

	if ( retCode != NSFileHandlingPanelOKButton ) return;
	
	axisList = [NSMutableArray arrayWithCapacity:[[self viewerControllersList] count]];
	roiList = [NSMutableArray arrayWithCapacity:[[self viewerControllersList] count]];
	
	for (i=0; i < [[self viewerControllersList] count]; i++)
		[roiList addObject:[NSMutableArray arrayWithCapacity:20]];
	
	roiShortNameList = [NSMutableArray arrayWithCapacity:20];
	
	for (i=0; i < [[self viewerControllersList] count]; i++) // over the viewers
	{
		ViewerController*   currentController = 0L;
		NSMutableArray  *pixList;
		NSMutableArray  *roiSeriesList;
		NSMutableArray  *roiImageList;
		NSString		*roiName = 0L;
		ROI				*axis = 0L;
		int				axisFound = NO;
			
		currentController = [[self viewerControllersList] objectAtIndex:i];
		// All rois contained in the current series
		roiSeriesList = [currentController roiList];
		
		pixList = [currentController pixList];
		
		for (j=0; j < [pixList count]; j++) // over the images in the viewers
		{
			roiImageList = [roiSeriesList objectAtIndex:j];
			
			for (k=0; k < [roiImageList count]; k++) // over each roi
			{
				ROI* currentROI = [roiImageList objectAtIndex: k];
				roiName = [currentROI name];
				shortName = [self shortname:roiName];
					
				if (shortName)
				{
					if ([[roiList objectAtIndex:i] indexOfObject:currentROI] == NSNotFound)
						[[roiList objectAtIndex:i] addObject:currentROI];
					
					if ([roiShortNameList indexOfObject:shortName] == NSNotFound)
						[roiShortNameList addObject:[NSString stringWithString:shortName]];
				}
				if ([roiName isEqualToString:@"Axis"] && [currentROI type] == tOPolygon && !axisFound)
				{
					axis = currentROI;
					axisFound = YES;
					[axisList addObject:axis];
				}
			}

		}
	}
	
	sortedShortNameList = [roiShortNameList sortedArrayUsingSelector:@selector(numericCompare:)];
	
	for (i = 0; i < [sortedShortNameList count]; i++)
	{
		NSString* spineNumberString = [sortedShortNameList objectAtIndex:i];
		NSString* prevType = @"start";
		int spineNumber = [spineNumberString intValue];
		[outputText appendFormat:@"%d", spineNumber];
		for (j=0; j < [[self viewerControllersList] count]; j++) // over the viewers
		{
			NSArray* rois = [roiList objectAtIndex:j];
			int roiFound = NO;
			ROI *axis = [axisList objectAtIndex:j];
			
			// find the right ROI
			for (k = 0; k < [rois count]; k++)
			{
				ROI* currentROI = [rois objectAtIndex:k];
				NSString* currentROIName = [currentROI name];
				if ([[self shortname:currentROIName] isEqualToString:spineNumberString])
				{
					roiFound = YES;
					float spineDistance = [self spineDistance:currentROI:axis];
					[outputText appendFormat:@"\t%0.3f", (spineDistance * 1000.0)];
					break;
				}
			}
			if (roiFound == NO)
			{
				[outputText appendFormat:@"\t%@", [self outputString:prevType:@""]];
				prevType = @"";
			}
		}
		[outputText appendFormat:@"\n"];
	}
	
	
	NSMutableString *fname = [ NSMutableString stringWithString: [ sheet filename ] ];
	
	const char *str = [outputText cStringUsingEncoding: NSASCIIStringEncoding ];
	NSData *data = [ NSData dataWithBytes: str length: strlen( str ) ];
	[data writeToFile: fname atomically: YES];
}
	
- (void) endSavePanelSpines: (NSSavePanel *) sheet returnCode: (int) retCode contextInfo: (void *) contextInfo
{
	NSMutableArray* roiList = 0L;
	NSMutableArray* roiShortNameList = 0L;
	NSArray* sortedShortNameList = 0L;
	NSString* shortName = 0L;
	NSMutableString	*outputText = [NSMutableString stringWithCapacity: 1024];
	int i, j, k;

	if ( retCode != NSFileHandlingPanelOKButton ) return;
	
	roiList = [NSMutableArray arrayWithCapacity:[[self viewerControllersList] count]];
	
	for (i=0; i < [[self viewerControllersList] count]; i++)
		[roiList addObject:[NSMutableArray arrayWithCapacity:20]];
	
	roiShortNameList = [NSMutableArray arrayWithCapacity:20];
	
	for (i=0; i < [[self viewerControllersList] count]; i++) // over the viewers
	{
		ViewerController*   currentController = 0L;
		NSMutableArray  *pixList;
		NSMutableArray  *roiSeriesList;
		NSMutableArray  *roiImageList;
		NSString		*roiName = 0L;
			
		currentController = [[self viewerControllersList] objectAtIndex:i];
		// All rois contained in the current series
		roiSeriesList = [currentController roiList];
		
		pixList = [currentController pixList];
		
		for (j=0; j < [pixList count]; j++) // over the images in the viewers
		{
			roiImageList = [roiSeriesList objectAtIndex:j];
			
			for (k=0; k < [roiImageList count]; k++) // over each roi
			{
				roiName = [[roiImageList objectAtIndex: k] name];
				shortName = [self shortname:roiName];
					
				if (shortName)
				{
					if ([[roiList objectAtIndex:i] indexOfObject:roiName] == NSNotFound)
						[[roiList objectAtIndex:i] addObject:[NSString stringWithString:roiName]];
					
					if ([roiShortNameList indexOfObject:shortName] == NSNotFound)
						[roiShortNameList addObject:[NSString stringWithString:shortName]];
				}
			}

		}
	}
	
	sortedShortNameList = [roiShortNameList sortedArrayUsingSelector:@selector(numericCompare:)];
	
	for (i = 0; i < [sortedShortNameList count]; i++)
	{
		NSString* spineNumberString = [sortedShortNameList objectAtIndex:i];
		NSString* prevType = @"start";
		int spineNumber = [spineNumberString intValue];
		[outputText appendFormat:@"%d", spineNumber];
		for (j=0; j < [[self viewerControllersList] count]; j++) // over the viewers
		{
			NSArray* rois = [roiList objectAtIndex:j];
			int roiFound = NO;
			
			// find the right ROI
			for (k = 0; k < [rois count]; k++)
			{
				NSString* currentROIName = [rois objectAtIndex:k];
				if ([[self shortname:currentROIName] isEqualToString:spineNumberString])
//				if ([currentROIName hasPrefix:spineNumberString])
				{
					roiFound = YES;
					if ([currentROIName hasSuffix:@"S"])
					{
						[outputText appendFormat:@"\t%@", [self outputString:prevType:@"S"]];
						prevType = @"S";
					}
					else if ([currentROIName hasSuffix:@"M"])
					{
						[outputText appendFormat:@"\t%@", [self outputString:prevType:@"M"]];
						prevType = @"M";
					}
					else if ([currentROIName hasSuffix:@"F"])
					{
						[outputText appendFormat:@"\t%@", [self outputString:prevType:@"F"]];
						prevType = @"F";
					}
					else
					{
						[outputText appendFormat:@"\t%@", [self outputString:prevType:@""]];
						prevType = @"";
					}
					break;
				}
			}
			if (roiFound == NO)
			{
				[outputText appendFormat:@"\t%@", [self outputString:prevType:@""]];
				prevType = @"";
			}
		}
		[outputText appendFormat:@"\n"];
	}
	
	
	NSMutableString *fname = [ NSMutableString stringWithString: [ sheet filename ] ];
	
	const char *str = [outputText cStringUsingEncoding: NSASCIIStringEncoding ];
	NSData *data = [ NSData dataWithBytes: str length: strlen( str ) ];
	[data writeToFile: fname atomically: YES];
}

- (NSString*) outputString:(NSString*) prevType: (NSString*) newType
{
	if ([prevType isEqualToString:@"start"])
		return newType;
	
	if ([prevType isEqualToString:newType])
		return newType;
	
	if ([prevType isEqualToString:@""])
		return [@"+" stringByAppendingString:newType];

	if ([newType isEqualToString:@""])
		return [@"-" stringByAppendingString:prevType];
	
	return [prevType stringByAppendingString:newType];
}


- (void) rotateType:(ROI*) roi
{
	NSString* name;
	NSString* newName;
	RGBColor green = {76, 255, 76};
	RGBColor yellow = {255, 255, 64};
	RGBColor red = {255, 0, 0};
	RGBColor blue = {0, 0, 255};
	
	green.red *= 256;
	green.green *= 256;
	green.blue *= 256;
	
	yellow.red *= 256;
	yellow.green *= 256;
	yellow.blue *= 256;
	
	red.red *= 256;
	red.green *= 256;
	red.blue *= 256;
	
	blue.red *= 256;
	blue.green *= 256;
	blue.blue *= 256;
	
	name = [roi name];
	
	NSString* lastchars = @"";
	
	if ([name length] > 2)
	{
		lastchars = [name substringFromIndex:([name length] - 2)];
		if ([lastchars isEqualToString:@" S"])
		{
			newName = [[name substringToIndex:([name length] - 2)] stringByAppendingString:@" M"];
			[roi setColor:red];
		}
		else if ([lastchars isEqualToString:@" M"])
		{
			newName = [[name substringToIndex:([name length] - 2)] stringByAppendingString:@" F"];
			[roi setColor:blue];
		}
		else if ([lastchars isEqualToString:@" F"])
		{
			newName = [name substringToIndex:([name length] - 2)];
			[roi setColor:green];
		}
		else
		{
			newName = [name stringByAppendingString:@" S"];
			[roi setColor:yellow];
		}
	}
	else
	{
		newName = [name stringByAppendingString:@" S"];
		[roi setColor:yellow];
	}

	[roi setName:newName];
	
	[[NSUserDefaults standardUserDefaults] setFloat:green.red forKey:@"ROIColorR"];
	[[NSUserDefaults standardUserDefaults] setFloat:green.green forKey:@"ROIColorG"];
	[[NSUserDefaults standardUserDefaults] setFloat:green.blue forKey:@"ROIColorB"];

}

- (float)	spineDistance: (ROI*) spine: (ROI*) axis
{
	// find the closest segment
	// find the distance along the axis to the start of the closest segment
	// find the distance along the closest segment
	int i;
	float cosestSegentDistance = 0;
	float totalSpanDistance = 0;
	float totalDistance = 0;

	NSPoint spinePoint = [[[spine points] objectAtIndex:0] point];
	spinePoint.x *= [spine pixelSpacingX];
	spinePoint.y *= [spine pixelSpacingY];
	
	
	NSMutableArray	*points = [axis points];
	
	for (i = 0; i < [points count] - 1; i++)
	{
		NSPoint ori, ext;
		float distance = 0;
		
		ori = [[points objectAtIndex:i] point];
		ext = [[points objectAtIndex:(i+1)] point];
		
		ori.x *= [axis pixelSpacingX];
		ori.y *= [axis pixelSpacingX];
		ext.x *= [axis pixelSpacingX];
		ext.y *= [axis pixelSpacingX];
		
		float extSpan = sqrt(((ori.x - ext.x) * (ori.x - ext.x)) + ((ori.y - ext.y) * (ori.y - ext.y)));
		
		NSPoint transPoint = [self transformPoint: spinePoint: ori: ext];
		
		if (transPoint.y > 0 && transPoint.y < extSpan)
			distance = transPoint.x;
		else if (transPoint.y < 0)
			distance = sqrt((transPoint.x * transPoint.x) + (transPoint.y * transPoint.y));
		else
			distance = sqrt((transPoint.x * transPoint.x) + ((transPoint.y - extSpan) * (transPoint.y - extSpan)));
		
		if (distance < cosestSegentDistance || i == 0)
		{
			cosestSegentDistance = distance;
			if (transPoint.y > 0 && transPoint.y < extSpan)
				totalDistance = totalSpanDistance + transPoint.y;
			else if (transPoint.y < 0)
				totalDistance = totalSpanDistance;
			else
				totalDistance = totalSpanDistance + extSpan;
			
		}
		totalSpanDistance += extSpan;
	}
	
	return totalDistance;
}




- (NSPoint)	transformPoint: (NSPoint) point : (NSPoint) ori : (NSPoint) ext
{
	float distance = sqrt(((ori.x - ext.x) * (ori.x - ext.x)) + ((ori.y - ext.y) * (ori.y - ext.y)));
	return NSMakePoint(((ori.x * point.y) + (ext.y * (point.x - ori.x)) + (ext.x * (ori.y - point.y)) - (ori.y * point.x)) / distance,
						(((ori.x - ext.x) * (ori.x - point.x)) + ((ori.y - ext.y) * (ori.y - point.y))) / distance);
}


@end
















