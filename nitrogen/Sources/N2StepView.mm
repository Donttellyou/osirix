//
//  StepView.m
//  Nitrogen Framework
//
//  Created by Joris Heuberger on 30/03/07.
//  Copyright 2007-2009 OsiriX Team. All rights reserved.
//

#import <Nitrogen/N2StepView.h>
#import <Nitrogen/N2Step.h>

@implementation N2StepView
@synthesize step = _step;

-(id)initWithStep:(N2Step*)step {
	self = [super initWithTitle:[step title] content:[step enclosedView]];
	
	_step = [step retain];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stepDidBecomeActiveInactive:) name:N2StepDidBecomeActiveNotification object:step];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stepDidBecomeActiveInactive:) name:N2StepDidBecomeInactiveNotification object:step];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stepDidBecomeEnabledDisabled:) name:N2StepDidBecomeEnabledNotification object:step];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stepDidBecomeEnabledDisabled:) name:N2StepDidBecomeDisabledNotification object:step];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stepTitleDidChange:) name:N2StepTitleDidChangeNotification object:step];
	
	return self;
}

-(void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_step release];
	[super dealloc];
}

-(void)stepDidBecomeActiveInactive:(NSNotification*)notification {
	if ([[notification name] isEqualToString:N2StepDidBecomeActiveNotification])
		[self expand:self];
	else if (![_step shouldStayVisibleWhenInactive]) [self collapse:self];
}

-(void)stepDidBecomeEnabledDisabled:(NSNotification*)notification {
	[self setEnabled:[[notification name] isEqualToString:N2StepDidBecomeEnabledNotification]];
}

-(void)stepTitleDidChange:(NSNotification*)notification {
	[self setTitle:[_step title]];
}

@end
