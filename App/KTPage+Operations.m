//
//  KTPage+Operations.m
//  KTComponents
//
//  Created by Dan Wood on 8/9/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTPage.h"

#import "Debug.h"
#import "KTAbstractIndex.h"
#import "KTDocument.h"
#import "NSSet+KTExtensions.h"


@interface NSObject ( RichTextElementDelegateHack )
- (NSString *)richTextHTML;
@end


@interface NSObject ( HTMLElementDelegateHack )
- (NSString *)html;
@end


@implementation KTPage ( Operations )

#pragma mark -
#pragma mark Perform Selector

/*	Add to the default behavior by respecting the recursive flag
 */
- (void)makeSelfOrDelegatePerformSelector:(SEL)selector
							   withObject:(void *)anObject
								 withPage:(KTPage *)page
								recursive:(BOOL)recursive
{
	[super makeSelfOrDelegatePerformSelector:selector withObject:anObject withPage:page recursive:recursive];
	
	if (recursive)
	{
		NSEnumerator *childrenEnumerator = [[self children] objectEnumerator];
		KTPage *aPage;
		while (aPage = [childrenEnumerator nextObject])
		{
			[aPage makeSelfOrDelegatePerformSelector:selector withObject:anObject withPage:page recursive:recursive];
		}
	}
}

/*	Perform the selector on our components (pagelets, index if present). Then allow
 *	-makeSelfOrDelegatePerformSelector: to take over.
 */
- (void)makeComponentsPerformSelector:(SEL)selector
						   withObject:(void *)anObject
							 withPage:(KTPage *)page
							recursive:(BOOL)recursive
{
	// Bail early if we've been deleted
	if ([self isDeleted])
	{
		return;
	}
	
	
	// Pagelets
	NSEnumerator *pageletsEnumerator = [[self pagelets] objectEnumerator];
	KTPagelet *aPagelet;
	while (aPagelet = [pageletsEnumerator nextObject])
	{
		[aPagelet makeSelfOrDelegatePerformSelector:selector withObject:anObject withPage:page recursive:NO];
	}
	
	
	// Index - if we have no index, this call is to nil, so does nothing
	KTAbstractIndex *index = [self index];
	[index makeComponentsPerformSelector:selector withObject:anObject withPage:page];
	
	
	// Self/delegate, and then children
	[self makeSelfOrDelegatePerformSelector:selector withObject:anObject withPage:page recursive:recursive];
}

// Called via recursiveComponentPerformSelector
// Kind of inefficient since we're just looking to see if there are ANY RSS collections

- (void)addRSSCollectionsToArray:(NSMutableArray *)anArray forPage:(KTPage *)aPage
{
	BOOL rss = ([self collectionCanSyndicate] && [self boolForKey:@"collectionSyndicate"]);
	if (rss)
	{
		[anArray addObject:self];
	}
}

- (void)addDesignsToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage
{
	NSString *pageDesign = [self wrappedValueForKey:@"designBundleIdentifier"];		// NOT inherited
	if (nil != pageDesign)
	{
		//LOG((@"%@ adding design:%@", [self class], pageDesign));
		[aSet addObject:pageDesign];
	}
}

// Called via recursiveComponentPerformSelector
- (void)addStaleToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage
{
	if ([self boolForKey:@"isStale"])
	{
		LOG((@"adding to stale set: %@", [self titleText]));
		[aSet addObject:self];
	}
}

#pragma mark -
#pragma mark Other Recursive Methods

/*! We set these as kStaleFamily as we only call these with the recursive methods
	to propagate the staleness
 */

// Called via recursivePerformSelector
- (void)setStaleIfInheritsSidebar:(id)ignored forPage:(KTPage *)aPage
{
	if ([self boolForKey:@"includeInheritedSidebar"] == YES && 
		[[self primitiveValueForKey:@"staleness"] intValue] != kStalePage)
	{
		////LOG((@"~~~~~~~~~ %@ ....%@", NSStringFromSelector(_cmd), [self titleText]));
		//[self markStale:kStaleFamily];
	}
}

// Called via recursivePerformSelector
- (void)setStaleIfIncludedInIndex:(id)ignored forPage:(KTPage *)aPage
{
	if ([self includeInIndexAndPublish] == YES && 
		[[[self parentOrRoot] primitiveValueForKey:@"staleness"] intValue] != kStalePage)
	{
		////LOG((@"~~~~~~~~~ %@ ....%@", NSStringFromSelector(_cmd), [self titleText]));
		//[[self parentOrRoot] markStale:kStaleFamily];
	}
}

// Called via recursivePerformSelector

- (void)addToStringIfStale:(NSMutableString *)str forPage:(KTPage *)aPage
{
	//int state = [self boolForKey:@"staleness"];
	int state = [[self primitiveValueForKey:@"staleness"] intValue];
	if (state != kNotStale)
		[str appendFormat:@"%@ - %@ (%@)\r\n", NSStringFromClass([self class]), [self titleText], (state == kStalePage) ? @"On" : @"Mixed"];
}

#pragma mark -
#pragma mark Spotlight

- (NSString *)spotlightHTML
{
	NSMutableString *result = [NSMutableString stringWithString:[super spotlightHTML]];
	
	// Add spotlightHTML of any pagelets owned by this page	
	NSEnumerator *e = [[self pagelets] objectEnumerator];
	KTPagelet *pagelet;
	while ( pagelet = [e nextObject] )
	{
		NSString *pageletHTML = [pagelet spotlightHTML];
		if ( (nil != pageletHTML) && ![pageletHTML isEqualToString:@""] )
		{
			[result appendFormat:@" %@", pageletHTML];
		}
	}
	
	if ( nil == result )
	{
		result = @"";
	}
	
	return result;
}

@end
