//
//  DCMViewAnnotationCategory.m
//  WindowAnchoredAnnotations
//
//  Created by ibook on 2007-01-07.
//  Copyright 2007 jacques.fauquex@opendicom.com All rights reserved.
//

#import "DCMViewAnnotationCategory.h"
#import "DCMView.h"

@implementation DCMView (DCMViewAnnotationCategory)

-(void) processorOfLayout:(NSArray *)curLayout
{
	//NSLog(@"DCMViewAnnotationCategory processorOfLayout");
	
	NSArray *annotationLine = [curLayout objectAtIndex:0];
	NSArray *annotationFormat = [curLayout objectAtIndex:1];
	NSArray *annotationType = [curLayout objectAtIndex:2];
	NSArray *annotationObject = [curLayout objectAtIndex:3];
	NSArray *annotationSelector = [curLayout objectAtIndex:4];
	NSArray *annotationArgument = [curLayout objectAtIndex:5];
	NSArray *targets = [NSArray arrayWithObjects:
		self,
		[dcmFilesList objectAtIndex:[self indexForPix:curImage]],
		[self windowController],
		@"curROI",
		curDCM,
		@"dicomObject",
		 nil
	];
	//falta el metodo para definir curROI and dicomObject
	
	//NSLog(@"x,y:%f %f",	contextualMenuInWindowPosX, contextualMenuInWindowPosY);	
	if ([targets count] == 6)
	{
		//loop processing each item, and when the item is a line, drawing it
		unsigned currentItem;
		NSMutableString *lineItemsString = [NSMutableString stringWithCapacity:64]; //fifo pile of arguments for line
		for (currentItem = 0; currentItem < [annotationType count]; currentItem++)
		{
			//NSLog(@"case %d:'%@'",currentItem,[annotationFormat objectAtIndex:currentItem]);
			switch([[annotationType objectAtIndex:currentItem] intValue])
			{
				case 0:	// immutableString
						[lineItemsString appendString:[annotationFormat objectAtIndex:currentItem]];
				break;
				
				case 1:	// string
						if ([annotationFormat objectAtIndex:currentItem])
						{
							[lineItemsString appendFormat:[annotationFormat objectAtIndex:currentItem],
								[
									[targets objectAtIndex:[[annotationObject objectAtIndex:currentItem] intValue]] 
										performSelector:NSSelectorFromString([annotationSelector objectAtIndex:currentItem]) 
											withObject:[annotationArgument objectAtIndex:currentItem]
								]
							];
						}
				break;
				
				case 2:	// date
						[lineItemsString appendString:
							[
								[
									[targets objectAtIndex:[[annotationObject objectAtIndex:currentItem] intValue]] 
										performSelector:NSSelectorFromString([annotationSelector objectAtIndex:currentItem]) 
											withObject:[annotationArgument objectAtIndex:currentItem]
								]
								descriptionWithCalendarFormat:[annotationFormat objectAtIndex:currentItem]
								timeZone:nil
								locale:nil
							]
						];
				break;
				
				case 3:	// boolValue
						[lineItemsString appendString:@"boolValue"];
				break;
				
				case 4:	// intValue
						[lineItemsString appendFormat:[annotationFormat objectAtIndex:currentItem],
							[
								[
									[targets objectAtIndex:[[annotationObject objectAtIndex:currentItem] intValue]] 
										performSelector:NSSelectorFromString([annotationSelector objectAtIndex:currentItem]) 
											withObject:[annotationArgument objectAtIndex:currentItem]
								]
								intValue
							]
						];
				break;
				
				case 5:	// floatValue
						[lineItemsString appendFormat:[annotationFormat objectAtIndex:currentItem],
							[
								[
									[targets objectAtIndex:[[annotationObject objectAtIndex:currentItem] intValue]] 
										performSelector:NSSelectorFromString([annotationSelector objectAtIndex:currentItem]) 
											withObject:[annotationArgument objectAtIndex:currentItem]
								]
								floatValue
							]
						];
				break;
				
				default:
						NSLog(@"Line option %d not valid",[[annotationType objectAtIndex:currentItem] intValue]);
			}
			
			//last item of a line -> draw the line
			if ([[annotationLine objectAtIndex:currentItem] intValue] > 0)		
			{
				//NSLog(lineItemsString);
				[self  DrawNSStringGLPlugin:lineItemsString position:[[annotationLine objectAtIndex:currentItem] intValue]];
				[lineItemsString setString:@""];
			}
		}
	}
	else
	{
		NSLog(@"targets could define only %d informators... (process aborted)",[targets count]);
	}
}

