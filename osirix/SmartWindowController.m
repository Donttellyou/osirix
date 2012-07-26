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

#import "SmartWindowController.h"
#import "SearchSubview.h"
#import "QueryFilter.h"
#import "QueryController.h"

#define SUBVIEWHEIGHT 50

@implementation SmartWindowController

@synthesize onDemandFilter;

- (id)init
{
	if (self = [super initWithWindowNibName:@"SmartAlbum"])
    {
		subviews = [[NSMutableArray array] retain];
        self.onDemandFilter = [NSMutableDictionary dictionary];
    }
    
	return self;
}

- (void) dealloc
{
    self.onDemandFilter = nil;
    
	[previousSqlString release];
	[sqlQueryTimer release];
	[subviews release];
	[criteria release];
	[super dealloc];
}

- (void)windowDidLoad
{
	firstTime = YES;
	[albumNameField setStringValue:NSLocalizedString(@"Smart Album", nil)];
	[super windowDidLoad];
	
	sqlQueryTimer = [[NSTimer timerWithTimeInterval: 0.5 target: self selector: @selector( updateSqlString:) userInfo: nil repeats: YES] retain];
	
	[[NSRunLoop currentRunLoop] addTimer: sqlQueryTimer forMode:NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: sqlQueryTimer forMode:NSModalPanelRunLoopMode];
	
	startingWindowHeight = [[self window] frame].size.height - 22;
}

- (void)addSubview:(id)sender
{
	//setup subview
	float subViewHeight = SUBVIEWHEIGHT;
	SearchSubview *subview = [[[SearchSubview alloc] initWithFrame:NSMakeRect(0.0,0.0,[filterBox frame].size.width, subViewHeight)] autorelease];
	[filterBox addSubview:subview];	
	[subviews  addObject:subview];
	[[subview addButton] setTarget:self];
	[[subview addButton] setAction:@selector(addSubview:)];
	[[subview filterKeyPopup] setTarget:subview];
	[[subview filterKeyPopup] setAction:@selector(showSearchTypePopup:)];
	[[subview searchTypePopup] setTarget:subview];
	[[subview searchTypePopup] setAction:@selector(showValueField:)];
	[[subview removeButton] setTarget:self];
	[[subview removeButton] setAction:@selector(removeSubview:)];
	[self drawSubviews];
	
	[subview showSearchTypePopup: [subview filterKeyPopup]];
	
	[self willChangeValueForKey: @"logicalOperatorEnabled"];
	[self didChangeValueForKey: @"logicalOperatorEnabled"];
}	

- (void)removeSubview:(id)sender
{
	NSView *view = [sender superview];
	[subviews removeObject:view];
	[view removeFromSuperview];
	[self drawSubviews];
	
	[self willChangeValueForKey: @"logicalOperatorEnabled"];
	[self didChangeValueForKey: @"logicalOperatorEnabled"];
}

- (void)drawSubviews
{
	float subViewHeight = SUBVIEWHEIGHT;
	float windowHeight = startingWindowHeight;
	
	int count = [subviews  count];
	NSRect windowFrame = [[self window] frame];
	float oldWindowHeight = windowFrame.size.height;
	float newWindowHeight = windowHeight  + subViewHeight * count;
	float y = windowFrame.origin.y - (newWindowHeight - oldWindowHeight);
	
	NSEnumerator *enumerator = [subviews reverseObjectEnumerator];
	id view;
	int i = 0;
	while (view = [enumerator nextObject])
	{
		NSRect viewFrame = [view frame];
		[view setFrame:NSMakeRect(viewFrame.origin.x, subViewHeight * i++, viewFrame.size.width, viewFrame.size.height)];
	}
	
	[[self window] setFrame: NSMakeRect(windowFrame.origin.x, y, windowFrame.size.width, newWindowHeight) display:YES];
	
	[self updateRemoveButtons];
	firstTime = NO;
}

- (void)updateRemoveButtons
{
	if ([subviews count] == 1)
	{
		AdvancedQuerySubview *view = [subviews objectAtIndex:0];
		[[view removeButton] setEnabled:NO];
	}
	else
	{
		AdvancedQuerySubview *view;
		for (view in subviews)
				[[view removeButton] setEnabled:YES];
	}
}

