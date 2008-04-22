//
//  KTPagelet.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "KTPagelet.h"

#import "Debug.h"
#import "KT.h"
#import "KTAppDelegate.h"
#import "KTDocument.h"
#import "KTElementPlugin.h"
#import "KTHTMLParser.h"
#import "KTManagedObject.h"
#import "KTPage.h"
#import "KTStoredDictionary.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"

#ifdef APP_RELEASE
#import "Registration.h"
#endif


@interface KTPagelet (Private)
+ (KTPagelet *)_insertNewPageletWithPage:(KTPage *)page pluginIdentifier:(NSString *)identifier location:(KTPageletLocation)location;
- (NSSet *)allPagesThatInheritSidebarsFromPage:(KTPage *)page;
@end


@implementation KTPagelet

#pragma mark -
#pragma mark Initialization

+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[KTPagelet setKeys:[NSArray arrayWithObjects: @"ordering", @"location", @"prefersBottom", nil]
		triggerChangeNotificationsForDependentKey: @"canMoveUp"];
	
	[KTPagelet setKeys:[NSArray arrayWithObjects: @"ordering", @",location", @"prefersBottom", nil]
		triggerChangeNotificationsForDependentKey: @"canMoveDown"];
	
	[pool release];
}

/*	Creates a fresh pagelet for the chosen page
 */
+ (KTPagelet *)pageletWithPage:(KTPage *)page plugin:(KTElementPlugin *)plugin;
{	
	NSParameterAssert(page);	NSParameterAssert(plugin);
	
	
	KTPageletLocation location = ([page includeSidebar]) ? KTSidebarPageletLocation : KTCalloutPageletLocation;
	
	KTPagelet *result = [self _insertNewPageletWithPage:page
									   pluginIdentifier:[[plugin bundle] bundleIdentifier]
											   location:location];
	
	// Tell the pagelet to awake
	[result awakeFromBundleAsNewlyCreatedObject:YES];
	
	
	return result;
}

/*	Private support method that creates a basic pagelet.
 */
+ (KTPagelet *)_insertNewPageletWithPage:(KTPage *)page pluginIdentifier:(NSString *)identifier location:(KTPageletLocation)location
{
	NSParameterAssert([page managedObjectContext]);		NSParameterAssert(identifier);
	
	
	// Create the pagelet
	KTPagelet *result = [NSEntityDescription insertNewObjectForEntityForName:@"Pagelet"
													  inManagedObjectContext:[page managedObjectContext]];
	OBASSERT(result);
	
	
	// Seup the pagelet's properties
	[result setValue:identifier forKey:@"pluginIdentifier"];
	[result setLocation:location];
	
	[page addPagelet:result];
	
	return result;
}

+ (KTPagelet *)pageletWithPage:(KTPage *)aPage dataSourceDictionary:(NSDictionary *)aDictionary
{
	KTElementPlugin *plugin = [aDictionary objectForKey:kKTDataSourcePlugin];
	
	KTPagelet *pagelet = [self pageletWithPage:aPage plugin:plugin];
	[pagelet awakeFromDragWithDictionary:aDictionary];
	
	return pagelet;
}

