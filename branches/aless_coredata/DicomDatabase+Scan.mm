//
//  DicomDatabase+Scan.mm
//  OsiriX
//
//  Created by Alessandro Volz on 25.05.11.
//  Copyright 2011 OsiriX Team. All rights reserved.
//

#import "DicomDatabase+Scan.h"
#import "NSThread+N2.h"
#import "NSDate+N2.h"
#import "dcdicdir.h"
#import "NSString+N2.h"
#import "NSFileManager+N2.h"

@interface _DicomDatabaseScanDcmElement : NSObject {
	DcmElement* _element;
}

+(id)elementWithElement:(DcmElement*)element;
-(id)initWithElement:(DcmElement*)element;
-(DcmElement*)element;
-(NSString*)stringValue;
-(NSInteger)integerValue;
-(NSNumber*)integerNumberValue;
-(NSString*)name;

@end


@interface NSMutableDictionary (DicomDatabaseScan)

@end

@implementation NSMutableDictionary (DicomDatabaseScan)

-(id)objectForKeyRemove:(id)key {
	id temp = [[self objectForKey:key] retain];
	[self removeObjectForKey:key];
	return [temp autorelease];
}

-(void)conditionallySetObject:(id)obj forKey:(id)key {
	if (obj)
		[self setObject:obj forKey:key];
//	else NSLog(@"Not setting %@", key);
}

@end





@implementation DicomDatabase (Scan)

/*-(NSString*)describeObject:(DcmObject*)obj {
	const DcmTagKey& key = obj->getTag();
	DcmTag dcmtag(key);
	DcmVR dcmev(obj->ident());
	
	return [NSString stringWithFormat:@"%s %s %s %s", dcmev.getVRName(), key.toString().c_str(), dcmtag.getTagName(), dcmtag.getVRName()];
}

-(NSArray*)describeElementValues:(DcmElement*)obj {
	NSMutableArray* v = [NSMutableArray array];
	
	unsigned int vm = obj->getVM();
	if (vm)
		for (int i = 0; i < vm; ++i) {
			OFString value;
			if (((DcmByteString*)obj)->getOFString(value,i).good())
				[v addObject:[NSString stringWithFormat:@"[%d] %s", i, value.c_str()]];
		}
	
	return v;
}*/

/*-(_DicomDatabaseScanDcmElement*)_dcmElementForKey:(NSString*)key inContext:(NSArray*)context {
	for (NSInteger i = context.count-1; i >= 0; --i) {
		NSDictionary* elements = [context objectAtIndex:i];
		_DicomDatabaseScanDcmElement* ddsde = [elements objectForKey:key];
		if (ddsde) return ddsde;
	}
	
	return nil;
}*/

static NSString* _dcmElementKey(Uint16 group, Uint16 element) {
	return [NSString stringWithFormat:@"%04X,%04X", group, element];
}

static NSString* _dcmElementKey(DcmElement* element) {
	const DcmTagKey& key = element->getTag();
	return _dcmElementKey(key.getGroup(), key.getElement());
}