- (void) windowWillClose: (NSNotification*) notification
{
	[[self window] setAcceptsMouseMovedEvents: NO];
	
	[sqlQueryTimer invalidate];
	
    [[self window] setDelegate:nil];
}

- (void) updateSqlString: (NSTimer*)theTimer
{
	if( [previousSqlString isEqualToString: [self sqlQueryString]] == NO)
	{
		[self willChangeValueForKey: @"sqlQueryString"];
		
		[previousSqlString release];
		previousSqlString = [[self sqlQueryString] retain];
		
		[self didChangeValueForKey: @"sqlQueryString"];
	}
}

- (NSString*) sqlQueryString
{
	[self createCriteria];
	
	NSString *format = [NSString string];
			
	BOOL first = YES;
	for( NSString *search in criteria)
	{
		if ( first) first = NO;
		else
		{
			if( [[NSUserDefaults standardUserDefaults] integerForKey: @"smartAlbumLogicalOperator"] == 1)
				format = [format stringByAppendingFormat: @" OR "];
			else
				format = [format stringByAppendingFormat: @" AND "];
		}
		
		format = [format stringByAppendingFormat: @"(%@)", search];
	}
	
	return format;
}

- (BOOL) logicalOperatorEnabled
{
	[self createCriteria];
	
	if( [criteria count] > 1)
		return YES;
	else
		return NO;
}

