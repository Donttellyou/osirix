//
//  N2Operators.h
//  Nitrogen Framework
//
//  Created by Alessandro Volz on 6/25/09.
//  Copyright 2009 OsiriX Team. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* N2LinesDontInterceptException;

CGFloat NSSign(const CGFloat f);
CGFloat NSLimit(const CGFloat v, const CGFloat min, const CGFloat max);

NSSize NSMakeSize(CGFloat wh);
NSSize operator-(const NSSize& s);						// -[x,y] = [-x,-y]
NSSize operator+(const NSSize& s1, const NSSize& s2);	// [x,y]+[X,Y] = [x+X,y+Y]
NSSize operator+=(NSSize& s1, const NSSize& s2);
NSSize operator-(const NSSize& s1, const NSSize& s2);	// [x,y]-[X,Y] = -[X,Y]+[x,y] = [x-X,y-Y]
NSSize operator-=(NSSize& s1, const NSSize& s2);
NSSize operator*(const NSSize& s1, const NSSize& s2);
NSSize operator*=(NSSize& s1, const NSSize& s2);
NSSize operator/(const NSSize& s1, const NSSize& s2);
NSSize operator/=(NSSize& s1, const NSSize& s2);
BOOL operator==(const NSSize& s1, const NSSize& s2);
BOOL operator!=(const NSSize& s1, const NSSize& s2);

NSSize operator+(const NSSize& s, const CGFloat f);
NSSize operator+=(NSSize& s, const CGFloat f);
NSSize operator-(const NSSize& s, const CGFloat f);
NSSize operator-=(NSSize& s, const CGFloat f);
NSSize operator*(const CGFloat f, const NSSize& s);		// [x,y]*d = [x*d,y*d]
NSSize operator/(const CGFloat f, const NSSize& s);
NSSize operator*(const NSSize& s, const CGFloat f);
NSSize operator*=(NSSize& s, const CGFloat f);
NSSize operator/(const NSSize& s, const CGFloat f);
NSSize operator/=(NSSize& s, const CGFloat f);

NSPoint operator-(const NSPoint& p);						// -[x,y] = [-x,-y]
NSPoint operator+(const NSPoint& p1, const NSPoint& p2);	// [x,y]+[X,Y] = [x+X,y+Y]
NSPoint operator+=(NSPoint& p1, const NSPoint& p2);
NSPoint operator-(const NSPoint& p1, const NSPoint& p2);	// [x,y]-[X,Y] = -[X,Y]+[x,y] = [x-X,y-Y]
NSPoint operator-=(NSPoint& p1, const NSPoint& p2);
NSPoint operator*(const NSPoint& p1, const NSPoint& p2);
NSPoint operator*=(NSPoint& p1, const NSPoint& p2);
NSPoint operator/(const NSPoint& p1, const NSPoint& p2);
NSPoint operator/=(NSPoint& p1, const NSPoint& p2);
BOOL operator==(const NSPoint& p1, const NSPoint& p2);
BOOL operator!=(const NSPoint& p1, const NSPoint& p2);

NSPoint operator+(const NSPoint& p, const CGFloat f);
NSPoint operator+=(NSPoint& p, const CGFloat f);
NSPoint operator-(const NSPoint& p, const CGFloat f);
NSPoint operator-=(NSPoint& p, const CGFloat f);
NSPoint operator*(const CGFloat f, const NSPoint& p);
NSPoint operator/(const CGFloat f, const NSPoint& p);
NSPoint operator*(const NSPoint& p, const CGFloat f);		// [x,y]*d = [x*d,y*d]
NSPoint operator*=(NSPoint& p, const CGFloat f);
NSPoint operator/(const NSPoint& p, const CGFloat f);		// [x,y]/d = [x/d,y/d]
NSPoint operator/=(NSPoint& p, const CGFloat f);

NSPoint NSMakePoint(const NSSize& s);
NSSize operator+(const NSSize& s, const NSPoint& p);
NSPoint operator+(const NSPoint& p, const NSSize& s);
NSSize operator-(const NSSize& s, const NSPoint& p);
NSPoint operator-(const NSPoint& p, const NSSize& s);
NSSize operator*(const NSSize& s, const NSPoint& p);
NSPoint operator*(const NSPoint& p, const NSSize& s);
NSSize operator/(const NSSize& s, const NSPoint& p);
NSPoint operator/(const NSPoint& p, const NSSize& s);

CGFloat NSDistance(const NSPoint& p1, const NSPoint& p2);
CGFloat NSAngle(const NSPoint& p1, const NSPoint& p2);
NSPoint NSMiddle(const NSPoint& p1, const NSPoint& p2);

typedef struct _NSVector : NSPoint {
} NSVector;

NSVector NSMakeVector(CGFloat x, CGFloat y);
NSVector NSMakeVector(const NSPoint& from, const NSPoint& to);
NSVector NSMakeVector(const NSPoint& p);
NSPoint NSMakePoint(const NSVector& p);

NSVector operator!(const NSVector& v);

CGFloat NSLength(const NSVector& v);
CGFloat NSAngle(const NSVector& v);

typedef struct _NSLine {
    NSPoint origin;
	NSVector direction;
} NSLine;

NSLine NSMakeLine(const NSPoint& origin, const NSVector& direction);
NSLine NSMakeLine(const NSPoint& p1, const NSPoint& p2);

CGFloat NSAngle(const NSLine& l);
BOOL NSParallel(const NSLine& l1, const NSLine& l2);
NSPoint operator*(const NSLine& l1, const NSLine& l2);		// intersection of lines
CGFloat NSLineYAtX(const NSLine& l1, CGFloat x);

NSRect NSMakeRect(const NSPoint& o, const NSSize& s);
NSRect NSInsetRect(const NSRect& r, const NSSize& s);
NSRect operator+(const NSRect& r, const NSSize& s);
NSRect operator-(const NSRect& r, const NSSize& s);