#pragma mark -
#pragma mark Awake

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject
{
	// First set fallback title, but then we'll let below override it
	if ( isNewlyCreatedObject )
	{
		NSString *titleText = [[self plugin] pluginPropertyForKey:@"KTPageletUntitledName"];
		[self setTitleHTML:titleText];		// really we just have text, but the prop is HTML
		
		[self setShowBorder:NO];	// new pagelets now DON'T show border initially, let people turn it on.
	}
	
	[super awakeFromBundleAsNewlyCreatedObject:isNewlyCreatedObject];
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary
{
	[super awakeFromDragWithDictionary:aDictionary];

    NSString *title = [aDictionary valueForKey:kKTDataSourceTitle];
    if ( nil == title )
	{
		// No title specified; use file name (minus extension)
		NSFileManager *fm = [NSFileManager defaultManager];
		title = [[fm displayNameAtPath:[aDictionary valueForKey:kKTDataSourceFileName]] stringByDeletingPathExtension];
	}
	if (nil != title)
	{
		[self setValue:[title escapedEntities] forKey:@"titleHTML"];
	}
}

#pragma mark -
#pragma mark Basic accessors

- (int)ordering { return [self wrappedIntegerForKey:@"ordering"]; }

- (void)setOrdering:(int)ordering
{
	// Since our ordering has changed, send the appropriate willChange/didChange notifications on our parent page
	NSSet *changedPages = [self allPages];
	
	[changedPages makeObjectsPerformSelector:@selector(willChangeValueForKey:) withObject:@"allSidebars"];
	[self setWrappedInteger:ordering forKey:@"ordering"];
	[changedPages makeObjectsPerformSelector:@selector(didChangeValueForKey:) withObject:@"allSidebars"];
}

- (NSString *)introductionHTML 
{
	NSString *result = [self wrappedValueForKey:@"introductionHTML"];
	if (!result)
	{
		result = @"";
	}
	
	return result;
}

- (void)setIntroductionHTML:(NSString *)value {	[self setWrappedValue:value forKey:@"introductionHTML"]; }

- (NSString *)cssClassName { return [[self plugin] pageletCSSClassName]; }

- (BOOL)showBorder { return [self wrappedBoolForKey:@"showBorder"]; }

- (void)setShowBorder:(BOOL)flag { [self setWrappedBool:flag forKey:@"showBorder"]; }

- (NSString *)titleHTML { return [self wrappedValueForKey:@"titleHTML"]; }

/*	used in bindings from page templates...		*/
- (NSString *)titleText { return [[self titleHTML] flattenHTML]; }

- (void)setTitleHTML:(NSString *)value { [self setWrappedValue:value forKey:@"titleHTML"]; }

- (NSString *)titleLinkURLPath { return [self wrappedValueForKey:@"titleLinkURLPath"]; }

- (void)setTitleLinkURLPath:(NSString *)aTitleLinkURLPath {	[self setWrappedValue:aTitleLinkURLPath forKey:@"titleLinkURLPath"]; }

/*!	Pass on messages to set modification data of a pagelet to its containing page, who really cares
 */
- (void)setLastModificationDate:(NSCalendarDate *)value 
{
	[[self page] setWrappedValue:value forKey:@"lastModificationDate"];
}

#pragma mark -
#pragma mark Page

- (KTPage *)root 
{
	return [[self page] root];
}

- (KTPage *)page { return [self wrappedValueForKey:@"page"]; }

/*	Sidebar pagelets put in an appearence on many pages. This returns a list of all those pages.
 *	Obviously for a callout, it just contains the one page.
 */
- (NSSet *)allPages
{
	NSSet *result = nil;
	
	if ([self location] == KTCalloutPageletLocation || ![self boolForKey:@"shouldPropagate"])
	{
		result = [NSSet setWithObject:[self page]];
	}
	else
	{
		KTPage *mainPage = [self page];
		NSMutableSet *pages = [[NSMutableSet alloc] initWithObjects:mainPage, nil];
		[pages unionSet:[self allPagesThatInheritSidebarsFromPage:mainPage]];
		
		result = [NSSet setWithSet:pages];
		[pages release];
	}
	
	return result;
}

/*	Support method for -allPages
 */
- (NSSet *)allPagesThatInheritSidebarsFromPage:(KTPage *)page
{
	NSMutableSet *result = [NSMutableSet set];
	
	NSEnumerator *childPages = [[page children] objectEnumerator];
	KTPage *aPage;
	
	while (aPage = [childPages nextObject])
	{
		if ([aPage includeSidebar] && [aPage boolForKey:@"includeInheritedSidebar"])
		{
			[result addObject:aPage];
			[result unionSet:[self allPagesThatInheritSidebarsFromPage:aPage]];
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark Location

/*	The pagelet location as stored in the DB. Does NOT distinguish between top and bottom sidebars.
 */
- (KTPageletLocation)location { return [self wrappedIntegerForKey:@"location"]; }

/*	The pagelet location as stored in the database. DOES distinguish between top and bottom sidebars.
 */
- (KTPageletLocation)locationByDifferentiatingTopAndBottomSidebars
{
	KTPageletLocation result = [self location];
	
	if (result == KTSidebarPageletLocation)
	{
		if ([self prefersBottom]) {
			result = KTBottomSidebarPageletLocation;
		}
		else {
			result = KTTopSidebarPageletLocation;
		}
	}
	
	return result;
}

/*	Returns the key of our parent page that matches our location.
 *	e.g. @"orderedTopSidebars" for KTTopSidebarPageletLocation
 */
- (NSString *)locationPageKey
{
	NSString *result = nil;
	
	switch ([self locationByDifferentiatingTopAndBottomSidebars])
	{
		case KTTopSidebarPageletLocation:
			result = @"orderedTopSidebars";
			break;
		case KTBottomSidebarPageletLocation:
			result = @"orderedBottomSidebars";
			break;
		case KTCalloutPageletLocation:
			result = @"orderedCallouts";
			break;
		default:
			OBASSERT_NOT_REACHED("It should be impossible to place a pagelet genericly in the sidebar");
			break;
	}
	
	OBPOSTCONDITION(result);
	
	return result;
}

/*	If you try to set the location to be a top or bottom sidebar, an exception is raised
 */
- (void)setLocation:(KTPageletLocation)location
{
	// Ensure no-one tries to set a top or bottom sidebar location
	BOOL isTopOrBottomLocation = (location == KTTopSidebarPageletLocation || location == KTBottomSidebarPageletLocation);
	NSAssert(!isTopOrBottomLocation, @"Can't directly set the location of a pagelet to top or bottom sidebar; use -setPrefersBottom: instead");
	
	// Store the value
	[self willChangeValueForKey:@"location"];
	[self setPrimitiveValue:[NSNumber numberWithInt:location] forKey:@"location"];
	
	// Since we are potentially inserting the pagelet in an array, the orderings must be updated to avoid conflicts
	[KTPage updatePageletOrderingsFromArray:[self pageletsInSameLocation]];
	
	[self didChangeValueForKey:@"location"];
}

- (BOOL)prefersBottom {	return [self wrappedBoolForKey:@"prefersBottom"]; }

- (void)setPrefersBottom:(BOOL)prefersBottom
{
	[self willChangeValueForKey:@"prefersBottom"];
	[self setPrimitiveValue:[NSNumber numberWithBool:prefersBottom] forKey:@"prefersBottom"];
	
	// Since we are potentially inserting the pagelet in an array, the orderings must be updated to avoid conflicts
	[KTPage updatePageletOrderingsFromArray:[self pageletsInSameLocation]];
	
	[self didChangeValueForKey:@"prefersBottom"];
}

- (BOOL)canMoveUp
{
	unsigned index = [[self pageletsInSameLocation] indexOfObject:self];
	BOOL result = (index != 0 && index != NSNotFound);
	return result;
}

- (BOOL)canMoveDown
{
	NSArray *pageletsInSameLocation = [self pageletsInSameLocation];
	BOOL result = ![[pageletsInSameLocation lastObject] isEqual:self];
	return result;
}

/*	Swaps the pagelet with the one above it
 */
- (void)moveUp
{
	NSMutableArray *fellowPagelets = [[NSMutableArray alloc] initWithArray:[self pageletsInSameLocation]];
	unsigned index = [fellowPagelets indexOfObjectIdenticalTo:self];
	[fellowPagelets exchangeObjectAtIndex:index withObjectAtIndex:index - 1];
	[KTPage updatePageletOrderingsFromArray:fellowPagelets];
	
	// Tidy up
	[fellowPagelets release];
}

/*	Swaps the pagelet with the one below it
 */
- (void)moveDown
{
	NSMutableArray *fellowPagelets = [[NSMutableArray alloc] initWithArray:[self pageletsInSameLocation]];
	unsigned index = [fellowPagelets indexOfObjectIdenticalTo:self];
	[fellowPagelets exchangeObjectAtIndex:index withObjectAtIndex:index + 1];
	[KTPage updatePageletOrderingsFromArray:fellowPagelets];
	
	// Tidy up
	[fellowPagelets release];
}

/*	A shortcut to the methods in KTPage for getting all the pagelets in the same location as us
 */
- (NSArray *)pageletsInSameLocation
{
	NSArray *result = [[self page] pageletsInLocation:[self locationByDifferentiatingTopAndBottomSidebars]];
	return result;
}

#pragma mark -
#pragma mark KTWebViewComponent protocol

/*	Add to the default list of components: pagelets (and their components), index (if it exists)
 */
- (NSString *)uniqueWebViewID
{
	NSString *result = [NSString stringWithFormat:@"ktpagelet-%@", [self uniqueID]];
	return result;
}

#pragma mark -
#pragma mark Support

// More human-readable description
- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"%@ <%p> : %@ %@ %@", [self class], self,
		[self titleHTML], [self wrappedValueForKey:@"uniqueID"], [self wrappedValueForKey:@"pluginIdentifier"]];
}

- (BOOL)canHaveTitle
{
	return [[[self plugin] pluginPropertyForKey:@"KTPageletCanHaveTitle"] boolValue];
}

@end