-(void) createCriteria
{
	AdvancedQuerySubview *view;
	[criteria release];
	criteria = [[NSMutableArray array] retain];
    
    [self.onDemandFilter removeObjectForKey: @"date"];
    [self.onDemandFilter removeObjectForKey: @"modality"];
    
	for (view in subviews)
	{
		NSString *predicateString = nil;
		NSString *value = nil;
		NSInteger searchType;
		
		NSString *key = [[view filterKeyPopup] titleOfSelectedItem];
		// Modality	
		if ([key isEqualToString:NSLocalizedString(@"Modality", nil)])
		{
			switch ([[view searchTypePopup] indexOfSelectedItem])
			{
				case osiCR: value = @"CR";
						break;
				case osiCT: value = @"CT";
						break;;
				case osiDX: value = @"DX";
						break;
				case osiES: value = @"ES";
						break;
				case osiMG: value = @"MG";
						break;
				case osiMR: value = @"MR";
						break;
				case osiNM: value = @"NM";
						break;
				case osiOT: value = @"OT";
						break;
				case osiPT: value = @"PT";
						break;
				case osiRF: value = @"RF";
						break;
				case osiSC: value = @"SC";
						break;
				case osiUS: value = @"US";
						break;
				case osiXA: value = @"XA";
						break;
				default:
					value = [[view valueField] stringValue];
					if( [value isEqualToString:@""]) value = @"OT";
				break;
			}
			
            if( value)
            {
                if( [[NSUserDefaults standardUserDefaults] integerForKey: @"smartAlbumLogicalOperator"] == 1) // OR
                {
                    NSArray *existingArray = [self.onDemandFilter valueForKey: @"modality"];
                    
                    if( existingArray == nil)
                        existingArray = [NSArray array];
                    
                    existingArray = [existingArray arrayByAddingObject: value];
                    
                    [self.onDemandFilter setValue: existingArray forKey: @"modality"];
                }
                else
                     [self.onDemandFilter setValue: [NSArray arrayWithObject: value] forKey: @"modality"];
            }
			predicateString = [NSString stringWithFormat:@"modality CONTAINS[cd] '%@'", value];
		}
		// Study status	
		else if ([key isEqualToString:NSLocalizedString(@"Study Status", nil)])
		{
			switch ([[view searchTypePopup] indexOfSelectedItem])
			{
				case empty: value = @"0";
						break;
				case unread: value = @"1";
						break;
				case reviewed: value = @"2";
						break;
				case dictated: value = @"3";
						break;
                case validated: value = @"4";
                    break;
				default: value = [[view valueField] stringValue];
			}
			
			if( [value isEqualToString:@""]) value = @"0";
			
			predicateString = [NSString stringWithFormat:@"stateText == \"%@\"", value];
		}		
		// Dates		
		else if ([key isEqualToString:NSLocalizedString(@"Study Date", nil)] == YES || [key isEqualToString:NSLocalizedString(@"Date Added", nil)])
		{
			NSDate *date = nil;
			NSString *field = nil;
			NSMutableDictionary *dict = nil;
            int dateEnum = 0;
            
			if( [key isEqualToString:NSLocalizedString(@"Study Date", nil)])
            {
                field = @"date";
                dict = self.onDemandFilter;
            }
            
			if( [key isEqualToString:NSLocalizedString(@"Date Added", nil)])
                field = @"dateAdded";
			
			switch ([[view searchTypePopup] indexOfSelectedItem] + 4)
			{
				case searchToday:
                    dateEnum = today;
					predicateString = [NSString stringWithFormat:@"%@ >= $NSDATE_TODAY", field];
				break;
				
				case searchYesterday:
                    dateEnum = yesteday;
					predicateString = [NSString stringWithFormat:@"%@ >= $NSDATE_YESTERDAY AND %@ <= $NSDATE_TODAY", field, field];
				break;
														
				case searchWithin:
					switch( [[view dateRangePopup] indexOfSelectedItem])
					{
						case 0:	dateEnum = today;	predicateString = [NSString stringWithFormat:@"%@ >= $NSDATE_TODAY", field];		break;
						case 1:	dateEnum = last2Days;	predicateString = [NSString stringWithFormat:@"%@ >= $NSDATE_2DAYS", field];			break;
						case 2:	dateEnum = last7Days;	predicateString = [NSString stringWithFormat:@"%@ >= $NSDATE_WEEK", field];			break;
						case 3:	dateEnum = lastMonth;	predicateString = [NSString stringWithFormat:@"%@ >= $NSDATE_MONTH", field];			break;
						case 4:	dateEnum = last2Months;	predicateString = [NSString stringWithFormat:@"%@ >= $NSDATE_2MONTHS", field];			break;
						case 5:	dateEnum = last3Months;	predicateString = [NSString stringWithFormat:@"%@ >= $NSDATE_3MONTHS", field];			break;
						case 6:	dateEnum = lastYear;	predicateString = [NSString stringWithFormat:@"%@ >= $NSDATE_YEAR", field];			break;
						case 8:	dateEnum = 101;	predicateString = [NSString stringWithFormat:@"%@ >= $NSDATE_LASTHOUR", field];		break;
						case 9:	dateEnum = 106;	predicateString = [NSString stringWithFormat:@"%@ >= $NSDATE_LAST6HOURS", field];		break;
						case 10:dateEnum = 112;	predicateString = [NSString stringWithFormat:@"%@ >= $NSDATE_LAST12HOURS", field];		break;
					}
				break;
				
				case searchBefore:
					date = [[view datePicker] objectValue];
					predicateString = [NSString stringWithFormat:@"%@ <= CAST(%lf, \"NSDate\")", field, [date timeIntervalSinceReferenceDate]];
				break;
				
				case searchAfter:
					date = [[view datePicker] objectValue];
					predicateString = [NSString stringWithFormat:@"%@ >= CAST(%lf, \"NSDate\")", field, [date timeIntervalSinceReferenceDate]];
				break;
				
				case searchExactDate:
					date = [[view datePicker] objectValue];
					predicateString = [NSString stringWithFormat:@"%@ >= CAST(%lf, \"NSDate\") AND %@ < CAST(%lf, \"NSDate\")", field, [date timeIntervalSinceReferenceDate], field, [[date addTimeInterval:60*60*24] timeIntervalSinceReferenceDate]];
				break;
			}
            
            if( dateEnum)
                [dict setValue: [NSNumber numberWithInt: dateEnum] forKey: @"date"];
		}
		else
        {
			searchType = [[view searchTypePopup] indexOfSelectedItem];
			value = [[view valueField] stringValue];
		}
		
		if ([key isEqualToString:NSLocalizedString(@"Patient Name", nil)])
			key = @"name";
		else if ([key isEqualToString:NSLocalizedString(@"Patient ID", nil)])
			key = @"patientID";
		else if ([key isEqualToString:NSLocalizedString(@"Study ID", nil)])
			key = @"id";
		else if ([key isEqualToString:NSLocalizedString(@"Study Description", nil)])
			key = @"studyName";
		else if ([key isEqualToString:NSLocalizedString(@"Referring Physician", nil)])
			key = @"referringPhysician";
		else if ([key isEqualToString:NSLocalizedString(@"Performing Physician", nil)])
			key = @"performingPhysician";
		else if ([key isEqualToString:NSLocalizedString(@"Institution", nil)])	
			key = @"institutionName";
		else if ([key isEqualToString:NSLocalizedString(@"Comments", nil)])	
			key = @"comment";
		else if ([key isEqualToString:NSLocalizedString(@"Comments 2", nil)])	
			key = @"comment2";
		else if ([key isEqualToString:NSLocalizedString(@"Comments 3", nil)])	
			key = @"comment3";
		else if ([key isEqualToString:NSLocalizedString(@"Comments 4", nil)])	
			key = @"comment4";
		else if ([key isEqualToString:NSLocalizedString(@"Study Status", nil)])
		{
			key = @"stateText";
			predicateString = [NSString stringWithFormat:@"stateText == %d", [value intValue]];
		}
		
		if( predicateString == nil)
		{
			if( [value isEqualToString:@""]) value = @"OT";
			
			switch( searchType)
			{
				case searchContains:			predicateString = [NSString stringWithFormat:@"%@ CONTAINS[cd] '%@'", key, value];		break;
				case searchStartsWith:			predicateString = [NSString stringWithFormat:@"%@ BEGINSWITH[cd] '%@'", key, value];		break;
				case searchEndsWith:			predicateString = [NSString stringWithFormat:@"%@ ENDSWITH[cd] '%@'", key, value];		break;
				case searchExactMatch:
									{
										if([[[view valueField] stringValue] isEqualToString:@""]) value = @"<empty>";
										predicateString = [NSString stringWithFormat:@"(%@ BEGINSWITH[cd] '%@') AND (%@ ENDSWITH[cd] '%@')", key, value, key, value];	break;
									}
			}
		}
		
		[criteria addObject: predicateString];
	}
}

