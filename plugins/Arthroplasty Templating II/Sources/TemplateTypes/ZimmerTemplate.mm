//
//  ZimmerTemplate.m
//  Arthroplasty Templating II
//  Created by Joris Heuberger on 19/03/07.
//  Copyright (c) 2007-2009 OsiriX Team. All rights reserved.
//

#import "ZimmerTemplate.h"
#import <Nitrogen/Nitrogen.h>
#include <sstream>

@implementation ZimmerTemplate

+(NSArray*)templatesAtPath:(NSString*)path usingClass:(Class)classs {
	NSMutableArray* templates = [NSMutableArray array];
	
	BOOL isDirectory, exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
	if (exists)
		if (isDirectory) {
			NSDirectoryEnumerator* e = [[NSFileManager defaultManager] enumeratorAtPath:path];
			NSString* sub; while (sub = [e nextObject])
				[templates addObjectsFromArray:[ZimmerTemplate templatesAtPath:[path stringByAppendingPathComponent:sub] usingClass:classs]];
		} else
			if ([[path pathExtension] isEqualToString:@"txt"])
				[templates addObject:[[[classs alloc] initFromFileAtPath:path] autorelease]];
	
	return templates;
}

+(NSArray*)bundledTemplates {
	return [ZimmerTemplate templatesAtPath:[[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/Zimmer Templates"] usingClass:[ZimmerTemplate class]];
}

+(NSDictionary*)propertiesFromInfoFileAtPath:(NSString*)path {
	NSError* error;
	NSString* fileContent = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	if (!fileContent) {
		fileContent = [NSString stringWithContentsOfFile:path encoding:NSISOLatin1StringEncoding error:&error];
		if(!fileContent) {
			NSLog(@"[ZimmerTemplate propertiesFromFileInfoAtPath]: %@", error);
			return NULL;
		}
	}
	
	NSScanner* infoFileScanner = [NSScanner scannerWithString:fileContent];
	[infoFileScanner setCharactersToBeSkipped:[NSCharacterSet whitespaceCharacterSet]];
	
	NSMutableDictionary* properties = [[NSMutableDictionary alloc] initWithCapacity:128];
	NSCharacterSet* newlineCharacterSet = [NSCharacterSet newlineCharacterSet];
	while (![infoFileScanner isAtEnd]) {
		NSString *key = @"", *value = @"";
		[infoFileScanner scanUpToString:@":=:" intoString:&key];
		key = [key stringByTrimmingStartAndEnd];
		[infoFileScanner scanString:@":=:" intoString:NULL];
		[infoFileScanner scanUpToCharactersFromSet:newlineCharacterSet intoString:&value];
		value = [value stringByTrimmingStartAndEnd];
		[properties setObject:value forKey:key];
		[infoFileScanner scanCharactersFromSet:newlineCharacterSet intoString:NULL];
	}
	
	return [properties autorelease];
}

-(id)initFromFileAtPath:(NSString*)path {
	self = [super initWithPath:path];
	
	// properties
	_properties = [[ZimmerTemplate propertiesFromInfoFileAtPath:path] retain];
	if(!_properties)
		return NULL; // TODO: is self released?

	return self;
}

-(void)dealloc {
	[_properties release]; _properties = NULL;
	[super dealloc];
}

-(NSString*)pdfPathForDirection:(ArthroplastyTemplateViewDirection)direction {
	NSString* key = direction==ArthroplastyTemplateAnteriorPosteriorDirection? @"PDF_FILE_AP" : @"PDF_FILE_ML";
	NSString* filename = [_properties objectForKey:key];
	return [[_path stringByDeletingLastPathComponent] stringByAppendingPathComponent:filename];
}

-(NSString*)prefixForDirection:(ArthroplastyTemplateViewDirection)direction {
	return direction == ArthroplastyTemplateAnteriorPosteriorDirection? @"AP" : @"ML";
}

-(BOOL)origin:(NSPoint*)point forDirection:(ArthroplastyTemplateViewDirection)direction {
	NSString* prefix = [NSString stringWithFormat:@"%@_ORIGIN_", [self prefixForDirection:direction]];
	
	NSString* key = [NSString stringWithFormat:@"%@X", prefix];
	NSString *xs = [_properties objectForKey:key];
	key = [NSString stringWithFormat:@"%@Y", prefix];
	NSString *ys = [_properties objectForKey:key];
	
	if (!xs || !ys || ![xs length] || ![ys length])
		return NO;

	std::istringstream([xs UTF8String]) >> point->x;
	std::istringstream([ys UTF8String]) >> point->y;
	*point = *point / 25.4; // 1in = 25.4mm, ORIGIN data in mm

	return YES;
}

-(NSArray*)rotationPointsForDirection:(ArthroplastyTemplateViewDirection)direction {
	NSMutableArray* points = [NSMutableArray arrayWithCapacity:5];
	NSString* prefix = [NSString stringWithFormat:@"%@_HEAD_ROTATION_POINT_", [self prefixForDirection:direction]];
	
	NSPoint origin; [self origin:&origin forDirection:direction];
	
	for (unsigned i = 1; i <= 5; ++i) {
		NSString* sx = [_properties objectForKey:[NSString stringWithFormat:@"%@%d_X", prefix, i]];
		NSString* sy = [_properties objectForKey:[NSString stringWithFormat:@"%@%d_Y", prefix, i]];
		NSPoint point = {0,0};
		if ([sx length] && [sy length]) {
			std::istringstream([sx UTF8String]) >> point.x;
			std::istringstream([sy UTF8String]) >> point.y;
			point = point/25.4;
		}
		[points addObject:[NSValue valueWithPoint:point+origin]];
	}
	
	return points;
}

-(NSImage*)imageForDirection:(ArthroplastyTemplateViewDirection)direction {
	return [[[NSImage alloc] initWithContentsOfFile:[self pdfPathForDirection:direction]] autorelease];
}

-(NSArray*)textualData {
	return [NSArray arrayWithObjects:[self name], [NSString stringWithFormat:@"Size: %@", [self size]], [self manufacturer], @"", @"", NULL];
}

// props

-(NSString*)fixation {
	return [_properties objectForKey:@"FIXATION_TYPE"];
}

-(NSString*)group {
	return [_properties objectForKey:@"PRODUCT_GROUP"];
}

-(NSString*)manufacturer {
	return [_properties objectForKey:@"IMPLANT_MANUFACTURER"];
}

-(NSString*)modularity {
	return [_properties objectForKey:@"MODULARITY_INFO"];
}

-(NSString*)name {
	return [_properties objectForKey:@"PRODUCT_FAMILY_NAME"];
}

-(NSString*)placement {
	return [_properties objectForKey:@"LEFT_RIGHT"];
}

-(NSString*)surgery {
	return [_properties objectForKey:@"TYPE_OF_SURGERY"];
}

-(NSString*)type {
	return [_properties objectForKey:@"COMPONENT_TYPE"];
}

-(NSString*)size {
	return [_properties objectForKey:@"SIZE"];
}

-(NSString*)referenceNumber {
	return [_properties objectForKey:@"REF_NO"];
}

-(CGFloat)scale {
	return 1;
}

-(CGFloat)rotation {
	return 0;
}

@end
