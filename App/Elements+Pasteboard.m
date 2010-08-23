//
//  Elements+Pasteboard.m
//  Marvel
//
//  Created by Mike on 06/09/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "Elements+Pasteboard.h"
#import "KTPage+Paths.h"

#import "BDAlias.h"
#import "KTPasteboardArchiving.h"

#import "NSEntityDescription+KTExtensions.h"
#import "NSObject+Karelia.h"


@interface KTPluginIDPasteboardRepresentation : NSObject <NSCoding>
{
	NSString *myPluginID;
	NSString *myPluginEntity;
}

- (id)initWithPlugin:(id)plugin;

- (NSString *)pluginID;
- (NSString *)pluginEntity;

@end


@implementation KTPluginIDPasteboardRepresentation

- (id)initWithPlugin:(KTPage *)plugin
{
	[super init];
	
	myPluginID = [[plugin uniqueID] copy];
	myPluginEntity = [[[plugin entity] name] copy];
	
	return self;
}

- (void)dealloc
{
	[myPluginID release];
	[myPluginEntity release];
	
	[super dealloc];
}

- (NSString *)pluginID { return myPluginID; }

- (NSString *)pluginEntity { return myPluginEntity; }

- (id)initWithCoder:(NSCoder *)decoder
{
	id result = [super init];
	
	myPluginID = [[decoder decodeObjectForKey:@"ID"] copy];
	myPluginEntity = [[decoder decodeObjectForKey:@"entity"] copy];
	
	return result;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:[self pluginID] forKey:@"ID"];
	[encoder encodeObject:[self pluginEntity] forKey:@"entity"];
}

@end


#pragma mark -


@interface KTPage ()
+ (KTPage *)_insertNewPageWithParent:(KTPage *)parent pluginIdentifier:(NSString *)pluginIdentifier;
@end


@implementation KTPage (Pasteboard)

/*	There are several relationships we don't want archived
 */
+ (NSSet *)keysToIgnoreForPasteboardRepresentation
{
	static NSSet *sIgnoredKeys;
	
	if (!sIgnoredKeys)
	{
		NSMutableSet *result = [NSMutableSet setWithSet:[NSSet set]];//[super keysToIgnoreForPasteboardRepresentation]];
		
		NSSet *myIgnoredKeys = [NSSet setWithObjects:
                                @"master",
                                @"rootDocumentInfo",
                                @"parentPage", @"archivePages",
                                @"childIndex",
                                @"plugins",
                                @"site",
                                @"thumbnailMediaIdentifier", @"customSiteOutlineIconIdentifier",
                                @"isStale",
                                @"datePublished", nil];
		
        [result unionSet:myIgnoredKeys];
		sIgnoredKeys = [result copy];
	}
	
	return sIgnoredKeys;
}

+ (KTPage *)pageWithPasteboardRepresentation:(NSDictionary *)archive parent:(KTPage *)parent
{
	OBPRECONDITION(archive && [archive isKindOfClass:[NSDictionary class]]);
	OBPRECONDITION(parent);
	
	
	// Create a basic page
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:archive];
	KTPage *result = [self _insertNewPageWithParent:parent
								   pluginIdentifier:[archive objectForKey:@"pluginIdentifier"]];
	[attributes removeObjectForKey:@"pluginIdentifier"];
	
	
	// Set up the children
	NSMutableSet *children = [result mutableSetValueForKey:@"childItems"];
	NSEnumerator *pagesEnumerator = [[archive objectForKey:@"childItems"] objectEnumerator];
	NSDictionary *anArchivedPage;
	while (anArchivedPage = [pagesEnumerator nextObject])
	{
		KTPage *page = [KTPage pageWithPasteboardRepresentation:anArchivedPage parent:result];
        OBASSERT(page);
		[children addObject:page];
	}
	
	
	// Prune away any properties no longer needing to be set
	NSArray *relationships = [[[result entity] relationshipsByName] allKeys];
	[attributes removeObjectsForKeys:relationships];
	[attributes removeObjectsForKeys:[[self keysToIgnoreForPasteboardRepresentation] allObjects]];
	[attributes removeObjectForKey:@"fileName"];	// Handled below
	
	
	// Convert Media and PluginIdentifiers back into real objects
	NSEnumerator *attributesEnumerator = [[NSDictionary dictionaryWithDictionary:attributes] keyEnumerator];
	id aKey;
	while (aKey = [attributesEnumerator nextObject])
	{
		id anObject = [attributes objectForKey:aKey];
		
		if ([anObject isKindOfClass:[KTPluginIDPasteboardRepresentation class]])
		{
			// TODO: Properly handle plugin IDs
			[attributes removeObjectForKey:aKey];
		}
	}
	
	
	// Set the attributes. MUST set all values or some non-optional properties may be ignored. BUGSID:28711
	[result setValuesForKeysWithDictionary:attributes setAllValues:YES];
    
	
	// Give the page a decent filename
	NSString *suggestedFileName = [result suggestedFileName];
	[result setFileName:suggestedFileName];
	
	
	return result;
}

