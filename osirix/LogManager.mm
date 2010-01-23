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

#import "LogManager.h"
#import "browserController.h"
#import "DICOMToNSString.h"
#import "DicomFile.h"

static LogManager *currentLogManager = nil;

@implementation LogManager

+ (id) currentLogManager
{
	if (!currentLogManager)
		currentLogManager = [[LogManager alloc] init];
	return currentLogManager;
}

- (id) init
{
	if (self = [super init])
	{
		_currentLogs = [[NSMutableDictionary alloc] init];
		_timer = [[NSTimer scheduledTimerWithTimeInterval: 5 target:self selector:@selector(checkLogs:) userInfo:nil repeats:YES] retain];
	}
	return self;
}

- (void) resetLogs
{
	NSManagedObjectContext *context = [[BrowserController currentBrowser] managedObjectContextLoadIfNecessary: NO];
	NSManagedObjectModel *model = [[BrowserController currentBrowser] managedObjectModel];
	[context retain];
	[context lock];
	
	[_currentLogs removeAllObjects];
	
	@try
	{
		NSFetchRequest *dbRequest = [[[NSFetchRequest alloc] init] autorelease];
		[dbRequest setEntity: [[model entitiesByName] objectForKey: @"LogEntry"]];
		
		[dbRequest setPredicate: [NSPredicate predicateWithFormat: @"message like[cd] %@", @"In Progress"]];
		NSError	*error = nil;
		NSArray *array = [context executeFetchRequest:dbRequest error:&error];
		
		for( NSManagedObject *o in array)
		{
			[o setValue: @"Incomplete" forKey:@"message"];
		}
	}
	@catch (NSException * e)
	{
	}
	
	
	[context unlock];
	[context release];
}

- (void) dealloc
{
	[_currentLogs release];
	[_timer invalidate];
	[_timer release];
	[super dealloc];
}

- (NSString *) logFolder
{
	NSString *path =  [[[BrowserController currentBrowser] documentsDirectory] stringByAppendingPathComponent:@"TEMP.noindex"];
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL isDir;
	if (!([manager fileExistsAtPath:path isDirectory:&isDir] && isDir))
	{
		[manager createDirectoryAtPath:path attributes:nil];
	}
	return path;
}