-(NSArray*)_itemsInRecord:(DcmDirectoryRecord*)record context:(NSMutableArray*)context basePath:(NSString*)basepath {
	NSString* tabs = [NSString stringByRepeatingString:@" " times:context.count*4];
	NSMutableArray* items = [NSMutableArray array];
	NSMutableDictionary* elements = [NSMutableDictionary dictionary];
	[context addObject:elements];
	
	//NSLog(@"%@Record %@", tabs, [self describeObject:record]);
	
	for (unsigned int i = 0; i < record->card(); ++i) {
		DcmElement* element = record->getElement(i);
		
		/*NSLog(@"%@Element %@", tabs, [self describeObject:element]);
		NSArray* values = [self describeElementValues:element];
		for (NSString* s in values)
			NSLog(@"%@%@", tabs, s);*/
		
		[elements setObject:[_DicomDatabaseScanDcmElement elementWithElement:element] forKey:_dcmElementKey(element)];
	}
	
	_DicomDatabaseScanDcmElement* elementReferencedFileID = [elements objectForKey:_dcmElementKey(0x0004,0x1500)];
	if (elementReferencedFileID) {
		NSString* path = [elementReferencedFileID stringValue];
		path = [path stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
		path = [basepath stringByAppendingPathComponent:path];
//		NSLog(@"\n\n%@", path);
		NSString* temp;

		NSMutableDictionary* item = [NSMutableDictionary dictionaryWithObject:path forKey:@"filePath"];

		NSMutableDictionary* elements = [NSMutableDictionary dictionary];
		for (NSDictionary* e in context)
			[elements addEntriesFromDictionary:e];
		
		//NSLog(@"\n\n%@\nDICOMDIR info:%@", path, elements);
		
		if ([[[elements objectForKeyRemove:_dcmElementKey(0x0004,0x1512)] stringValue] isEqualToString:@"1.2.840.10008.1.2.4.100"])
			[item setObject:@"DICOMMPEG2" forKey:@"fileType"];
		else [item setObject:@"DICOM" forKey:@"fileType"];
		
		[item conditionallySetObject:[NSNumber numberWithBool:YES] forKey:@"hasDICOM"];
		
		temp = [[elements objectForKeyRemove:_dcmElementKey(0x0008,0x0016)] stringValue];
		if (!temp) temp = [[elements objectForKeyRemove:_dcmElementKey(0x0004,0x1510)] stringValue];
		[item conditionallySetObject:temp forKey:@"SOPClassUID"];
		[elements removeObjectForKey:_dcmElementKey(0x0004,0x1510)];
		
		temp = [[elements objectForKeyRemove:_dcmElementKey(0x0008,0x0018)] stringValue];
		if (!temp) temp = [[elements objectForKey:_dcmElementKey(0x0004,0x1511)] stringValue];
		[item conditionallySetObject:temp forKey:@"SOPUID"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0004,0x1511)] stringValue] forKey:@"referencedSOPInstanceUID"];
		
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0020,0x000D)] stringValue] forKey:@"studyID"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0020,0x0010)] stringValue] forKey:@"studyNumber"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0008,0x1030)] stringValue] forKey:@"studyDescription"];
		[item conditionallySetObject:[NSDate dateWithYYYYMMDD:[[elements objectForKeyRemove:_dcmElementKey(0x0008,0x0020)] stringValue] HHMMss:[[elements objectForKeyRemove:_dcmElementKey(0x0008,0x0030)] stringValue]] forKey:@"studyDate"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0008,0x0060)] stringValue] forKey:@"modality"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0010,0x0020)] stringValue] forKey:@"patientID"]; // ???
		[item conditionallySetObject:[item objectForKey:@"patientID"] forKey:@"patientUID"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0010,0x0010)] stringValue] forKey:@"patientName"];

		[item conditionallySetObject:[NSDate dateWithYYYYMMDD:[[elements objectForKeyRemove:_dcmElementKey(0x0010,0x0030)] stringValue] HHMMss:nil] forKey:@"patientBirthDate"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0010,0x0040)] stringValue] forKey:@"patientSex"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0008,0x0050)] stringValue] forKey:@"accessionNumber"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0004,0x1511)] stringValue] forKey:@"referencedSOPInstanceUID"];
		
		[item conditionallySetObject:[NSNumber numberWithInteger:1] forKey:@"numberOfSeries"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0020,0x000E)] stringValue] forKey:@"seriesID"]; // SeriesInstanceUID
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0008,0x103E)] stringValue] forKey:@"seriesDescription"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0020,0x0011)] integerNumberValue] forKey:@"seriesNumber"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0020,0x0013)] integerNumberValue] forKey:@"imageID"];
		
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0008,0x0080)] stringValue] forKey:@"institutionName"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0008,0x0090)] stringValue] forKey:@"referringPhysiciansName"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0008,0x1050)] stringValue] forKey:@"performingPhysiciansName"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0028,0x0008)] integerNumberValue] forKey:@"numberOfFrames"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0028,0x0010)] integerNumberValue] forKey:@"height"];
		[item conditionallySetObject:[[elements objectForKeyRemove:_dcmElementKey(0x0028,0x0011)] integerNumberValue] forKey:@"width"];
		
