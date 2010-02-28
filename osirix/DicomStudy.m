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

#import "DicomStudy.h"
#import "DicomSeries.h"
#import <OsiriX/DCMAbstractSyntaxUID.h>
#import <OsiriX/DCM.h>
#import "MutableArrayCategory.h"

#ifdef OSIRIX_VIEWER
#import "DCMPix.h"
#import "VRController.h"
#import "browserController.h"
#import "BonjourBrowser.h"
#endif

#define WBUFSIZE 512

NSString* soundex4( NSString *inString)
{
	char *p, *p1;
	char *outstr;
	int i;
	char workbuf[WBUFSIZE + 1];
	char priorletter;
	int N;
	
	if( inString == nil) return nil;
	
      /* Make a working copy  */
	
      strncpy(workbuf, [[inString uppercaseString] UTF8String], WBUFSIZE);
      workbuf[WBUFSIZE] = 0;
	  
      /* Convert all vowels to 'A'  */

      for (p = workbuf; *p; ++p)
      {
            if (strchr("AEIOUY", *p))
                  *p = 'A';
      }

      /* Prefix transformations: done only once on the front of a name */

      if ( 0 == strncmp(workbuf, "MAC", 3))     /* MAC to MCC    */
            workbuf[1] = 'C';
      else if ( 0 == strncmp(workbuf, "KN", 2)) /* KN to NN      */
            workbuf[0] = 'N';
      else if ('K' == workbuf[0])                     /* K to C        */
            workbuf[0] = 'C';
      else if ( 0 == strncmp(workbuf, "PF", 2)) /* PF to FF      */
            workbuf[0] = 'F';
      else if ( 0 == strncmp(workbuf, "SCH", 3))/* SCH to SSS    */
            workbuf[1] = workbuf[2] = 'S';

      /*
      ** Infix transformations: done after the first letter,
      ** left to right
      */

      while ((p = strstr(workbuf, "DG")) > workbuf)   /* DG to GG      */
            p[0] = 'G';
      while ((p = strstr(workbuf, "CAAN")) > workbuf) /* CAAN to TAAN  */
            p[0] = 'T';
      while ((p = strchr(workbuf, 'D')) > workbuf)    /* D to T        */
            p[0] = 'T';
      while ((p = strstr(workbuf, "NST")) > workbuf)  /* NST to NSS    */
            p[2] = 'S';
      while ((p = strstr(workbuf, "AV")) > workbuf)   /* AV to AF      */
            p[1] = 'F';
      while ((p = strchr(workbuf, 'Q')) > workbuf)    /* Q to G        */
            p[0] = 'G';
      while ((p = strchr(workbuf, 'Z')) > workbuf)    /* Z to S        */
            p[0] = 'S';
      while ((p = strchr(workbuf, 'M')) > workbuf)    /* M to N        */
            p[0] = 'N';
      while ((p = strstr(workbuf, "KN")) > workbuf)   /* KN to NN      */
            p[0] = 'N';
      while ((p = strchr(workbuf, 'K')) > workbuf)    /* K to C        */
            p[0] = 'C';
      while ((p = strstr(workbuf, "AH")) > workbuf)   /* AH to AA      */
            p[1] = 'A';
      while ((p = strstr(workbuf, "HA")) > workbuf)   /* HA to AA      */
            p[0] = 'A';
      while ((p = strstr(workbuf, "AW")) > workbuf)   /* AW to AA      */
            p[1] = 'A';
      while ((p = strstr(workbuf, "PH")) > workbuf)   /* PH to FF      */
            p[0] = p[1] = 'F';
      while ((p = strstr(workbuf, "SCH")) > workbuf)  /* SCH to SSS    */
            p[0] = p[1] = 'S';

      /*
      ** Suffix transformations: done on the end of the word,
      ** right to left
      */

      /* (1) remove terminal 'A's and 'S's      */

      for (i = strlen(workbuf) - 1;
            (i > 0) && ('A' == workbuf[i] || 'S' == workbuf[i]);
            --i)
      {
            workbuf[i] = 0;
      }

      /* (2) terminal NT to TT      */

      for (i = strlen(workbuf) - 1;
            (i > 1) && ('N' == workbuf[i - 1] || 'T' == workbuf[i]);
            --i)
      {
            workbuf[i - 1] = 'T';
      }

      /* Now strip out all the vowels except the first     */

      p = p1 = workbuf;
      while ( 0 != (*p1++ = *p++))
      {
            while ('A' == *p)
                  ++p;
      }

      /* Remove all duplicate letters     */

      p = p1 = workbuf;
      priorletter = 0;
      do {
            while (*p == priorletter)
                  ++p;
            priorletter = *p;
      } while (0 != (*p1++ = *p++));

      /* Finish up */
	
	  return [NSString stringWithUTF8String: workbuf];
}

