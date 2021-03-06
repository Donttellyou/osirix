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

#import "ThreadsManager.h"
#import "ThreadModalForWindowController.h"
#import "NSThread+N2.h"

@implementation ThreadsManager

@synthesize threads = _threads;
@synthesize threadsController = _threadsController;

+(ThreadsManager*)defaultManager {
	static ThreadsManager* threadsManager = [[self alloc] init];
	return threadsManager;
}

-(id)init {
	self = [super init];
	
	_threads = [[NSMutableArray alloc] init];
	
	_threadsController = [[NSArrayController alloc] init];
	[_threadsController setSelectsInsertedObjects:NO];
	[_threadsController setAvoidsEmptySelection:NO];
	[_threadsController setObjectClass:[NSThread class]];
    [_threadsController bind:@"contentArray" toObject:self withKeyPath:@"threads" options:NULL];
	
	return self;
}

-(void)dealloc {
	[_threads release];
	[super dealloc];
}

#pragma mark Interface

-(NSUInteger)threadsCount {
	return [self countOfThreads];
}

-(NSThread*)threadAtIndex:(NSUInteger)index {
	return [self objectInThreadsAtIndex:index];
}

-(void)subAddThread:(NSThread*)thread
{
	@synchronized( thread)
	{
		if (![[NSThread currentThread] isMainThread])
			NSLog( @"***** NSThread we should NOT be here");
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(threadWillExit:) name:NSThreadWillExitNotification object:thread];
		[[self mutableArrayValueForKey:@"threads"] addObject:thread];
		
		if (![thread isMainThread] && ![thread isExecuting])
			[thread start]; // We need to start the thread NOW, to be sure, it happens AFTER the addObject
		
		[thread release]; // This is not a memory leak - See Below
	}
}

-(void)addThreadAndStart:(NSThread*)thread
{
	@synchronized( thread)
	{
		[thread retain]; // This is not a memory leak - release will happen in subAddThread:
		
		if (![[NSThread currentThread] isMainThread])
			[self performSelectorOnMainThread:@selector(subAddThread:) withObject:thread waitUntilDone: NO];
		
		else if (![_threads containsObject:thread])
			[self subAddThread:thread];
	}
}

-(void) subRemoveThread:(NSThread*)thread
{
	if (![[NSThread currentThread] isMainThread])
		NSLog( @"***** NSThread we should NOT be here");
	
	@synchronized( thread)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSThreadWillExitNotification object:thread];
		[[self mutableArrayValueForKey:@"threads"] removeObject:thread];
	}
	
	[thread release]; // This is not a memory leak - See Below
}

-(void)removeThread:(NSThread*)thread
{
	@synchronized( thread)
	{
		[thread retain]; // This is not a memory leak - release will happen in subRemoveThread:
		
		if (![[NSThread currentThread] isMainThread])
			[self performSelectorOnMainThread:@selector( subRemoveThread:) withObject:thread waitUntilDone:NO];
		else if ([_threads containsObject:thread])
			[self subRemoveThread: thread];
	}
}

-(void)threadWillExit:(NSNotification*)notification {
	[self removeThread:notification.object];
}

#pragma mark Core Data

-(NSUInteger)countOfThreads {
    return [_threads count];
}

-(id)objectInThreadsAtIndex:(NSUInteger)index {
    return [_threads objectAtIndex:index];
}

-(void)insertObject:(id)obj inThreadsAtIndex:(NSUInteger)index {
    [_threads insertObject:obj atIndex:index];
}

-(void)removeObjectFromThreadsAtIndex:(NSUInteger)index {
    [_threads removeObjectAtIndex:index];
}

-(void)replaceObjectInThreadsAtIndex:(NSUInteger)index withObject:(id)obj {
    [_threads replaceObjectAtIndex:index withObject:obj];
}

@end
