//
//  NSOutlineView+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004 Biophony LLC. All rights reserved.
//

#import "NSOutlineView+KTExtensions.h"

#import "Debug.h"
#import "KTPage.h"

@implementation NSOutlineView (KTExtensions)

- (int)numberOfChildrenOfItem:(id)item;
{
	int result = [[self dataSource] outlineView:self numberOfChildrenOfItem:item];
	return result;
}

- (id)child:(int)index ofItem:(id)item
{
	id result = [[self dataSource] outlineView:self child:index ofItem:item];
	return result;
}

#pragma mark -
#pragma mark Selection

- (void)expandSelectedRow
{
	[self expandItem:[self itemAtRow:[self selectedRow]]];
}

- (void)selectItem:(id)anItem
{
	OFF((@"selectItem: %@", [anItem titleText]));

	[self selectItem:anItem forceDidChangeNotification:NO];
}

- (void)selectItem:(id)anItem forceDidChangeNotification:(BOOL)aFlag
{
    int row = [self rowForItem:anItem];
	OFF((@"selectItem: %@ forceDidChangeNotification:%d -> row %d", [anItem titleText], aFlag, row));
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	if ( aFlag )
	{
		NSNotification *notification = [NSNotification notificationWithName:NSOutlineViewSelectionDidChangeNotification
																	 object:self];
		[[NSNotificationCenter defaultCenter] postNotification:notification];
		

// THE OLD CODE WAS USING A QUEUE TO COALESCE THE NOTIFICATIONS, BUT THIS MEANS DELAYING BY ONE RUNLOOP ITERATION. Mike.
		
//		NSNotificationQueue *queue = [NSNotificationQueue defaultQueue];
//		
//		[queue enqueueNotification:notification 
//					  postingStyle:NSPostASAP 
//					  coalesceMask:NSNotificationCoalescingOnSender 
//						  forModes:nil];
	}
}

- (void)selectItems:(NSArray *)theItems
{
	[self selectItems:theItems forceDidChangeNotification:NO];
}

- (void)selectItems:(NSArray *)theItems forceDidChangeNotification:(BOOL)aFlag
{
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    
    NSEnumerator *e = [theItems objectEnumerator];
    id item;
    while ( item = [e nextObject] )
    {
        unsigned int row = [self rowForItem:item];
        if ( 0 <= row )
        {
            [indexSet addIndex:row];
        }
    }
    
    if ( [indexSet count] > 0 )
    {
        [self selectRowIndexes:indexSet byExtendingSelection:NO];
		if ( aFlag )
		{
			NSNotification *notification = [NSNotification notificationWithName:NSOutlineViewSelectionDidChangeNotification
																		 object:self];
			[[NSNotificationCenter defaultCenter] postNotification:notification];
		}
    }
}

/*!	If one item selected, return it.  Otherwise, return nil.
*/
- (id)selectedItem
{
	if ( 1 == [self numberOfSelectedRows] )
	{
		int selectedRow = [self selectedRow];
		id result = [self itemAtRow:selectedRow];
		return result;
	}
	else
	{
		return nil;
	}
	//return (1 == [self numberOfSelectedRows]) ? [self itemAtRow:[self selectedRow]] : nil;
}

/*!	Return selected items as an array of items
*/
- (NSArray *)selectedItems
{
    NSMutableArray *array = [NSMutableArray array];
    NSIndexSet *indexSet = [self selectedRowIndexes];
    unsigned int count = [indexSet count];
    
    if ( count > 0 ) {
        unsigned int anIndex = [indexSet firstIndex];
        
		id theObj = [self itemAtRow:anIndex];
		if (nil != theObj)	// above may return null, not sure why
		{
			[array addObject:theObj];
			while ( NSNotFound != (anIndex = [indexSet indexGreaterThanIndex:anIndex]) )
			{
				theObj = [self itemAtRow:anIndex];
				if (!theObj)
				{
					theObj = [NSNull null];
				}
				[array addObject:theObj];
			}
		}
    }
    return [NSArray arrayWithArray:array];
}

- (id)itemAboveFirstSelectedRow
{
    return [self itemAtRow:[[self selectedRowIndexes] firstIndex]-1];
}

- (NSArray *)itemsAtRows:(NSIndexSet *)rowIndexes
{
	// We can bail early in certain circumstances
	if (!rowIndexes || [rowIndexes count] <= 0)
	{
		return nil;
	}
	
	
	NSMutableArray *buffer = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
	
	unsigned index = [rowIndexes firstIndex];
	[buffer addObject:[self itemAtRow:index]];
	
	while ((index = [rowIndexes indexGreaterThanIndex:index]) != NSNotFound)
	{
		[buffer addObject:[self itemAtRow:index]];
	}
	
	return [[buffer copy] autorelease];
}

- (NSIndexSet *)rowsForItems:(NSArray *)items;
{
	NSMutableIndexSet *buffer = [[NSMutableIndexSet alloc] init];
	NSEnumerator *itemsEnumerator = [items objectEnumerator];
	id anItem;		int aRow;
	
	while (anItem = [itemsEnumerator nextObject])
	{
		aRow = [self rowForItem:anItem];
		[buffer addIndex:aRow];
	}
	
	// Tidy up
	NSIndexSet *result = [[buffer copy] autorelease];
	[buffer release];
	return result;
}

#pragma mark -
#pragma mark Drawing

/*	Equivalent to -reloadItem:reloadChildren: but for handling -setNeedsDisplayInRect:
 */
- (void)setItemNeedsDisplay:(id)item childrenNeedDisplay:(BOOL)recursive
{
	NSRect displayRect = [self rectOfRow:[self rowForItem:item]];
	
	// Basic tactic for recursive display is to union the item's rect and that of its last visible child
	if (recursive && [self isItemExpanded:item])
	{
		id lastVisibleChild = [self lastVisibleChildOfItem:item];
		NSRect lastChildRect = [self rectOfRow:[self rowForItem:lastVisibleChild]];
		displayRect = NSUnionRect(displayRect, lastChildRect);
	}
	
	[self setNeedsDisplayInRect:displayRect];
}

/*	If the item is expanded and has some children, searches down into the hierarchy to find the last visible
 *	child. Otherwise, just returns the item.
 */
- (id)lastVisibleChildOfItem:(id)item
{
	id result = item;
	
	if ([self isItemExpanded:item])
	{
		int childCount = [self numberOfChildrenOfItem:item];
		if (childCount > 0)
		{
			id lastChild = [self child:(childCount - 1) ofItem:item];
			result = [self lastVisibleChildOfItem:lastChild];
		}
	}
	
	return result;
}

@end

