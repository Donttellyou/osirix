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

#import "DicomDatabase+Scan.h"
#import "NSThread+N2.h"
#import "NSDate+N2.h"
#import "dcdicdir.h"
#import "NSString+N2.h"
#import "NSFileManager+N2.h"
#import "DicomImage.h"
#import "N2Debug.h"
#import "DicomFile.h"
#import "MutableArrayCategory.h"
#import "BrowserController.h"
#import "DCMPix.h"
#import "ThreadsManager.h"
#import "DiscMountedAskTheUserDialogController.h"
#import "DCMAbstractSyntaxUID.h"
#import "N2Stuff.h"

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

+(NSImage*)_nsImageForElement:(DcmItem*)thumb {
    // ftp://medical.nema.org/medical/dicom/2011/11_03pu.pdf F.7 ICON IMAGE KEY DEFINITION
    
    // Pixel samples have a Value of either 1 or 8 for Bits Allocated (0028,0100) and Bits Stored (0028,0101)
    Uint16 bitsAllocated, bitsStored;
    if (!thumb->findAndGetUint16(DcmTagKey(0x0028,0x0100), bitsAllocated).good()) return nil;
    if (!thumb->findAndGetUint16(DcmTagKey(0x0028,0x0101), bitsStored).good()) return nil;
    if (bitsAllocated != 1 && bitsAllocated != 8) return nil;
    if (bitsStored != 1 && bitsStored != 8) return nil;
    
    Uint16 width, height;
    if (!thumb->findAndGetUint16(DcmTagKey(0x0028,0x0010), height).good()) return nil; // Rows must be defined
    if (!thumb->findAndGetUint16(DcmTagKey(0x0028,0x0011), width).good()) return nil; // Columns must be defined
    
    const Uint8* data;
    if (!thumb->findAndGetUint8Array(DcmTagKey(0x7fe0,0x0010), data).good()) return nil; // PixelRepresentation must be defined
    
    // Photometric Interpretation (0028,0004) shall have a Value of either MONOCHROME 1, MONOCHROME 2 or PALETTE COLOR
    OFString spi;
    if (!thumb->findAndGetOFString(DcmTagKey(0x0028,0x0004), spi).good()) return nil;
    NSBitmapImageRep* rep = nil;
    if (spi == "MONOCHROME1") {
        rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:width pixelsHigh:height bitsPerSample:bitsStored samplesPerPixel:1 hasAlpha:NO isPlanar:NO colorSpaceName:NSDeviceWhiteColorSpace bytesPerRow:0 bitsPerPixel:bitsAllocated] autorelease];
        unsigned char* bitmapData = rep.bitmapData;
        // invert data
        for (NSUInteger i = 0; i < width*height*bitsAllocated/8; ++i) {
            if (bitsAllocated == 1)
                bitmapData[i] = data[i]^0xff;
            else bitmapData[i] = 0xff-data[i];
        }
    } else
    if (spi == "MONOCHROME2") {
        rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:width pixelsHigh:height bitsPerSample:bitsStored samplesPerPixel:1 hasAlpha:NO isPlanar:NO colorSpaceName:NSDeviceWhiteColorSpace bytesPerRow:width*8/bitsAllocated bitsPerPixel:bitsAllocated] autorelease];
        memcpy(rep.bitmapData, data, ceilf(1.0*width*height*bitsAllocated/8));
    } else
    if (spi == "PALETTE COLOR") {
        return nil; // TODO: this type of thumbnail should be read too...
    } else
        return nil;

    NSImage* im = [[[NSImage alloc] init] autorelease];
    [im addRepresentation:rep];
    return im;
}