@implementation DicomStudy

+ (NSString*) soundex: (NSString*) s
{
	NSArray *a = [s componentsSeparatedByString:@" "];
	NSMutableString *r = [NSMutableString string];
	
	for( NSString *w in a)
		[r appendFormat:@" %@", soundex4( w)];
	
	return r;
}

- (NSString*) soundex
{
	return [DicomStudy soundex: [self primitiveValueForKey: @"name"]];
}

- (NSString*) modalities
{
	[[self managedObjectContext] lock];
		
	NSArray *seriesModalities = [[[self valueForKey:@"series"] allObjects] valueForKey:@"modality"];
	
	NSMutableArray *r = [NSMutableArray array];
	
	BOOL SC = NO, SR = NO, PR = NO;
	
	for( NSString *mod in seriesModalities)
	{
		if( [mod isEqualToString:@"SR"])
			SR = YES;
		else if( [mod isEqualToString:@"SC"])
			SC = YES;
		else if( [mod isEqualToString:@"PR"])
			PR = YES;
		else if( [mod isEqualToString:@"RTSTRUCT"] == YES && [r containsString: mod] == NO)
			[r addObject: @"RT"];
		else if( [mod isEqualToString:@"KO"])
		{
		}
		else if([r containsString: mod] == NO)
			[r addObject: mod];
	}
	
	NSString *m = nil;
	
	if( [r count] == 0)
	{
		if( SC) [r addObject: @"SC"];
		else
		{
			if( SR) [r addObject: @"SR"];
			if( PR) [r addObject: @"PR"];
		}
	}
	
	m = [r componentsJoinedByString:@"\\"];
		
	[[self managedObjectContext] unlock];
	
	return m;
}

- (void) dealloc
{
	[dicomTime release];
	
	[super dealloc];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
}

- (BOOL) isHidden;
{
	return isHidden;
}

- (void) setHidden: (BOOL) h;
{
	isHidden = h;
}

- (NSString*) type
{
	return @"Study";
}

- (void) setReportURL: (NSString*) url
{
	#ifdef OSIRIX_VIEWER
	BrowserController	*cB = [BrowserController currentBrowser];
	
	if( url && [cB isCurrentDatabaseBonjour] == NO)
	{
		NSString *commonPath = [[cB fixedDocumentsDirectory] commonPrefixWithString: url options: NSLiteralSearch];
		
		if( [commonPath isEqualToString: [cB fixedDocumentsDirectory]])
		{
			url = [url substringFromIndex: [[cB fixedDocumentsDirectory] length]];
			
			if( [url characterAtIndex: 0] == '/') url = [url substringFromIndex: 1];
		}
	}
	#endif
	
	[self willChangeValueForKey: @"reportURL"];
	[self setPrimitiveValue: url forKey: @"reportURL"];
	[self didChangeValueForKey: @"reportURL"];
}