-(void) DrawNSStringGLPlugin:(NSString*)str position:(int)pos
{	
	NSRect size = [self frame];
	//openGl works with C strings
	unsigned char	*lstr = (unsigned char*) [str UTF8String];
	short lstrLength = [str length];
	short margin = 5;
	short rightMargin = margin + stringSize.width;
	short topMargin = margin + stringSize.height;
	short y;
	short x;
	short i;
	switch(pos)
	{
		case 0:	// top centered
			y = topMargin;
			x = size.size.width - stringSize.width;
			//loop variable avoiding last character (NULL terminating C string)
			while (i++ < lstrLength) x -= fontListGLSize[ lstr[ i]];
			x /=2;
		break;
		
		case 1:	// top left
			y = topMargin;
			x = margin;
		break;
		
		case 2:	
			y = topMargin + (stringSize.height * 1.1);
			x = margin;
		break;

		case 3:	
			y = topMargin + (stringSize.height * 2.2);
			x = margin;
		break;
		
		case 4:	
			y = topMargin + (stringSize.height * 3.3);
			x = margin;
		break;
		
		case 5:	//left centered
			y = (size.size.height / 2) + (stringSize.height / 2);
			x = margin;
		break;
		
		case 6:	// bottom left
			y = size.size.height - margin - (stringSize.height * 3.3);
			x = margin;
		break;

		case 7:	
			y = size.size.height - margin - (stringSize.height * 2.2);
			x = margin;
		break;
		
		case 8:	
			y = size.size.height - margin - (stringSize.height * 1.1);
			x = margin;
		break;

		case 9:	
			y = size.size.height - margin;
			x = margin;
		break;

		case 10: // bottom centered
			y = size.size.height - margin;
			x = size.size.width - stringSize.width ;
			//loop variable avoiding last character (NULL terminating C string)
			while (i++ < lstrLength) x -= fontListGLSize[ lstr[ i]];
			x /=2;
		break;
		
		case 11: // top right
			y = topMargin;
			x = size.size.width - rightMargin;
			while (i++ < lstrLength) x -= fontListGLSize[ lstr[ i]];
		break;
		
		case 12:
			y = topMargin + (stringSize.height * 1.1);
			x = size.size.width - rightMargin;
			while (i++ < lstrLength) x -= fontListGLSize[ lstr[ i]];
		break;

		case 13:
			y = topMargin + (stringSize.height * 2.2);
			x = size.size.width - rightMargin;
			while (i++ < lstrLength) x -= fontListGLSize[ lstr[ i]];
		break;
		
		case 14:
			y = topMargin + (stringSize.height * 3.3);
			x = size.size.width - rightMargin;
			while (i++ < lstrLength) x -= fontListGLSize[ lstr[ i]];
		break;
		
		case 15: // right centered	
			y = (size.size.height/2) + (stringSize.height/2);
			x = size.size.width - rightMargin;
			while (i++ < lstrLength) x -= fontListGLSize[ lstr[ i]];
		break;
		
		case 16: //bottom right
			y = (short) (size.size.height - margin - (stringSize.height * 3.3));
			x = size.size.width - rightMargin;
			while (i++ < lstrLength) x -= fontListGLSize[ lstr[ i]];
		break;

		case 17:
			y = size.size.height - margin - (stringSize.height * 2.2);
			x = size.size.width - rightMargin;
			while (i++ < lstrLength) x -= fontListGLSize[ lstr[ i]];
		break;
		
		case 18:
			y = size.size.height - margin - (stringSize.height * 1.1);
			x = size.size.width - rightMargin;
			while (i++ < lstrLength) x -= fontListGLSize[ lstr[ i]];
		break;

		case 19:
			y = size.size.height - margin; //bottom
			x = size.size.width - rightMargin;
			while (i++ < lstrLength) x -= fontListGLSize[ lstr[ i]];
		break;

		case 20:	// centered in function of float contextualMenuInWindowPosX, contextualMenuInWindowPosY;
			y = size.size.height - contextualMenuInWindowPosY + stringSize.height;
			x = contextualMenuInWindowPosX- stringSize.width;
		break;
				
		default:
		NSLog(@"Line option %d not valid",pos);
		return;
	}

	glColor4f (0.0f, 0.0f, 0.0f, 0.0f); //black
	glRasterPos3d (x+1, y+1, 0);
	i=-1;
	while (i++ < lstrLength) glCallList (fontListGL + lstr[i] - ' ');

	glColor4f (1.0f, 1.0f, 1.0f, 1.0f); //white
	glRasterPos3d (x, y, 0);
	i=-1;
	while (i++ < lstrLength) glCallList (fontListGL + lstr[i] - ' ');
}

#pragma mark Number and text accesor proxy for image ManagedObject


-(NSString *) patientSex
{
	//this field may be empty in the database
	if ( [[dcmFilesList objectAtIndex:[self indexForPix:curImage]] valueForKeyPath:@"series.study.patientSex"]) return [[dcmFilesList objectAtIndex:[self indexForPix:curImage]] valueForKeyPath:@"series.study.patientSex"];
	else return  @" ";
	return @"sexo";
}

@end



/*
DCMObject *dcmObject = [DCMObject objectWithContentsOfFile:srcFile decodingPixelData:NO];
 -(NSMutableArray*) dcmPixList;
 -(NSMutableArray*) dcmRoiList;
 -(NSArray*) dcmFilesList;
- (short) curImage;
- (DCMPix*)curDCM;
- (float)mouseXPos;
- (float)mouseYPos;
- (float) contextualMenuInWindowPosX;
- (float) contextualMenuInWindowPosY;
*/