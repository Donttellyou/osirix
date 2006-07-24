//
//  Notification.m
//  RemoteDistributedNotificationCenter
//
//  Created by Arnaud Garcia on 19.10.05.
//

#import "Observer.h"


@implementation Observer
-(id)initWithObserver:(id)obs andSelector:(SEL)sel forNotificationName:(NSString*)name withSoftID:(NSString*)aSoftID
{
	if ((self = [super init])) {
		[self setAnObserver:obs];
		[self setSelector:sel];
		[self setNotificationName:name];
		[self SetSoftID:aSoftID];
	}
	return self;
}

-(id)init
{
	self=[super init];
	return self;
}
// anObserver
-(id)anObserver
{
	return anObserver;
}
-(void)setAnObserver:(id)obs
{
	[obs retain];
	anObserver=obs;
}

//notificationName
-(NSString*)notificationName
{
	return notificationName;
}
-(void)setNotificationName:(NSString*)name
{
	[notificationName release];
	notificationName=[[NSString alloc] initWithString: name];
}

// softID
-(NSString*)softID;
{
	return softID;
}

-(void)SetSoftID:(NSString*)aSoftID
{
	[softID release];
	softID=[[NSString alloc] initWithString:aSoftID];
}

//Selector
- (SEL)selector
{
	return NSSelectorFromString(aSelectorString);
}

- (void)setSelector:(SEL)selector
{
	[aSelectorString release];
	aSelectorString=[[NSString alloc] initWithString:NSStringFromSelector(selector)];
	
}

- (void) encodeWithCoder: (NSCoder *)coder
{

	[coder encodeObject:aSelectorString];
	[coder encodeObject:notificationName];
	[coder encodeObject:softID];

}

- initWithCoder: (NSCoder *)coder
{
	[super init];
	//TODO v�rifier si l'ordre doit �tre invers� ?
	aSelectorString=[[coder decodeObject] retain];
	notificationName=[[coder decodeObject] retain];
	softID=[[coder decodeObject] retain];
	//anObject=[[coder decodeObject] retain];
	return self;
}
-(void)dealloc
{
	[aSelectorString release];
	[anObserver release];
	[notificationName release];
	[super dealloc];
}
@end