- (NSString*) reportURL
{
	NSString *url = [self primitiveValueForKey: @"reportURL"];
	
	#ifdef OSIRIX_VIEWER
	if( url && [url length])
	{
		BrowserController	*cB = [BrowserController currentBrowser];
		
		if( [cB isCurrentDatabaseBonjour] == NO)
		{
			if( [url characterAtIndex: 0] != '/')
				url = [[cB fixedDocumentsDirectory] stringByAppendingPathComponent: url];
			else
			{	// Should we convert it to a local path?
				NSString *commonPath = [[cB fixedDocumentsDirectory] commonPrefixWithString: url options: NSLiteralSearch];
				if( [commonPath isEqualToString: [cB fixedDocumentsDirectory]])
				{
					[self setReportURL: url];
					NSLog(@"report url converted to local path");
				}
			}
		}
	}
	#endif
	
	return url;
}

- (NSString *) localstring
{
	[[self managedObjectContext] lock];
	
	NSManagedObject	*obj = [[[[self valueForKey:@"series"] anyObject] valueForKey:@"images"] anyObject];
	
	BOOL local = [[obj valueForKey:@"inDatabaseFolder"] boolValue];
	
	[[self managedObjectContext] unlock];
	
	if( local) return @"L";
	else return @"";
}

- (void) setDate:(NSDate*) date
{
	[dicomTime release];
	dicomTime = nil;
	
	[self willChangeValueForKey: @"date"];
	[self setPrimitiveValue: date forKey:@"date"];
	[self didChangeValueForKey: @"date"];
}

- (NSNumber*) dicomTime
{
	if( dicomTime) return dicomTime;
	
	dicomTime = [[[DCMCalendarDate dicomTimeWithDate:[self valueForKey: @"date"]] timeAsNumber] retain];
	
	return dicomTime;
}


//�������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������

- (NSString*) yearOldAcquisition
{
	if( [self valueForKey: @"dateOfBirth"])
	{
		NSCalendarDate *momsBDay = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate: [[self valueForKey:@"dateOfBirth"] timeIntervalSinceReferenceDate]];
		NSCalendarDate *dateOfBirth = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate: [[self valueForKey:@"date"] timeIntervalSinceReferenceDate]];
		
		NSInteger years, months, days;
		
		[dateOfBirth years:&years months:&months days:&days hours:NULL minutes:NULL seconds:NULL sinceDate:momsBDay];
		
		if( years < 2)
		{
			if( years < 1)
			{
				if( months < 1) return [NSString stringWithFormat:@"%d d", days];
				else return [NSString stringWithFormat:@"%d m", months];
			}
			else return [NSString stringWithFormat:@"%d y %d m",years, months];
		}
		else return [NSString stringWithFormat:@"%d y", years];
	}
	else return @"";
}

- (NSNumber*) yearOldInDays
{
	if( [self valueForKey: @"dateOfBirth"])
	{
		NSCalendarDate *momsBDay = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate: [[self valueForKey:@"dateOfBirth"] timeIntervalSinceReferenceDate]];
		NSCalendarDate *dateOfBirth = [NSCalendarDate date];
		
		NSInteger days;
		
		days = [dateOfBirth timeIntervalSinceDate: momsBDay] / 86400.;
		
		return [NSNumber numberWithInt: days];
	}
	else return [NSNumber numberWithInt: 0];
}

- (NSString*) yearOld
{
	if( [self valueForKey: @"dateOfBirth"])
	{
		NSCalendarDate *momsBDay = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate: [[self valueForKey:@"dateOfBirth"] timeIntervalSinceReferenceDate]];
		NSCalendarDate *dateOfBirth = [NSCalendarDate date];
		
		NSInteger years, months, days;
		
		[dateOfBirth years:&years months:&months days:&days hours:NULL minutes:NULL seconds:NULL sinceDate:momsBDay];
		
		if( years < 2)
		{
			if( years < 1)
			{
				if( months < 1) return [NSString stringWithFormat:@"%d d", days];
				else return [NSString stringWithFormat:@"%d m", months];
			}
			else return [NSString stringWithFormat:@"%d y %d m",years, months];
		}
		else return [NSString stringWithFormat:@"%d y", years];
	}
	else return @"";
}


//�������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������

- (NSNumber *) noFilesExcludingMultiFrames
{
	if( [[self primitiveValueForKey:@"numberOfImages"] intValue] <= 0) // There are frames !
	{
		NSArray	*array = [[self valueForKey:@"series"] allObjects];
		
		int sum = 0;
		
		for( DicomSeries *s in array)
		{
			if( [DCMAbstractSyntaxUID isStructuredReport: [s valueForKey: @"seriesSOPClassUID"]] == NO)
				sum += [[s valueForKey:@"noFilesExcludingMultiFrames"] intValue];
		}
		
		return [NSNumber numberWithInt:sum];
	}
	else return [self noFiles];
}

- (NSNumber *) noFiles
{
	int n = [[self primitiveValueForKey:@"numberOfImages"] intValue];
	if( n == 0)
	{
		[[self managedObjectContext] lock];
		
		NSArray	*array = [[self valueForKey:@"series"] allObjects];
		
		int sum = 0;
		BOOL framesInSeries = NO;
		
		for( DicomSeries *s in array)
		{
			if( [DCMAbstractSyntaxUID isStructuredReport: [s valueForKey: @"seriesSOPClassUID"]] == NO)
			{
				sum += [[s valueForKey:@"noFiles"] intValue];
				
				if( [[s primitiveValueForKey:@"numberOfImages"] intValue] < 0) // There are frames !
					framesInSeries = YES;
			}
		}
		
		if( framesInSeries)
			sum = -sum;
		
		NSNumber *no = [NSNumber numberWithInt: sum];
		
		[self willChangeValueForKey: @"numberOfImages"];
		[self setPrimitiveValue: no forKey:@"numberOfImages"];
		[self didChangeValueForKey: @"numberOfImages"];
		
		[[self managedObjectContext] unlock];
		
		if( sum < 0)
			return [NSNumber numberWithInt: -sum];
		else
			return no;
	}
	else
	{
		if( n < 0)
			return [NSNumber numberWithInt: -n];
		else
			return [self primitiveValueForKey:@"numberOfImages"];
	}
}

//�������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������

- (NSSet*) paths
{
	[[self managedObjectContext] lock];
	
	NSSet *sets = [self valueForKeyPath: @"series.images.completePath"];
	NSMutableSet *set = [NSMutableSet set];
	
	for (id subset in sets)
		[set unionSet: subset];
		
	[[self managedObjectContext] unlock];
	
	return set;
}


//�������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������

- (NSSet*) keyImages
{
	[[self managedObjectContext] lock];
	
	NSMutableSet *set = [NSMutableSet set];
	NSEnumerator *enumerator = [[self primitiveValueForKey: @"series"] objectEnumerator];
	
	id object;
	while (object = [enumerator nextObject])
		[set unionSet:[object keyImages]];
		
	[[self managedObjectContext] unlock];
	
	return set;
}

//��������������������������������------------------------ Series subselections-----------------------------------���������������������������������������������������������������������


- (NSArray *)imageSeries
{
	[[self managedObjectContext] lock];
	
	NSMutableArray *newArray = nil;
	
	@try
	{
		NSArray *array = [self primitiveValueForKey: @"series"];
		
		newArray = [NSMutableArray array];
		for (id series in array)
		{
			if ([DCMAbstractSyntaxUID isImageStorage:[series valueForKey:@"seriesSOPClassUID"]] || [DCMAbstractSyntaxUID isRadiotherapy:[series valueForKey:@"seriesSOPClassUID"]] || [series valueForKey:@"seriesSOPClassUID"] == nil)
				[newArray addObject:series];
		}
	}
	@catch (NSException *e)
	{
		NSLog( @"imageSeries exception: %@", e);
	}
	
	[[self managedObjectContext] unlock];
	
	return newArray;
}