/*		[item setObject:path forKey:@"date"];
		[item setObject:path forKey:@"seriesDICOMUID"];
		[item setObject:path forKey:@"protocolName"];
		[item setObject:path forKey:@"numberOfFrames"];
		[item setObject:path forKey:@"SOPUID* ()"];
		[item setObject:path forKey:@"imageID* ()"];
		[item setObject:path forKey:@"sliceLocation"];
		[item setObject:path forKey:@"numberOfSeries"];
		[item setObject:path forKey:@"numberOfROIs"];
		[item setObject:path forKey:@"commentsAutoFill"];
		[item setObject:path forKey:@"seriesComments"];
		[item setObject:path forKey:@"studyComments"];
		[item setObject:path forKey:@"stateText"];
		[item setObject:path forKey:@"keyFrames"];
		[item setObject:path forKey:@"album"];*/
		
		[elements removeObjectForKey:_dcmElementKey(0x0004,0x1500)]; // ReferencedFileID = IMAGES\IM000000
		[elements removeObjectForKey:_dcmElementKey(0x0004,0x1400)]; // OffsetOfTheNextDirectoryRecord = 0
		[elements removeObjectForKey:_dcmElementKey(0x0004,0x1410)]; // RecordInUseFlag = 65535
		[elements removeObjectForKey:_dcmElementKey(0x0004,0x1420)]; // OffsetOfReferencedLowerLevelDirectoryEntity = 0
		[elements removeObjectForKey:_dcmElementKey(0x0004,0x1430)]; // DirectoryRecordType = IMAGE // TODO: doc?
		[elements removeObjectForKey:_dcmElementKey(0x0008,0x0005)]; // SpecificCharacterSet = ISO_IR 100
		[elements removeObjectForKey:_dcmElementKey(0x0008,0x0008)]; // ImageType = ORIGINAL\PRIMARY
		[elements removeObjectForKey:_dcmElementKey(0x0008,0x0081)]; // InstitutionAddress = 
		[elements removeObjectForKey:_dcmElementKey(0x0859,0x0010)]; // PrivateCreator = ETIAM DICOMDIR
		[elements removeObjectForKey:_dcmElementKey(0x0859,0x1040)]; // Unknown Tag & Data = 13156912
		
		//if (elements.count) NSLog(@"\nUnused DICOMDIR info for %@: %@", path, elements);
		if (elements.count) [item setObject:elements forKey:@"DEBUG"];

		[items addObject:item];
	}
	
	for (unsigned long i = 0; i < record->cardSub(); ++i)
		[items addObjectsFromArray:[self _itemsInRecord:record->getSub(i) context:context basePath:basepath]];
	
	[context removeLastObject];
	return items;
}

-(NSArray*)_itemsInRecord:(DcmDirectoryRecord*)record basePath:(NSString*)basepath {
	return [self _itemsInRecord:record context:[NSMutableArray array] basePath:basepath];
}

-(NSString*)_fixedPathForPath:(NSString*)path { // path was listed in DICOMDIR and [NSFileManager.defaultManager fileExistsAtPath:path] says NO
	return nil;
}

-(NSArray*)scanDicomdirAt:(NSString*)path withPaths:(NSArray*)allpaths {
	NSThread* thread = [NSThread currentThread];

	DcmDicomDir dcmdir([path fileSystemRepresentation]);
	DcmDirectoryRecord& record = dcmdir.getRootRecord();
	NSArray* items = [self _itemsInRecord:&record basePath:[path stringByDeletingLastPathComponent]];
	
	// file paths are sometimes wrong the DICOMDIR, se if these files exist
	for (NSInteger i = items.count-1; i >= 0; --i) {
		NSMutableDictionary* item = [items objectAtIndex:i];
		NSString* filepath = [item objectForKey:@"filePath"];
		if (![NSFileManager.defaultManager fileExistsAtPath:path]) { // reference invalid, try and find the file...
			NSString* fixedpath = [self _fixedPathForPath:path];
			if (fixedpath) [item setObject:fixedpath forKey:@"filePath"];
		}
	}
	
	thread.status = [NSString stringWithFormat:NSLocalizedString(@"Importing %d %@...", nil), items.count, items.count == 1 ? NSLocalizedString(@"file", nil) : NSLocalizedString(@"files", nil) ];
	return [self addFilesDescribedInDictionaries:items postNotifications:NO rereadExistingItems:NO generatedByOsiriX:NO mountedVolume:YES];
}

