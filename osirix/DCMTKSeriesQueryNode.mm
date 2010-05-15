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

#import "DCMTKSeriesQueryNode.h"
#import <OsiriX/DCMCalendarDate.h>
#import "DCMTKImageQueryNode.h"
#import "DICOMToNSString.h"

#undef verify
#include "dcdeftag.h"


@implementation DCMTKSeriesQueryNode

+ (id)queryNodeWithDataset:(DcmDataset *)dataset
				callingAET:(NSString *)myAET  
				calledAET:(NSString *)theirAET  
				hostname:(NSString *)hostname 
				port:(int)port 
				transferSyntax:(int)transferSyntax
				compression: (float)compression
				extraParameters:(NSDictionary *)extraParameters{
	return [[[DCMTKSeriesQueryNode alloc] initWithDataset:(DcmDataset *)dataset
				callingAET:(NSString *)myAET  
				calledAET:(NSString *)theirAET  
				hostname:(NSString *)hostname 
				port:(int)port 
				transferSyntax:(int)transferSyntax
				compression: (float)compression
				extraParameters:(NSDictionary *)extraParameters] autorelease];
}

- (id)initWithDataset:(DcmDataset *)dataset
			callingAET:(NSString *)myAET  
			calledAET:(NSString *)theirAET  
			hostname:(NSString *)hostname 
			port:(int)port 
			transferSyntax:(int)transferSyntax
			compression: (float)compression
			extraParameters:(NSDictionary *)extraParameters
{
	if (self = [super initWithDataset:(DcmDataset *)dataset
			callingAET:(NSString *)myAET  
			calledAET:(NSString *)theirAET  
			hostname:(NSString *)hostname 
			port:(int)port 
			transferSyntax:(int)transferSyntax
			compression: (float)compression
			extraParameters:(NSDictionary *)extraParameters])
	{
		_studyInstanceUID = nil;
		const char *string = nil;
		
		if (dataset ->findAndGetString(DCM_SpecificCharacterSet, string).good() && string != nil)
			_specificCharacterSet = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];

		if (dataset ->findAndGetString(DCM_SeriesInstanceUID, string).good() && string != nil) 
			_uid = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
			
		if (dataset ->findAndGetString(DCM_StudyInstanceUID, string).good() && string != nil) 
			_studyInstanceUID = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];	
		else
			_studyInstanceUID = [[extraParameters valueForKey: @"StudyInstanceUID"] retain];
		
		if (dataset ->findAndGetString(DCM_SeriesDescription, string).good() && string != nil) 
			_theDescription = [[NSString alloc] initWithCString:string  DICOMEncoding:_specificCharacterSet];
			
		if (dataset ->findAndGetString(DCM_SeriesNumber, string).good() && string != nil) 
			_name = [[NSString alloc] initWithCString:string  DICOMEncoding:_specificCharacterSet];
			
		if (dataset ->findAndGetString(DCM_ImageComments, string).good() && string != nil) 
			_comments = [[NSString alloc] initWithCString:string  DICOMEncoding:_specificCharacterSet];
			
		if (dataset ->findAndGetString(DCM_SeriesDate, string).good() && string != nil)
		{
			NSString *dateString = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
			_date = [[DCMCalendarDate dicomDate:dateString] retain];
			[dateString release];
		}
		
		if (dataset ->findAndGetString(DCM_SeriesTime, string).good() && string != nil)
		{
			NSString *dateString = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
			_time = [[DCMCalendarDate dicomTime:dateString] retain];
			[dateString release];
		}
		
		if (dataset ->findAndGetString(DCM_Modality, string).good() && string != nil)	
			_modality = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
			
		if (dataset ->findAndGetString(DCM_NumberOfSeriesRelatedInstances, string).good() && string != nil)
		{
			NSString	*numberString = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
			_numberImages = [[NSNumber numberWithInt: [numberString intValue]] retain];
			[numberString release];
		}

	}
	return self;
}

- (void)dealloc
{
	[_studyInstanceUID release];
	[super dealloc];
}

- (DcmDataset *)queryPrototype
{
	DcmDataset *dataset = new DcmDataset();
	dataset-> insertEmptyElement(DCM_InstanceCreationDate, OFTrue);
	dataset-> insertEmptyElement(DCM_InstanceCreationTime, OFTrue);
	dataset-> insertEmptyElement(DCM_StudyInstanceUID, OFTrue);
	dataset-> insertEmptyElement(DCM_SeriesInstanceUID, OFTrue);
	dataset-> insertEmptyElement(DCM_SOPInstanceUID, OFTrue);
	dataset-> insertEmptyElement(DCM_InstanceNumber, OFTrue);
	dataset-> insertEmptyElement(DCM_ImageComments, OFTrue);
	dataset-> putAndInsertString(DCM_SeriesInstanceUID, [_uid UTF8String], OFTrue);
	dataset-> putAndInsertString(DCM_StudyInstanceUID, [_studyInstanceUID UTF8String], OFTrue);
	dataset-> putAndInsertString(DCM_QueryRetrieveLevel, "IMAGE", OFTrue);
	
	return dataset;
	
}

- (DcmDataset *)moveDataset{
	DcmDataset *dataset = new DcmDataset();
	dataset-> putAndInsertString(DCM_SeriesInstanceUID, [_uid UTF8String], OFTrue);
	dataset-> putAndInsertString(DCM_StudyInstanceUID, [_studyInstanceUID UTF8String], OFTrue);
	dataset-> putAndInsertString(DCM_QueryRetrieveLevel, "SERIES", OFTrue);
	return dataset;
}

- (void)addChild:(DcmDataset *)dataset
{
	if (!_children)
		_children = [[NSMutableArray alloc] init];
	
	if( dataset == nil)
		return;
	
	[_children addObject:[DCMTKImageQueryNode queryNodeWithDataset:dataset
			callingAET:_callingAET  
			calledAET:_calledAET
			hostname:_hostname 
			port:_port 
			transferSyntax:_transferSyntax
			compression: _compression
			extraParameters:_extraParameters]];
}


@end