- (NSArray *)reportSeries
{
	[[self managedObjectContext] lock];
	
	NSMutableArray *newArray = nil;
	@try
	{
		NSArray *array = [self primitiveValueForKey: @"series"] ;
		
		newArray = [NSMutableArray array];
		
		for (id series in array)
		{
			if ([DCMAbstractSyntaxUID isStructuredReport:[series valueForKey:@"seriesSOPClassUID"]])
			{
				if( [[series valueForKey:@"id"] intValue] != 5002 || [[series valueForKey:@"name"] isEqualToString: @"OsiriX ROI SR"] == NO)		// We dont want the OsiriX ROIs SR
					[newArray addObject:series];
			}
		}
	}
	@catch (NSException *e)
	{
		NSLog( @"imageSeries exception: %@", e);
	}
	
	[[self managedObjectContext] unlock];
	
	return newArray;
}

- (NSArray *)structuredReports
{
	[[self managedObjectContext] lock];
	
	NSMutableSet *set = nil;
	
	@try
	{
		NSArray *array = [self primitiveValueForKey:@"reportSeries"];
		set = [NSMutableSet set];
		
		for (id series in array)
			[set unionSet:[series primitiveValueForKey:@"images"]];
		
	}
	@catch (NSException *e)
	{
		NSLog( @"imageSeries exception: %@", e);
	}
	
	[[self managedObjectContext] unlock];
	
	return [set allObjects];
}

- (NSArray *)keyObjectSeries
{
	[[self managedObjectContext] lock];
	
	NSArray *array = [self primitiveValueForKey: @"series"] ;
	NSMutableArray *newArray = [NSMutableArray array];
	
	for (id series in array)
	{
		if ([[DCMAbstractSyntaxUID keyObjectSelectionDocumentStorage] isEqualToString:[series valueForKey:@"seriesSOPClassUID"]])
			[newArray addObject:series];
	}
	
	[[self managedObjectContext] unlock];
	
	return newArray;
}

- (NSArray *)keyObjects
{
	[[self managedObjectContext] lock];
	
	NSArray *array = [self keyObjectSeries];
	NSMutableSet *set = [NSMutableSet set];
	
	for (id series in array)
		[set unionSet:[series primitiveValueForKey:@"images"]];
	
	[[self managedObjectContext] unlock];
	
	return [set allObjects];
}

- (NSArray *)presentationStateSeries
{
	[[self managedObjectContext] lock];
	
	NSArray *array = [self primitiveValueForKey: @"series"];
	NSMutableArray *newArray = [NSMutableArray array];
	
	for (id series in array)
	{
		if ([DCMAbstractSyntaxUID isPresentationState:[series valueForKey:@"seriesSOPClassUID"]])
			[newArray addObject:series];
	}
	
	[[self managedObjectContext] unlock];
	
	return newArray;
}

- (NSArray *)waveFormSeries
{
	[[self managedObjectContext] lock];
	
	NSArray *array = [self primitiveValueForKey: @"series"] ;
	NSMutableArray *newArray = [NSMutableArray array];
	
	for (id series in array)
	{
		if ([DCMAbstractSyntaxUID isWaveform:[series valueForKey:@"seriesSOPClassUID"]])
			[newArray addObject:series];
	}
	
	[[self managedObjectContext] unlock];
	
	return newArray;
}