-(NSMutableArray*)_itemsInRecord:(DcmDirectoryRecord*)record context:(NSMutableArray*)context basePath:(NSString*)basepath {
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
		NSInteger tempi;
		
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
		if (!temp) temp = [[elements objectForKey:_dcmElementKey(0x0004,0x1510)] stringValue];
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
		tempi = [[elements objectForKeyRemove:_dcmElementKey(0x0028,0x0010)] integerValue];
		[item conditionallySetObject:[NSNumber numberWithInteger:tempi? tempi : OsirixDicomImageSizeUnknown] forKey:@"height"];
		tempi = [[elements objectForKeyRemove:_dcmElementKey(0x0028,0x0011)] integerValue];
		[item conditionallySetObject:[NSNumber numberWithInteger:tempi? tempi : OsirixDicomImageSizeUnknown] forKey:@"width"];
        
        // thumbnail
        _DicomDatabaseScanDcmElement* thumbnailElement = [elements objectForKeyRemove:_dcmElementKey(0x0088,0x0200)]; // IconImageSequence
        if (thumbnailElement && thumbnailElement.element->ident() == EVR_SQ && ((DcmSequenceOfItems*)thumbnailElement.element)->card() == 1) {
            DcmItem* thumb = ((DcmSequenceOfItems*)thumbnailElement.element)->getItem(0);
            NSImage* im = [[self class] _nsImageForElement:thumb];
            if (im)
                [item setObject:im forKey:@"NSImageThumbnail"];
        }
        
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
		[elements removeObjectForKey:_dcmElementKey(0x0004,0x1430)]; // DirectoryRecordType = IMAGE
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

-(NSMutableArray*)_itemsInRecord:(DcmDirectoryRecord*)record basePath:(NSString*)basepath {
	return [self _itemsInRecord:record context:[NSMutableArray array] basePath:basepath];
}

-(NSString*)_fixedPathForPath:(NSString*)path withPaths:(NSArray*)allpaths { // path was listed in DICOMDIR and [NSFileManager.defaultManager fileExistsAtPath:path] says NO
	NSString* cutpath = [path stringByDeletingPathExtension];
	
	for (NSString* ipath in allpaths)
		if ([[ipath stringByDeletingPathExtension] isEqualToString:cutpath])
			return ipath;
	
	return nil;
}

+(BOOL)_item:(NSDictionary*)item isOnlyEntryForItsSeriesInItems:(NSArray*)items {
    NSString* seriesInstanceUID = [item objectForKey:@"seriesID"];
    for (NSDictionary* i2 in items)
        if (i2 != item && [[i2 objectForKey:@"seriesID"] isEqualToString:seriesInstanceUID])
            return NO;
    return YES;
}

-(NSArray*)scanDicomdirAt:(NSString*)path withPaths:(NSArray*)allpaths pathsToScanAnyway:(NSMutableArray*)pathsToScanAnyway {
	NSThread* thread = [NSThread currentThread];

	DcmDicomDir dcmdir([path fileSystemRepresentation]);
	DcmDirectoryRecord& record = dcmdir.getRootRecord();
	NSMutableArray* items = [self _itemsInRecord:&record basePath:[path stringByDeletingLastPathComponent]];
	
	// file paths are sometimes wrong the DICOMDIR, see if these files exist
	for (NSInteger i = items.count-1; i >= 0; --i) {
        NSMutableDictionary* item = [items objectAtIndex:i];
        
		NSString* filepath = [item objectForKey:@"filePath"];
		if (![NSFileManager.defaultManager fileExistsAtPath:filepath]) { // reference invalid, try and find the file...
			filepath = [self _fixedPathForPath:filepath withPaths:allpaths];
			if (filepath) [item setObject:filepath forKey:@"filePath"];
		}
        
        // some DICOMDIR files only list 1 image for 1 multiframe DICOM file
        NSString* scuid = [item objectForKey:@"SOPClassUID"];
        if ([[self class] _item:item isOnlyEntryForItsSeriesInItems:items] &&
            ([DCMAbstractSyntaxUID isMultiframe:scuid]))
        {
            [pathsToScanAnyway addObject:filepath];
            [items removeObjectAtIndex:i];
        }
        
        if ([thread isCancelled]) 
            break;
	}
	
    NSArray* objectIDs = nil;
    if (items.count) {
        thread.status = [NSString stringWithFormat:NSLocalizedString(@"Importing %@...", nil), N2LocalizedSingularPluralCount(items.count, @"file", @"files")];
        objectIDs = [self addFilesDescribedInDictionaries:items postNotifications:NO rereadExistingItems:NO generatedByOsiriX:NO];
    }
    
    return [self objectsWithIDs:objectIDs];
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

-(void)_requestZipPassword:(NSArray*)args {
	[BrowserController.currentBrowser askForZIPPassword:[args objectAtIndex:0] destination:[args objectAtIndex:1]];
}

-(void)_askUserDiscDataCopyOrBrowse:(NSArray*)a {
    NSString* path = [a objectAtIndex:0];
    NSInteger count = [[a objectAtIndex:1] integerValue];
    NSInteger* mode = (NSInteger*)[[a objectAtIndex:2] pointerValue];
    
    DiscMountedAskTheUserDialogController* dialog = [[DiscMountedAskTheUserDialogController alloc] initWithMountedPath:path dicomFilesCount:count];
    [dialog.window center];
    
    [NSApp runModalForWindow:dialog.window];
    
    *mode = dialog.choice;
    
    [dialog release];
    
}

-(BOOL)scanAtPath:(NSString*)path isVolume:(BOOL)isVolume {
	NSThread* thread = [NSThread currentThread];
	[thread enterOperation];
	@try {
        NSArray* dicomImages = [NSMutableArray array];

        thread.status = NSLocalizedString(@"Scanning directories...", nil);
        NSMutableArray* allpaths = [[[path stringsByAppendingPaths:[[NSFileManager.defaultManager enumeratorAtPath:path filesOnly:YES] allObjects]] mutableCopy] autorelease];
        NSMutableArray* pathsToScanAnyway = [NSMutableArray array];
        
        // first read the DICOMDIR file
        if ([NSUserDefaults.standardUserDefaults boolForKey:@"UseDICOMDIRFileCD"]) {
            thread.status = NSLocalizedString(@"Looking for DICOMDIR...", nil);
            NSString* dicomdirPath = [[self class] _findDicomdirIn:allpaths];
            if (dicomdirPath) {
                NSLog(@"Scanning DICOMDIR at %@", dicomdirPath);
                thread.status = NSLocalizedString(@"Reading DICOMDIR...", nil);
                dicomImages = [self scanDicomdirAt:dicomdirPath withPaths:allpaths pathsToScanAnyway:pathsToScanAnyway];
            }
            
        //	NSLog(@"DICOMDIR referenced %d images: %@", dicomImages.count, [dicomImages valueForKey:@"completePath"]);
        }
        
        BOOL doScan = (![NSUserDefaults.standardUserDefaults boolForKey:@"UseDICOMDIRFileCD"]) || (!dicomImages.count && [NSUserDefaults.standardUserDefaults boolForKey:@"ScanDiskIfDICOMDIRZero"]);
        if (pathsToScanAnyway.count || doScan) {
            NSMutableArray* dicomFilePaths = [NSMutableArray arrayWithArray:pathsToScanAnyway];
            
            if (doScan) {
                thread.status = NSLocalizedString(@"Looking for DICOM files...", nil);
                thread.supportsCancel = YES;
                for (NSInteger i = 0; i < allpaths.count; ++i) {
                    thread.progress = 1.0*i/allpaths.count;
                    NSString* path = [allpaths objectAtIndex:i];
                    
                    if ([dicomFilePaths containsObject:path])
                        continue;
                    
                    if ([DicomFile isDICOMFile:path]) {
                        // avoid DICOMDIR files
                        if ([path.lastPathComponent.lowercaseString rangeOfString:@"dicomdir"].length == 0)
                            [dicomFilePaths addObject:path];
                    } else if ([path.pathExtension isEqualToString:@"zip"] || [path.pathExtension isEqualToString:@"osirixzip"]) {
                        [thread enterOperation];
                        thread.status = NSLocalizedString(@"Processing ZIP file...", @"");

                        // unzip file to a temporary place and add the files to allpaths
                        [NSFileManager.defaultManager confirmDirectoryAtPath:self.tempDirPath];
                        NSString* tempPath = [NSFileManager.defaultManager tmpFilePathInDir:self.tempDirPath];
                        [NSFileManager.defaultManager confirmDirectoryAtPath:tempPath];
                        
                        if ([BrowserController unzipFile:path withPassword:nil destination:tempPath] == NO) { // needs password
                            [self performSelectorOnMainThread:@selector(_requestZipPassword:) withObject:[NSArray arrayWithObjects: path, tempPath, NULL] waitUntilDone:YES];
                        }
                        
                        [self scanAtPath:tempPath isVolume:NO];
                        [thread exitOperation];
                    }
                    
                    if (thread.isCancelled)
                        return NO;
                }
            }
            
            dicomImages = [self addFilesAtPaths:dicomFilePaths postNotifications:NO dicomOnly:NO rereadExistingItems:NO generatedByOsiriX:NO];
        }
        
        if (!dicomImages.count)
            return NO;
        
        NSInteger mode = [NSUserDefaults.standardUserDefaults integerForKey:@"MOUNT"];
        if (mode == -1 || [[NSApp currentEvent] modifierFlags]&NSCommandKeyMask)
            [self performSelectorOnMainThread:@selector(_askUserDiscDataCopyOrBrowse:) withObject:[NSArray arrayWithObjects: path, [NSNumber numberWithInteger:dicomImages.count], [NSValue valueWithPointer:&mode], nil] waitUntilDone:YES];
        
        if (mode == 1) { // copy into database on mount
            NSThread* copyFilesThread = [NSThread performBlockInBackground:^{
                NSThread* cft = [NSThread currentThread];
                cft.name = NSLocalizedString(@"Importing images from media...", nil);
                cft.supportsCancel = YES;
                [ThreadsManager.defaultManager removeThread:thread];
                [ThreadsManager.defaultManager addThreadAndStart:cft];
                
                NSMutableArray* paths = [[[dicomImages valueForKey:@"completePath"] mutableCopy] autorelease];
                [paths removeDuplicatedStrings];
                
                int progress = 0;
                thread.progress = 0;
                
                [DicomDatabase.activeLocalDatabase.independentDatabase performSelector:@selector(copyFilesThread:)
                                                                            withObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                            paths, @"filesInput",
                                                                                            [NSNumber numberWithBool:YES], @"mountedVolume",
                                                                                            [NSNumber numberWithBool:YES], @"copyFiles",
                                                                                            [NSNumber numberWithBool: YES], @"addToAlbum",
                                                                                            [NSNumber numberWithBool: YES], @"selectStudy",
                                                                                        NULL]];
                
                [ThreadsManager.defaultManager removeThread:cft];
                [ThreadsManager.defaultManager addThreadAndStart:thread];
            }];
            
            while (copyFilesThread.isExecuting) {
                if (thread.isCancelled && !copyFilesThread.isCancelled)
                    [copyFilesThread cancel];
                [NSThread sleepForTimeInterval:0.01];
            }
            
            /*for (NSString* frompath in paths) {
                NSString* topath = nil;
                int i = 0;
                do {
                    topath = [db.incomingDirPath stringByAppendingPathComponent:[frompath lastPathComponent]];
                } while ([NSFileManager.defaultManager fileExistsAtPath:topath]);
                
                [NSFileManager.defaultManager copyItemAtPath:frompath toPath:topath error:NULL];

                thread.progress = CGFloat(++progress)/paths.count;
            }*/
            
            if (isVolume && [NSUserDefaults.standardUserDefaults boolForKey:@"CDDVDEjectAfterAutoCopy"] && ![copyFilesThread isCancelled]) {
                thread.status = NSLocalizedString(@"Ejecting...", nil);
                thread.progress = -1;
                
                [DCMPix purgeCachedDictionaries]; // <- This is very important to 'unlink' all opened files, otherwise MacOS will display the famous 'The disk is in use and could not be ejected'
                
                int attempts = 0;
                BOOL success = NO;
                while( success == NO)
                {
                    success = [[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtPath:  path];
                    if( success == NO)
                    {
                        attempts++;
                        if( attempts < 5)
                        {
                            [NSThread sleepForTimeInterval: 1.0];
                        }
                        else success = YES;
                    }
                }
                
                return YES;
            }
        }
        
    //    if (![[[BrowserController currentBrowser] sourceForDatabase:self] isBeingEjected]) {
        if (!thread.isCancelled) {
            thread.status = NSLocalizedString(@"Generating series thumbnails...", nil);
            NSMutableArray* dicomSeries	= [NSMutableArray array];
            for (DicomImage* di in dicomImages)
                if (![dicomSeries containsObject:di.series])
                    [dicomSeries addObject:di.series];
            for (NSInteger i = 0; i < dicomSeries.count; ++i)
                @try {
                    thread.progress = 1.0*i/dicomSeries.count;
                    [[dicomSeries objectAtIndex:i] thumbnail];
                } @catch (NSException* e) {
                    N2LogExceptionWithStackTrace(e);
                }
        }
    //    }
        
        if (mode == 2)
            return NO;
        
        /*
        
        
        for (int i = 0; i < 200; ++i) {
            thread.status = [NSString stringWithFormat:@"Iteration %d.", i];
            [NSThread sleepForTimeInterval:0.1];
        }
        */
    } @catch (NSException* e) {
        @throw;
    } @finally {
        [thread exitOperation];
    }
    
    return YES;
}

-(BOOL)scanAtPath:(NSString*)path {
	return [self scanAtPath:path isVolume:YES];
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


