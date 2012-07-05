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

#import "ComparativeCell.h"
#import "NSString+N2.h"
#import "N2Operators.h"
#import "N2Debug.h"

@implementation ComparativeCell

@synthesize rightTextFirstLine = _rightTextFirstLine;
@synthesize rightTextSecondLine = _rightTextSecondLine;
@synthesize leftTextSecondLine = _leftTextSecondLine;
@synthesize textColor = _textColor;

-(id)init
{
    if ((self = [super init]))
    {
        [self setImagePosition:NSImageLeft];
        [self setAlignment:NSLeftTextAlignment];
        [self setHighlightsBy:NSNoCellMask];
        [self setShowsStateBy:NSNoCellMask];
        [self setBordered:NO];
        [self setLineBreakMode:NSLineBreakByTruncatingMiddle];
        [self setButtonType:NSMomentaryChangeButton];
    }
    
    return self;
}

-(void)dealloc
{
    self.textColor = nil;
    self.rightTextFirstLine = nil;
    self.rightTextSecondLine = nil;
    self.leftTextSecondLine = nil;
    [super dealloc];
}

-(id)copyWithZone:(NSZone *)zone
{
    ComparativeCell* copy = [super copyWithZone:zone];
    
    copy->_rightTextFirstLine = [self.rightTextFirstLine copyWithZone:zone];
    copy->_rightTextSecondLine = [self.rightTextSecondLine copyWithZone:zone];
    copy->_leftTextSecondLine = [self.leftTextSecondLine copyWithZone:zone];
    copy->_textColor = [self.textColor copyWithZone:zone];
    
    return copy;
}

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView
{
    frame.origin.x += 1;
    
    [super drawImage:image withFrame:frame inView:controlView];
}

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)controlView
{
    NSRect initialFrame = frame;

    [super drawWithFrame:frame inView:controlView];
}

- (NSRect)drawTitle:(NSAttributedString*)title withFrame:(NSRect)frame inView:(NSView *)controlView
{
    NSRect initialFrame = frame;
    static const CGFloat spacer = 2;

    NSMutableAttributedString* mutableTitle = [[title mutableCopy] autorelease];
    if (self.textColor) [mutableTitle addAttributes:[NSDictionary dictionaryWithObjectsAndKeys:self.textColor, NSForegroundColorAttributeName, nil] range:mutableTitle.range];
    title = mutableTitle;
    
    // First Line
    
    if (self.rightTextFirstLine)
    {
        NSMutableDictionary* attributes = [[[self.attributedTitle attributesAtIndex:0 effectiveRange:NULL] mutableCopy] autorelease];
        NSMutableParagraphStyle* rightAlignmentParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [rightAlignmentParagraphStyle setAlignment:NSRightTextAlignment];
        [attributes setObject:rightAlignmentParagraphStyle forKey:NSParagraphStyleAttributeName];

        frame.origin.y += 2;
        [self.rightTextFirstLine drawInRect:frame withAttributes:attributes];
        frame.origin.y -= 2;
        
        CGFloat w = [self.rightTextFirstLine sizeWithAttributes:attributes].width;
        frame.size.width -= w + spacer;
    }
    
    if (self.title)
    {
        NSMutableDictionary* attributes = [[[self.attributedTitle attributesAtIndex:0 effectiveRange:NULL] mutableCopy] autorelease];
        NSMutableParagraphStyle* leftAlignmentParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [leftAlignmentParagraphStyle setAlignment:NSLeftTextAlignment];
        [leftAlignmentParagraphStyle setLineBreakMode: NSLineBreakByTruncatingTail];
        [attributes setObject:leftAlignmentParagraphStyle forKey:NSParagraphStyleAttributeName];
        
        frame.origin.y += 2;
        [self.title drawInRect:frame withAttributes:attributes];
        frame.origin.y -= 2;
    }
    
    // Second Line
    frame = initialFrame;
    
    if (self.rightTextSecondLine)
    {
        NSMutableDictionary* attributes = [[[self.attributedTitle attributesAtIndex:0 effectiveRange:NULL] mutableCopy] autorelease];
        NSMutableParagraphStyle* rightAlignmentParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [rightAlignmentParagraphStyle setAlignment:NSRightTextAlignment];
        [attributes setObject:rightAlignmentParagraphStyle forKey:NSParagraphStyleAttributeName];
        
        initialFrame.origin.y += 2 + 17;
        [self.rightTextSecondLine drawInRect:initialFrame withAttributes:attributes];
        initialFrame.origin.y -= 2 + 17;
        
        CGFloat w = [self.rightTextSecondLine sizeWithAttributes:attributes].width;
        frame.size.width -= w + spacer;
    }
    
    if (self.leftTextSecondLine)
    {
        NSMutableDictionary* attributes = [[[self.attributedTitle attributesAtIndex:0 effectiveRange:NULL] mutableCopy] autorelease];
        NSMutableParagraphStyle* leftAlignmentParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [leftAlignmentParagraphStyle setAlignment:NSLeftTextAlignment];
        [leftAlignmentParagraphStyle setLineBreakMode: NSLineBreakByTruncatingTail];
        [attributes setObject:leftAlignmentParagraphStyle forKey:NSParagraphStyleAttributeName];
        
        frame.origin.y += 2 + 17;
        [self.leftTextSecondLine drawInRect:frame withAttributes:attributes];
        frame.origin.y -= 2 + 17;
    }
    
    return initialFrame;
}

- (BOOL)trackMouse:(NSEvent*)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)untilMouseUp
{
    return NO;
}

-(void)setPlaceholderString:(NSString*)str
{
    // this is a dummy function... AppKit calls this, and if we don't implement it, it fails
}

@end