/*	We return a dictionary of our properties. However, media and page objects stored weakly by their
 *  ID must be converted to special NSCoder-compatible types.
 */
- (id <NSCoding>)pasteboardRepresentation
{
	// Start with our extensible properties
	NSDictionary *extensibleProperties = [self extensibleProperties];
	NSMutableDictionary *buffer = [NSMutableDictionary dictionaryWithDictionary:extensibleProperties];
	
	
	// Convert any pages into their id-only representation
	NSEnumerator *keysEnumerator = [extensibleProperties keyEnumerator];
	id aKey;
	while (aKey = [keysEnumerator nextObject])
	{
		id anObject = [buffer objectForKey:aKey];
		if (![anObject conformsToProtocol:@protocol(NSCoding)])
		{
			id <NSCoding> pasteboardRep = [anObject IDOnlyPasteboardRepresentation];
			[buffer setValue:pasteboardRep forKey:aKey];    // pasteboardRep may be nil for some media containers
		}
	}
	
	
	// Add in all attributes and keys from the model. Ignore transient properties.
	NSArray *propertyKeys = [[[self entity] propertiesByNameOfClass:[NSPropertyDescription class]
										 includeTransientProperties:NO] allKeys];
	NSDictionary *properties = [self dictionaryWithValuesForKeys:propertyKeys];
	[buffer addEntriesFromDictionary:properties];
	
	
	// Special case: pages need their thumbnails copied
	if ([self isKindOfClass:[KTPage class]])
	{
		[buffer setValue:[(KTPage *)self thumbnail] forKey:@"thumbnail"];
	}
	
	
	// Ignore keys we don't want archived
	NSSet *ignoredKeys = [[self class] keysToIgnoreForPasteboardRepresentation];
	[buffer removeObjectsForKeys:[ignoredKeys allObjects]];
	
	
	// Turn any managed objects into their pasteboard representation
	keysEnumerator = [[NSDictionary dictionaryWithDictionary:buffer] keyEnumerator];
	while (aKey = [keysEnumerator nextObject])
	{
		id anObject = [buffer objectForKey:aKey];
		
		BOOL objectIsNSCodingCompliant = [anObject conformsToProtocol:@protocol(NSCoding)];
		if ([anObject isKindOfClass:[NSSet class]] && ![[anObject anyObject] conformsToProtocol:@protocol(NSCoding)])
		{
			objectIsNSCodingCompliant = NO;
		}
		
		if (!objectIsNSCodingCompliant)
		{
			id <NSCoding> pasteboardRepObject = [anObject valueForKey:@"pasteboardRepresentation"];
            [buffer setValue:pasteboardRepObject forKey:aKey];
		}
	}
	
	
	return [NSDictionary dictionaryWithDictionary:buffer];
}

- (id <NSCoding>)IDOnlyPasteboardRepresentation
{
	id <NSCoding> result = [[[KTPluginIDPasteboardRepresentation alloc] initWithPlugin:self] autorelease];
	return result;
}

@end
