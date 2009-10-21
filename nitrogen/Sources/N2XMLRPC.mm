//
//  N2XMLRPC.mm
//  Nitrogen
//
//  Created by Alessandro Volz on 28.09.09.
//  Copyright 2009 OsiriX Team. All rights reserved.
//

#import "N2XMLRPC.h"
#import "ISO8601DateFormatter.h"
#import <Nitrogen/NSData+N2.h>
#import <Nitrogen/NSString+N2.h>

@implementation N2XMLRPC

+(NSObject*)ParseElement:(NSXMLNode*)n {
	if ([n kind] == NSXMLTextKind)
		return [n stringValue];
	
	NSXMLElement* e = (NSXMLElement*)n;
	
	if ([[e name] isEqualToString:@"array"]) {
		NSArray* values = [e nodesForXPath:@"data/value/*" error:NULL];
		NSMutableArray* returnValues = [NSMutableArray arrayWithCapacity:[values count]];
		for (NSXMLElement* v in values)
			[returnValues addObject:[N2XMLRPC ParseElement:v]];
		return [NSArray arrayWithArray:returnValues];
	}
	
	if ([[e name] isEqualToString:@"base64"]) {
		return [NSData dataWithBase64:[[e childAtIndex:0] stringValue]];
	}
	
	if ([[e name] isEqualToString:@"boolean"]) {
		return [NSNumber numberWithBool:[[e stringValue] boolValue]];
	}
	
	if ([[e name] isEqualToString:@"dateTime.iso8601"]) {
		return [[[[ISO8601DateFormatter alloc] init] autorelease] dateFromString:[e stringValue]];
	}
	
	if ([[e name] isEqualToString:@"double"]) {
		return [NSNumber numberWithDouble:[[e stringValue] doubleValue]];
	}
	
	if ([[e name] isEqualToString:@"i4"] || [[e name] isEqualToString:@"int"]) {
		return [NSNumber numberWithInt:[[e stringValue] intValue]];
	}
	
	if ([[e name] isEqualToString:@"string"]) {
		return [[e stringValue] xmlUnescapedString];
	}
	
	if ([[e name] isEqualToString:@"struct"]) {
		NSArray* members = [e nodesForXPath:@"member" error:NULL];
		NSMutableDictionary* returnMembers = [NSMutableDictionary dictionaryWithCapacity:[members count]];
		for (NSXMLElement* m in members)
			[returnMembers setObject:[N2XMLRPC ParseElement:[[m nodesForXPath:@"value/*" error:NULL] objectAtIndex:0]] forKey:[[[m nodesForXPath:@"name" error:NULL] objectAtIndex:0] stringValue]];
		return [NSDictionary dictionaryWithDictionary:returnMembers];
	}
	
	if ([[e name] isEqualToString:@"nil"]) {
		return NULL;
	}
	
	[NSException raise:NSGenericException format:@"unhandled XMLRPC data type: %@", [e name]]; return NULL;
}

+(NSString*)FormatElement:(NSObject*)o {
	if (!o)
		return @"<nil/>";
	
	if ([o isKindOfClass:[NSDictionary class]]) {
		NSMutableString* s = [NSMutableString stringWithCapacity:512];
		[s appendString:@"<struct>"];
		for (NSString* k in (NSDictionary*)o)
			[s appendFormat:@"<member><name>%@</name><value>%@</value></member>", k, [N2XMLRPC FormatElement:[(NSDictionary*)o objectForKey:k]]];
		[s appendString:@"</struct>"];
		return [NSString stringWithString:s];
	}
	
	if ([o isKindOfClass:[NSString class]]) {
		return [NSString stringWithFormat:@"<string>%@</string>", [(NSString*)o xmlEscapedString]];
	}
	
	if ([o isKindOfClass:[NSArray class]]) {
		NSMutableString* s = [NSMutableString stringWithCapacity:512];
		[s appendString:@"<array><data>"];
		for (NSObject* o2 in (NSArray*)o)
			[s appendFormat:@"<value>%@</value>", [N2XMLRPC FormatElement:o2]];
		[s appendString:@"</data></array>"];
		return [NSString stringWithString:s];
	}
	
	if ([o isKindOfClass:[NSDate class]]) {
		return [NSString stringWithFormat:@"<dateTime.iso8601>%@</dateTime.iso8601>", [[[[ISO8601DateFormatter alloc] init] autorelease] stringFromDate:(NSDate*)o]];
	}
	
	if ([o isKindOfClass:[NSData class]]) {
		return [NSString stringWithFormat:@"<base64>%@</base64>", [(NSData*)o base64]];
	}
	
	if ([o isKindOfClass:[NSNumber class]])
		switch ([(NSNumber*)o objCType][0]) {
			case 'c':
				return [NSString stringWithFormat:@"<boolean>%d</boolean>", int([(NSNumber*)o boolValue])];
			case 'i':
				return [NSString stringWithFormat:@"<int>%d</int>", [(NSNumber*)o intValue]];
			case 'f':
			case 'd':
				return [NSString stringWithFormat:@"<double>%f</double>", [(NSNumber*)o doubleValue]];
			default:
				[NSException raise:NSGenericException format:@"execution succeeded but return NSNumber of type %c unsupported", [(NSNumber*)o objCType][0]]; return NULL;
	}
	
	[NSException raise:NSGenericException format:@"execution succeeded but return class %@ unsupported", [o className]]; return NULL;
}

+(NSString*)ReturnElement:(NSInvocation*)invocation {
	const char* returnType = [[invocation methodSignature] methodReturnType];
	switch (returnType[0]) {
		case '@': {
			NSObject* o; [invocation getReturnValue:&o];
			return [N2XMLRPC FormatElement:o];
		} break;
		case 'i': {
			NSInteger i; [invocation getReturnValue:&i];
			return [NSString stringWithFormat:@"<int>%d</int>", i];
		} break;
		case 'f': {
			CGFloat f; [invocation getReturnValue:&f];
			return [NSString stringWithFormat:@"<double>%f</double>", f];
		} break;
	}
	
	[NSException raise:NSGenericException format:@"execution succeeded but return type %c unsupported", returnType[0]]; return NULL;
}

@end
