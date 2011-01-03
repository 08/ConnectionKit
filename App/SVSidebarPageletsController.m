//
//  SVSidebarPageletsController.m
//  Sandvox
//
//  Created by Mike on 08/01/2010.
//  Copyright 2010-11 Karelia Software. All rights reserved.
//

#import "SVSidebarPageletsController.h"

#import "KTPage.h"
#import "SVSidebar.h"

#import "NSSortDescriptor+Karelia.h"


@interface SVSidebarPageletsController ()
+ (void)_addPagelet:(SVGraphic *)pagelet toSidebarOfDescendantsOfPageIfApplicable:(KTPage *)page;
@end


#pragma mark -


@implementation SVSidebarPageletsController

#pragma mark Init & Dealloc

- (id)initWithSidebar:(SVSidebar *)sidebar;
{
    self = [self init];
    _sidebar = [sidebar retain];
    
    [self setObjectClass:[SVGraphic class]];
    [self setManagedObjectContext:[sidebar managedObjectContext]];
    [self setEntityName:@"Graphic"];
    [self setAvoidsEmptySelection:NO];
    [self setAutomaticallyRearrangesObjects:YES];
    [self didChangeArrangementCriteria];
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES],
                             NSRaisesForNotApplicableKeysBindingOption,
                             nil];
    [self bind:NSContentSetBinding toObject:sidebar withKeyPath:@"pagelets" options:options];
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    [self didChangeArrangementCriteria];
    return self;
}

- (void)dealloc
{
    [_sidebar release];
    
    [super dealloc];
}

#pragma mark Arranging Objects

- (NSArray *)arrangeObjects:(NSArray *)objects;
{
    // Pre-sort by standard pagelet sort descriptors
    objects = [objects sortedArrayUsingDescriptors:[[self class] pageletSortDescriptors]];
    return [super arrangeObjects:objects];
}

- (NSArray *)allSidebarPagelets;
{
    //  Fetches all sidebar pagelets in the receiver's MOC and sorts them.
    
    
    NSManagedObjectContext *context = [self managedObjectContext];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"Graphic"
                                   inManagedObjectContext:context]];
    [request setSortDescriptors:[[self class] pageletSortDescriptors]];
    
    NSArray *result = [context executeFetchRequest:request error:NULL];
    
    // Tidy up
    [request release];
    return result;
}

+ (NSArray *)pageletSortDescriptors;
{
    static NSArray *result;
    if (!result)
    {
        result = [NSSortDescriptor sortDescriptorArrayWithKey:@"sortKey"
                                                    ascending:YES];
        [result retain];
        OBASSERT(result);
    }
    
    return result;
}

#pragma mark Managing Content

@synthesize sidebar = _sidebar;

- (void)setManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    [super setManagedObjectContext:managedObjectContext];
    
    //  Setting automaticallyPreparesContent to YES in IB doesn't handle there being no MOC set properly. So we hold off doing the initial fetch until there is a MOC. After that everything seems to work normally.
    if (managedObjectContext && ![self automaticallyPreparesContent])
    {
        [self setAutomaticallyPreparesContent:YES];
        [self fetch:self];
    }
}

#pragma mark Adding and Removing Objects

- (void)insertObject:(id)object atArrangedObjectIndex:(NSUInteger)index;
{
    OBPRECONDITION(object);
    
    // Position right
    [self moveObject:object toIndex:index];
    
    // Do the insert
    [super insertObject:object atArrangedObjectIndex:index];
    [object didAddToPage:[[self sidebar] page]];
    
    
    // Detach from text attachment
    //[pagelet detachFromBodyText];
}

- (void)addObject:(id)pagelet
{
    // Add to as many descendants as appropriate. Must do it before calling super otherwise inheritablePagelets will be wrong
    [[self class]
     _addPagelet:pagelet toSidebarOfDescendantsOfPageIfApplicable:[[self sidebar] page]];
    
    // Place at top of sidebar, unlike most controllers
	[self insertObject:pagelet atArrangedObjectIndex:0];
}