- (void) checkLogs:(NSTimer *)timer
{
	if( [[BrowserController currentBrowser] isNetworkLogsActive])
	{
		NSManagedObjectContext *context = [[BrowserController currentBrowser] managedObjectContextLoadIfNecessary: NO];
		if( context == nil)
		{
			NSLog(@"***** log context == nil");
			return;
		}
		
		if( [[BrowserController currentBrowser] isCurrentDatabaseBonjour]) return;
		
		char logPatientName[ 1024];
		char logStudyDescription[ 1024];
		char logCallingAET[ 1024];
		char logStartTime[ 1024];
		char logMessage[ 1024];
		char logUID[ 1024];
		char logNumberReceived[ 1024];
		char logNumberTotal[ 1024];
		char logEndTime[ 1024];
		char logType[ 1024];
		char logEncoding[ 1024];

		logPatientName[ 0] = 0;
		logStudyDescription[ 0] = 0;
		logCallingAET[ 0] = 0;
		logStartTime[ 0] = 0;
		logMessage[ 0] = 0;
		logUID[ 0] = 0;
		logNumberReceived[ 0] = 0;
		logNumberTotal[ 0] = 0;
		logEndTime[ 0] = 0;
		logType[ 0] = 0;
		logEncoding[ 0] = 0;
		
		[context retain];
		if( [context tryLock])
		{
			NSString *logFolder = [self logFolder];
			NSFileManager *manager = [NSFileManager defaultManager];
			NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath: logFolder];
			NSString *path;
			
			NS_DURING
			while (path = [enumerator nextObject])
			{
				if ([[path pathExtension] isEqualToString: @"log"])
				{
					NSString *file = [logFolder stringByAppendingPathComponent:path];
					NSString *newfile = [file stringByAppendingString:@"reading"];
					
					rename( [file UTF8String], [newfile UTF8String]);
					remove( [file UTF8String]);
					
					FILE * pFile;
					pFile = fopen ( [newfile UTF8String], "r");
					if( pFile)
					{
						char data[ 4096];
						
						fread( data, 4096, 1 ,pFile);
						
						char *curData = data;
						
						if(curData) strcpy( logPatientName, strsep( &curData, "\r"));
						if(curData) strcpy( logStudyDescription, strsep( &curData, "\r"));
						if(curData) strcpy( logCallingAET, strsep( &curData, "\r"));
						if(curData) strcpy( logStartTime, strsep( &curData, "\r"));
						if(curData) strcpy( logMessage, strsep( &curData, "\r"));
						if(curData) strcpy( logUID, strsep( &curData, "\r"));
						if(curData) strcpy( logNumberReceived, strsep( &curData, "\r"));
						if(curData) strcpy( logEndTime, strsep( &curData, "\r"));
						if(curData) strcpy( logType, strsep( &curData, "\r"));
						if(curData) strcpy( logEncoding, strsep( &curData, "\r"));
						if(curData) strcpy( logNumberTotal, strsep( &curData, "\r"));
						
						fclose (pFile);
						remove( [newfile UTF8String]);
						
						// Encoding
						NSStringEncoding encoding[ 10];
						for( int i = 0; i < 10; i++) encoding[ i] = NSISOLatin1StringEncoding;
						NSArray	*c = [[NSString stringWithCString: logEncoding] componentsSeparatedByString:@"\\"];
						
						if( [c count] < 10)
						{
							for( int i = 0; i < [c count]; i++) encoding[ i] = [NSString encodingForDICOMCharacterSet: [c objectAtIndex: i]];
							for( int i = [c count]; i < 10; i++) encoding[ i] = [NSString encodingForDICOMCharacterSet: [c lastObject]];
						}
						
						if( [[NSString stringWithUTF8String: logMessage] isEqualToString:@"In Progress"] || [[NSString stringWithUTF8String: logMessage] isEqualToString:@"Complete"])
						{				
							NSString *uid = [NSString stringWithUTF8String: logUID];
							id logEntry = [_currentLogs objectForKey:uid];
							if (logEntry == nil)
							{
								logEntry = [NSEntityDescription insertNewObjectForEntityForName:@"LogEntry" inManagedObjectContext:context];
								
								[logEntry setValue:[NSDate dateWithTimeIntervalSince1970: [[NSString stringWithUTF8String: logStartTime] intValue]]  forKey:@"startTime"];
								[logEntry setValue:[NSString stringWithUTF8String: logType] forKey:@"type"];
								[logEntry setValue:[NSString stringWithUTF8String: logCallingAET] forKey:@"originName"];
								[logEntry setValue:[DicomFile stringWithBytes: (char*) logPatientName encodings: encoding] forKey:@"patientName"];
								[logEntry setValue:[DicomFile stringWithBytes: (char*) logStudyDescription encodings: encoding] forKey:@"studyName"];
								
								[_currentLogs setObject:logEntry forKey:uid];
							}
							
							if( logEntry != nil && [logEntry isDeleted] == NO)
							{
								[logEntry setValue:[NSString stringWithUTF8String: logMessage] forKey:@"message"];
								[logEntry setValue:[NSNumber numberWithInt: [[NSString stringWithUTF8String: logNumberTotal] intValue]] forKey:@"numberImages"];
								[logEntry setValue:[NSNumber numberWithInt: [[NSString stringWithUTF8String: logNumberReceived] intValue]] forKey:@"numberSent"];
								
								if( [[NSString stringWithUTF8String: logMessage] isEqualToString:@"Complete"])
								{
									if( [[NSString stringWithUTF8String: logEndTime] intValue] == 0)
										strcpy( logEndTime, [[NSString stringWithFormat:@"%d", time (NULL)] UTF8String]);
										
									[_currentLogs removeObjectForKey: uid];
								}
								
								if( [[NSString stringWithUTF8String: logEndTime] intValue] != 0)
									[logEntry setValue:[NSDate dateWithTimeIntervalSince1970: [[NSString stringWithUTF8String: logEndTime] intValue]] forKey:@"endTime"];
							}
						}
						else NSLog(@"***** Unknown log message type");
					}
					else NSLog(@"***** Unable to load a log message");
				}
			}

			NS_HANDLER
				NSLog(@"Exception while checking logs: %@", [localException description]);
			NS_ENDHANDLER
			
			[context unlock];
		}
		
		[context release];
	}
}
@end
