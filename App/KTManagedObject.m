//
//  KTManagedObject.m
//  KTComponents
//
//  Created by Terrence Talbot on 6/22/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTManagedObject.h"

#import "KTDocument.h"
#import "KTExtensiblePluginPropertiesArchivedObject.h"
#import "KTPersistentStoreCoordinator.h"

#import "NSArray+Karelia.h"
#import "NSDocumentController+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSObject+KTExtensions.h"

#import "Debug.h"


@implementation KTManagedObject

//- (void)awakeFromFetch
//{
//	TJT((@"awakeFromFetch:%@", [self managedObjectDescription]));
//	[super awakeFromFetch];
//}
//
//- (void)awakeFromInsert
//{
//	TJT((@"awakeFromInsert:%@", [self managedObjectDescription]));
//	[super awakeFromInsert];
//}
//
//- (void)didTurnIntoFault
//{
//	TJT((@"didTurnIntoFault:%@", [self managedObjectDescription]));
//	[super didTurnIntoFault];
//}
//
//- (void)dealloc
//{
//	TJT((@"dealloc:%@", [self managedObjectDescription]));
//	[super dealloc];
//}
//
//- (void)willSave
//{
//	TJT((@"willSave:%@", [self managedObjectDescription]));
//	[super willSave];
//}
//
//- (void)didSave
//{
//	TJT((@"didSave:%@", [self managedObjectDescription]));
//	[super didSave];
//}
//
//- (id)retain
//{
//	TJT((@"retain:%@", [self managedObjectDescription]));
//	return [super retain];
//}
//
//- (oneway void)release
//{
//	TJT((@"release:%@", [self managedObjectDescription]));
//	[super release];
//}
//
//- (id)autorelease
//{
//	TJT((@"autorelease:%@", [self managedObjectDescription]));
//	return [super autorelease];
//}

//- (id)initWithEntity:(NSEntityDescription*)entity insertIntoManagedObjectContext:(NSManagedObjectContext*)context
//{
//	id result = [super initWithEntity:entity insertIntoManagedObjectContext:context];
//	
//	if ( nil != result )
//	{
//		if ( [NSThread isMainThread] )
//		{
//			LOG((@"creating new instance of %@ in main thread", [self className]));
//		}
//		else
//		{
//			LOG((@"creating new instance of %@ in thread %X", [self className], [NSThread currentThread]));
//		}
//	}
//	
//	return result;
//}
		
/*! returns predicate to find an object in a different context considered "equal"
	in attribute value(s).
*/
- (NSPredicate *)predicateForSimilarObject 
{
	[self subclassResponsibility:_cmd];
	return nil;
}

/*! returns first matching object in aContext using predicateForSimilarObject */
- (KTManagedObject *)similarObjectInContext:(KTManagedObjectContext *)aContext 
{
    // attempt to find a matching object using the built-in predicate
    KTManagedObject *result = nil;
	
	// perform the query
	NSError *fetchError = nil;
	NSArray *fetchedObjects = [aContext objectsWithEntityName:[[self entity] name]
													predicate:[self predicateForSimilarObject]
														error:&fetchError];
	    
    // extract result
    if ( (nil != fetchedObjects) && ([fetchedObjects count] > 0) ) 
	{
        result = [fetchedObjects objectAtIndex:0];
    }
	
    return result;
}

#pragma mark -
#pragma mark Plugin Properties

/*	These 2 methods allow us to store and retrieve managed object even though they dont't conform to <NSCoding>
 *	Instead though they must conform to the KTArchivableManagedObject protocol
 */
- (NSDictionary *)unarchiveExtensibleProperties:(NSData *)propertiesData
{
	NSDictionary *result = [super unarchiveExtensibleProperties:propertiesData];
	
	// Go through all dictionary entries and swap any KTArchivedManagedObjects for the real thing
	NSEnumerator *keysEnumerator= [[NSDictionary dictionaryWithDictionary:result] keyEnumerator];
	NSString *aKey;
	while (aKey = [keysEnumerator nextObject])
	{
		id anObject = [result objectForKey:aKey];
		if ([anObject isKindOfClass:[KTExtensiblePluginPropertiesArchivedObject class]])
		{
			KTExtensiblePluginPropertiesArchivedObject *archivedObject = (KTExtensiblePluginPropertiesArchivedObject *)anObject;
			
			KTPersistentStoreCoordinator *PSC = (id)[[self managedObjectContext] persistentStoreCoordinator];
			if([PSC isKindOfClass:[KTPersistentStoreCoordinator class]])
			{
				KTDocument *document = [PSC document];
				NSManagedObject *realObject = [archivedObject realObjectInDocument:document];
				[result setValue:realObject forKey:aKey];
			}
		}
	}
	
	return result;
}

- (NSData *)archiveExtensibleProperties:(NSDictionary *)properties
{
	// Replace any managed objects conforming to KTArchivableManagedObject with KTArchivedManagedObject
	NSMutableDictionary *correctedProperties = [NSMutableDictionary dictionaryWithDictionary:properties];
	NSEnumerator *keysEnumerator = [properties keyEnumerator];
	NSString *aKey;
	
	while (aKey = [keysEnumerator nextObject])
	{
		id anObject = [properties objectForKey:aKey];
		if ([anObject isKindOfClass:[NSManagedObject class]] &&
			[anObject conformsToProtocol:@protocol(KTExtensiblePluginPropertiesArchiving)])
		{
			KTExtensiblePluginPropertiesArchivedObject *archivedObject =
			[[[KTExtensiblePluginPropertiesArchivedObject alloc] initWithObject:anObject] autorelease];
			
			[correctedProperties setValue:archivedObject forKey:aKey];
		}
	}
	
	NSData *result = [super archiveExtensibleProperties:correctedProperties];
	return result;
}


@end