- (NSManagedObject *)roiSRSeries
{
	NSArray *array = [self primitiveValueForKey: @"series"] ;
	if ([array count] < 1)  return nil;
	
	[[self managedObjectContext] lock];
	
	NSMutableArray *newArray = [NSMutableArray array];
	for( DicomSeries *series in array)
	{
		if( [[series valueForKey:@"id"] intValue] == 5002 && [[series valueForKey:@"name"] isEqualToString: @"OsiriX ROI SR"] == YES && [DCMAbstractSyntaxUID isStructuredReport:[series valueForKey:@"seriesSOPClassUID"]] == YES)
			[newArray addObject:series];
	}
	
	if( [newArray count] > 1)
	{
		NSLog( @"****** multiple (%d) roiSRSeries?? Delete the extra series...", [newArray count]);
		
		for( int i = 1 ; i < [newArray count] ; i++)
			[[self managedObjectContext] deleteObject: [newArray objectAtIndex: i]]; 
	}
	
	[[self managedObjectContext] unlock];
	
	if( [newArray count]) return [newArray objectAtIndex: 0];
	
	return nil;
}

- (NSDictionary *)dictionary
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	if ([self primitiveValueForKey:@"name"])
		[dict  setObject: [self primitiveValueForKey:@"name"] forKey: @"Patients Name"];
	if ([self primitiveValueForKey:@"patientID"])
		[dict  setObject: [self primitiveValueForKey:@"patientID"] forKey: @"Patient ID"];
	if ([self primitiveValueForKey:@"studyName"])
		[dict  setObject: [self primitiveValueForKey:@"studyName"] forKey: @"Study Description"];
	if ([self primitiveValueForKey:@"patientSex"] )
		[dict  setObject: [self primitiveValueForKey:@"patientSex"] forKey: @"Patients Sex"];
	if ([self primitiveValueForKey:@"dateOfBirth"] )
		[dict  setObject: [self primitiveValueForKey:@"dateOfBirth"] forKey: @"Patients DOB"];
	if ([self primitiveValueForKey:@"institutionName"])
		[dict  setObject: [self primitiveValueForKey:@"institutionName"] forKey: @"Institution"];
	if ([self primitiveValueForKey:@"accessionNumber"])
		[dict  setObject: [self primitiveValueForKey:@"accessionNumber"] forKey: @"Accession Number"];
	if ([self primitiveValueForKey:@"comment"])
		[dict  setObject: [self primitiveValueForKey:@"comment"] forKey: @"Comment"];
	if ([self primitiveValueForKey:@"modality"])
		[dict  setObject: [self primitiveValueForKey:@"modality"] forKey: @"Modality"];
	if ([self primitiveValueForKey:@"date"])
		[dict  setObject: [self primitiveValueForKey:@"date"] forKey: @"Study Date"];
	if ([self primitiveValueForKey:@"performingPhysician"] )
		[dict  setObject: [self primitiveValueForKey:@"performingPhysician"] forKey: @"Performing Physician"];
	if ([self primitiveValueForKey:@"referringPhysician"])
		[dict  setObject: [self primitiveValueForKey:@"referringPhysician"] forKey: @"Referring Physician"];
	if ([self primitiveValueForKey:@"id"])
		[dict  setObject: [self primitiveValueForKey:@"id"] forKey: @"Study ID"];
	if ([self primitiveValueForKey:@"studyInstanceUID"])
		[dict  setObject: [self primitiveValueForKey:@"studyInstanceUID"] forKey: @"Study Instance UID"];

	return dict;
}

- (NSComparisonResult)compareName:(DicomStudy*)study;
{
	return [[self valueForKey:@"name"] caseInsensitiveCompare:[study valueForKey:@"name"]];
}

- (NSString*) albumsNames
{
	[[self managedObjectContext] lock];
	
	NSString * s = [[[[self valueForKey: @"albums"] allObjects] valueForKey:@"name"] componentsJoinedByString:@"/"];
	
	[[self managedObjectContext] unlock];
	
	return s;
}

- (BOOL) validateForDelete:(NSError **)error
{
	BOOL delete = [super validateForDelete:(NSError **)error];
	if( delete)
	{
		if( [self valueForKey:@"reportURL"])
			[[NSFileManager defaultManager] removeFileAtPath: [self valueForKey:@"reportURL"] handler:nil];
	}
	return delete;
}

@end