+ (void)addPagelet:(SVGraphic *)pagelet toSidebarOfPage:(KTPage *)page;
{
    [self _addPagelet:pagelet toSidebarOfDescendantsOfPageIfApplicable:page];
    [[page sidebar] addPageletsObject:pagelet];
}

+ (void)_addPagelet:(SVGraphic *)pagelet
toSidebarOfDescendantsOfPageIfApplicable:(KTPage *)page;
{
    NSSet *inheritablePagelets = [[page sidebar] pagelets];
    
    for (SVSiteItem *aSiteItem in [page childItems])
    {
        // We only care about actual pages
        KTPage *aPage = [aSiteItem pageRepresentation];
        if (!aPage) continue;
        
        
        // It's reasonable to add the pagelet if one of more pagelets from the parent also appear
        SVSidebar *sidebar = [aPage sidebar];
        if ([[sidebar pagelets] intersectsSet:inheritablePagelets] ||
            [inheritablePagelets count] < 1)
        {
            [self addPagelet:pagelet toSidebarOfPage:aPage];
        }
    }
}

- (void)willRemoveObject:(id)object
{
    [super willRemoveObject:object];
    
    
    OBPRECONDITION([object isKindOfClass:[SVGraphic class]]);
    SVGraphic *pagelet = object;
                   
    // Recurse down the page tree removing the pagelet from their sidebars.
    [self removePagelet:pagelet fromSidebarOfPage:(KTPage *)[[self sidebar] page]];
    
    // Delete the pagelet if it no longer appears on any pages
    if ([[pagelet sidebars] count] == 0 && ![pagelet textAttachment])
    {
        [[self managedObjectContext] deleteObject:pagelet];
    }
}

- (void)removePagelet:(SVGraphic *)pagelet fromSidebarOfPage:(KTPage *)page;
{
    // No point going any further unless the page actually contains the pagelet! This can save recursing enourmous chunks of the site outline
    if ([[[page sidebar] pagelets] containsObject:pagelet])
    {
        // Remove from descendants first
        for (SVSiteItem *aSiteItem in [page childItems])
        {
            KTPage *pageRep = [aSiteItem pageRepresentation];
            if (pageRep) [self removePagelet:pagelet fromSidebarOfPage:pageRep];
        }
        
        // Remove from the receiver
        [[page sidebar] removePageletsObject:pagelet];
    }
}

#pragma mark Moving Pagelets

- (void)exchangeWithPrevious:(id)sender;
{
    // Move selected objects up one if they can
    NSIndexSet *selection = [self selectionIndexes];
    
    NSUInteger currentIndex = [selection firstIndex];
    while (currentIndex != NSNotFound)
    {
        if (currentIndex > 0)
        {
            id aPagelet = [[self arrangedObjects] objectAtIndex:currentIndex];
            
            [self moveObject:aPagelet
                beforeObject:[[self arrangedObjects] objectAtIndex:(currentIndex - 1)]];
        }
        
        currentIndex = [selection indexGreaterThanIndex:currentIndex];
    }
}

- (void)exchangeWithNext:(id)sender;
{
    // Move selected objects down one if they can
    NSIndexSet *selection = [self selectionIndexes];
    
    NSUInteger currentIndex = [selection lastIndex];
    while (currentIndex != NSNotFound)
    {
        if (currentIndex < ([[self arrangedObjects] count] - 1))
        {
            id aPagelet = [[self arrangedObjects] objectAtIndex:currentIndex];
            
            [self moveObject:aPagelet
                 afterObject:[[self arrangedObjects] objectAtIndex:(currentIndex + 1)]];
        }
        
        currentIndex = [selection indexLessThanIndex:currentIndex];
    }
}

- (void)moveObject:(id)object toIndex:(NSUInteger)index;
{
    SVGraphic *pagelet = object;
    
    
    if (index >= [[self arrangedObjects] count])
    {
        SVGraphic *lastPagelet = [[self arrangedObjects] lastObject];
        [self moveObject:pagelet afterObject:lastPagelet];
    }
    else
    {
        SVGraphic *refPagelet = [[self arrangedObjects] objectAtIndex:index];
        [self moveObject:pagelet beforeObject:refPagelet];
    }
}