+(NSString*)_findDicomdirIn:(NSArray*)allpaths  {
	NSString* candidate = nil;
	
	for (NSString* path in allpaths) {
		NSString* filename = [path lastPathComponent];
		NSString* ucfilename = [filename uppercaseString];
		if ([ucfilename isEqualToString:@"DICOMDIR"] || [ucfilename isEqualToString:@"DICOMDIR."])
			if (!candidate || candidate.length > path.length)
				candidate = path;
	}
	
	return candidate;
}

-(void)scanAtPath:(NSString*)path {
	NSThread* thread = [NSThread currentThread];
	[thread enterOperation];
	
	BOOL isDir;
	NSFileManager* fm = NSFileManager.defaultManager;
	
	NSMutableArray* dicomImages = [NSMutableArray array];

	thread.status = NSLocalizedString(@"Scanning directories...", nil);
	NSArray* allpaths = [path stringsByAppendingPaths:[[fm enumeratorAtPath:path filesOnly:YES] allObjects]];
	
	// first read the DICOMDIR file
	thread.status = NSLocalizedString(@"Looking for DICOMDIR...", nil);
	NSString* dicomdirPath = [[self class] _findDicomdirIn:allpaths];
	if (dicomdirPath) {
		NSLog(@"Scanning DICOMDIR at %@", dicomdirPath);
		thread.status = NSLocalizedString(@"Reading DICOMDIR...", nil);
		[dicomImages addObjectsFromArray:[self scanDicomdirAt:dicomdirPath withPaths:allpaths]];
	}
	
	NSLog(@"DICOMDIR referenced %d images", dicomImages.count);
	
	if (!dicomImages.count) {
	}
	
	
	
	
	
	
	/*
	
	
	for (int i = 0; i < 200; ++i) {
		thread.status = [NSString stringWithFormat:@"Iteration %d.", i];
		[NSThread sleepForTimeInterval:0.1];
	}
	*/
	[thread exitOperation];
}

@end


@implementation _DicomDatabaseScanDcmElement

+(id)elementWithElement:(DcmElement*)element {
	return [[[[self class] alloc] initWithElement:element] autorelease];
}

-(id)initWithElement:(DcmElement*)element {
	if ((self = [super init])) {
		_element = element; // new DcmElement(element)
	}
	
	return self;
}

-(void)dealloc {
	//delete _element;
	[super dealloc];
}

-(DcmElement*)element {
	return _element;
}

-(NSString*)description {
	NSMutableString* str = [NSMutableString stringWithFormat:@"%@ = %@", self.name, self.stringValue];
/*	unsigned int vm = _element->getVM();
	if (vm > 1)
		for (unsigned int i = 0; i < vm; ++i) {
			OFString ofstr;
			if (_element->getOFString(ofstr,i).good())
				[str appendFormat:@"[%d][%s] ", i, ofstr.c_str()];
		}
	else {
		OFString ofstr;
		if (_element->getOFString(ofstr,0).good())
			[str appendFormat:@"%s", ofstr.c_str()];
	}
	*/
	return str;
}

-(NSString*)name {
	return [NSString stringWithCString:DcmTag(_element->getTag()).getTagName() encoding:NSUTF8StringEncoding];
}

-(NSString*)stringValue {
	OFString ofstr;
	if (_element->getOFStringArray(ofstr).good())
		return [NSString stringWithCString:ofstr.c_str() encoding:NSUTF8StringEncoding];
	return nil;
}

-(NSInteger)integerValue {
	NSString* str = [self stringValue];
	return [str integerValue];
}

-(NSNumber*)integerNumberValue {
	return [NSNumber numberWithInteger:[self integerValue]];
}

@end