- (BOOL) editSqlQuery
{
	return editSqlQuery;
}

- (IBAction) editSqlString:(id) sender
{
	editSqlQuery = YES;
	[NSApp stopModal];
}

-(NSMutableArray *)criteria
{
	return criteria;
}

-(NSString *)albumTitle
{
	return [albumNameField stringValue];
}

- (NSCalendarDate *)dateBeforeNow:(int)value
{
	NSCalendarDate *today = [NSCalendarDate date];
	NSCalendarDate *date;
	switch (value)
	{
		case searchWithinToday: 
			date = today;
			break;
		case searchWithinLast2Days: 
			date = [today dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0];
			break;
		case searchWithinLastWeek: 
			date = [today dateByAddingYears:0 months:0 days:-7 hours:0 minutes:0 seconds:0];
			break;
		case searchWithinLast2Weeks: 
			date = [today dateByAddingYears:0 months:0 days:-14 hours:0 minutes:0 seconds:0];
			break;
		case searchWithinLastMonth: 
			date = [today dateByAddingYears:0 months:-1 days:0 hours:0 minutes:0 seconds:0];
			break;
		case searchWithinLast2Months: 
			date = [today dateByAddingYears:0 months:-2 days:0 hours:0 minutes:0 seconds:0];
			break;
		case searchWithinLast3Months: 
			date = [today dateByAddingYears:0 months:-3 days:0 hours:0 minutes:0 seconds:0];
			break;
		case searchWithinLastYear:  
			date = [today dateByAddingYears:-1 months:0 days:0 hours:0 minutes:0 seconds:0];
			break;
		default:
			date = today;
			break;
	}
	return date;
}
@end