- (void)moveObject:(id)object beforeObject:(id)pagelet;
{
    OBPRECONDITION(pagelet);
    
    NSArray *pagelets = [self allSidebarPagelets];
    
    // Locate after pagelet
    NSUInteger index = [pagelets indexOfObject:pagelet];
    OBASSERT(index != NSNotFound);
    
    // Set our sort key to match
    NSNumber *pageletSortKey = [pagelet sortKey];
    OBASSERT(pageletSortKey);
    NSInteger previousSortKey = [pageletSortKey integerValue] - 1;
    [object setSortKey:[NSNumber numberWithInteger:previousSortKey]];
    
    // Bump previous pagelets along as needed
    for (NSUInteger i = index; i > 0; i--)  // odd handling of index so we can use an *unsigned* integer
    {
        SVGraphic *previousPagelet = [pagelets objectAtIndex:(i - 1)];
        if (previousPagelet != object)    // don't want to accidentally process self twice
        {
            previousSortKey--;
            
            if ([[previousPagelet sortKey] integerValue] > previousSortKey)
            {
                [previousPagelet setSortKey:[NSNumber numberWithInteger:previousSortKey]];
            }
            else
            {
                break;
            }
        }
    }
}

- (void)moveObject:(id)object afterObject:(id)pagelet;
{
    OBPRECONDITION(object);
    
    NSArray *pagelets = [self allSidebarPagelets];
    
    // Set our sort key to match
    NSNumber *pageletSortKey = (pagelet ? [pagelet sortKey] : [NSNumber numberWithInteger:-1]);
    OBASSERT(pageletSortKey);
    NSInteger nextSortKey = [pageletSortKey integerValue] + 1;
    [object setSortKey:[NSNumber numberWithInteger:nextSortKey]];
    
    
    // Bump following pagelets along as needed
    NSUInteger i = 0;
    if (pagelet)
    {
        NSUInteger index = [pagelets indexOfObject:pagelet];
        OBASSERT(index != NSNotFound);
        i = index+1;
    }
    
    for (; i < [pagelets count]; i++)
    {
        SVGraphic *nextPagelet = [pagelets objectAtIndex:i];
        if (nextPagelet != object)    // don't want to accidentally process self twice
        {
            nextSortKey++;
            
            if ([[nextPagelet sortKey] integerValue] < nextSortKey)
            {
                [nextPagelet setSortKey:[NSNumber numberWithInteger:nextSortKey]];
            }
            else
            {
                break;
            }
        }
    }
}

#pragma mark Pasteboard

- (BOOL)insertPageletsFromPasteboard:(NSPasteboard *)pasteboard
               atArrangedObjectIndex:(NSUInteger)index;
{
    BOOL result = NO;
    
    
    // Fallback to inserting a new pagelet from the pasteboard
    NSManagedObjectContext *context = [self managedObjectContext];
    
    NSArray *pagelets = [SVGraphic graphicsFromPasteboard:pasteboard
                           insertIntoManagedObjectContext:context];
    
    
    // Fallback to generic pasteboard support
    if ([pagelets count] < 1)
    {
        pagelets = [SVGraphicFactory graphicsFromPasteboard:pasteboard
                            insertIntoManagedObjectContext:context];
    }
    
    for (SVGraphic *aPagelet in pagelets)
    {
        [aPagelet setShowsTitle:YES];
        [self insertObject:aPagelet atArrangedObjectIndex:index];
        result = YES;
    }
    
    
    if (!result) NSBeep();
    return result;
}

- (SVGraphic *)addObjectFromSerializedPagelet:(id)serializedPagelet;
{
    SVGraphic *result = [SVGraphic graphicWithSerializedProperties:serializedPagelet
                                     insertIntoManagedObjectContext:[self managedObjectContext]];
    
    if (result) [self addObject:result];
    
    return result;
}

#pragma mark Automatic Rearranging

- (NSArray *)automaticRearrangementKeyPaths;
{
    NSArray *result = [super automaticRearrangementKeyPaths];
    result = (result ? [result arrayByAddingObject:@"sortKey"] : [NSArray arrayWithObject:@"sortKey"]);
    return result;
}

@end

