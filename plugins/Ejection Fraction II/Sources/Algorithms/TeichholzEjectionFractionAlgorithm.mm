//
//  TeichholzEjectionFractionAlgorithm.m
//  Ejection Fraction II
//
//  Created by Alessandro Volz on 05.11.09.
//  Copyright 2009 OsiriX Team. All rights reserved.
//

#import "TeichholzEjectionFractionAlgorithm.h"
#import "EjectionFractionWorkflow.h"
#import <OsiriX Headers/ROI.h>

@implementation TeichholzEjectionFractionAlgorithm

-(NSString*)description {
	return @"Teichholz";
}

-(NSArray*)groupedRoiIds {
	return [NSArray arrayWithObjects: [NSArray arrayWithObject:DiasLength], [NSArray arrayWithObject:SystLength], NULL];
}

-(CGFloat)volumeWithLength:(CGFloat)length {
	return powf(length, 3) * 7 / (length + 2.4);
}

-(CGFloat)compute:(NSDictionary*)rois {
	return [self ejectionFractionWithDiastoleVolume:[self volumeWithLength:[[rois objectForKey:DiasLength] MesureLength:NULL]]
									  systoleVolume:[self volumeWithLength:[[rois objectForKey:SystLength] MesureLength:NULL]]];
}

@end
