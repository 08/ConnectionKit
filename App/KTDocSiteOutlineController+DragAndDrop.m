//
//  KTDocSiteOutlineController+DragAndDrop.m
//  Marvel
//
//  Created by Mike on 11/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//


#import "Debug.h"
#import "DOMNode+KTExtensions.h"
#import "KT.h"
#import "KTDataSource.h"
#import "KTAppDelegate.h"
#import "KTDocSiteOutlineController.h"
#import "KTDocument.h"
#import "KTDocWindowController.h"
#import "KTPage.h"
#import "KTPulsatingOverlay.h"
#import "NSArray+Karelia.h"
#import "NSException+Karelia.h"
#import "KTElementPlugin.h"


/// these are localized strings for Case 26766 Disposable Dialog When Changing A Published Page's Path
// NSLocalizedString(@"Are you sure you wish to change the file name of this page?", @"title of alert when changing page file name")
// NSLocalizedString(@"Changing the file name of this page will also change the URL of this page. Because this page has been previously published, any bookmarks or links to this page from other websites will no longer work.", @"body of alert when changing page file name")
// NSLocalizedString(@"Change", @"alert button when changing file name")
// NSLocaiizedString(@"Note: the previously published page '%@' will not be deleted from your server.", @"alert optional note when changing page file name")



@interface KTDocSiteOutlineController (DragAndDropPrivate)
- (NSArray *)itemsForRows:(NSArray *)anArray;
- (BOOL)item:(id)anItem isDescendantOfItem:(id)anotherItem;
- (BOOL)items:(NSArray *)items containsParentOfItem:(id)item;
@end


@implementation KTDocSiteOutlineController (DragAndDrop)

#pragma mark -
#pragma mark Drag

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    if ( isLocal ) 
	{
        return NSDragOperationMove;
    }
	
    return NSDragOperationCopy;
}

/*! writes the row number for each selected row to the pboard (as an NSString)
 allRows is an array of every selected row's number
 parentRows, a subset of allRows, lists the rows at the top of the selection
 tree, i.e., those rows not contained within another selected item.
 in theory, just moving the parentRows should bring along everything
 */
- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	[pboard declareTypes:[NSArray arrayWithObjects:kKTOutlineDraggingPboardType, kKTPagesPboardType, nil] owner:self];
	
	NSMutableArray *allRows = [NSMutableArray arrayWithCapacity:[items count]];
	
	// copy parent row numbers to pboard
	NSMutableArray *parentRows = [NSMutableArray arrayWithCapacity:[items count]];
	NSMutableDictionary *pboardData = [NSMutableDictionary dictionary];
	
	NSEnumerator *e = [items objectEnumerator];
	id item;
	while ( item = [e nextObject] )
	{
		[allRows addObject:[NSString stringWithFormat:@"%i", [[self siteOutline] rowForItem:item]]];
		if ( ![self items:items containsParentOfItem:item] )
		{
			[parentRows addObject:[NSString stringWithFormat:@"%i", [[self siteOutline] rowForItem:item]]];
		}
	}
	
	// once we know allRows, we can check for root
	if ( 0 == [[allRows objectAtIndex:0] intValue] )
	{
		// the rootFolder (item at row 0) should not be draggable
		return NO;
	}
	
	[pboardData setObject:allRows forKey:@"allRows"];
	[pboardData setObject:parentRows forKey:@"parentRows"];
	[pboard setPropertyList:pboardData forType:kKTOutlineDraggingPboardType];
	
	//  package up the selected page(s)
	//  NB: we package any children within the parents
	NSMutableArray *archivedPages = [NSMutableArray arrayWithCapacity:[parentRows count]];
	NSArray *parentObjects = [self itemsForRows:parentRows];
	e = [parentObjects objectEnumerator];
	KTPage *aPage;
	while (aPage = [e nextObject])
	{
		[archivedPages addObject:[aPage pasteboardRepresentation]];
	}
	
	
	// now, pop it on the pasteboard
	NSData *copyData = [NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithArray:archivedPages]];
	[pboard setData:copyData forType:kKTPagesPboardType];
	
	return YES;
}

#pragma mark -
#pragma mark Drop

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView
				  validateDrop:(id <NSDraggingInfo>)info
				  proposedItem:(id)item
			proposedChildIndex:(int)anIndex
{
	//LOG((@"validateDrop: %@ proposedItem: %@ proposedChildIndex: %i", info, [item fileName], anIndex));
	NSPasteboard *pboard = [info draggingPasteboard];
	NSDictionary *pboardData = [pboard propertyListForType:kKTOutlineDraggingPboardType];
	NSArray *allRows = [pboardData objectForKey:@"allRows"];
	
	id root = [[self document] root];
	id proposedParent;
	if ( nil == item )
	{
		proposedParent  = root;
	}
	else
	{
		proposedParent = item;
	}
	int proposedParentSortOrder = [proposedParent integerForKey:@"collectionSortOrder"];
	// KTCollectionSortAlpha, KTCollectionSortLatestAtBottom, KTCollectionSortLatestAtTop, or KTCollectionUnsorted
	
	BOOL cameFromProgram = (nil != [info draggingSource]);
	if (cameFromProgram)
	{
		if  ( [[self siteOutline] isEqual:[info draggingSource]] )
		{
			KTPage *firstDraggedItem = [[self siteOutline] itemAtRow:[[allRows objectAtIndex:0] intValue]];
			// this should be a "local" drag
			if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:kKTOutlineDraggingPboardType]] )
			{
				if ( NSOutlineViewDropOnItemIndex == anIndex )
				{
					// we only allow, for now, dropping onto a page if it's already a collection
					// but not already the parent of firstDraggedItem and not a parent of proposedParent
					if ( [proposedParent isCollection] 
						&& ![proposedParent isEqual:[firstDraggedItem parent]]
						&& ![self item:proposedParent isDescendantOfItem:firstDraggedItem] )
					{
						//LOG((@"allowing drop directly onto collection %@", [proposedParent fileName]));
						return NSDragOperationMove;
					}
					else
					{
						//LOG((@"disallowing drop directly onto \"%@\" since it's not a collection", [proposedParent fileName]));
						return NSDragOperationNone;
					}
				}
				else if ( (proposedParent == root) && (anIndex == 0) )
				{
					// nothing should drop above home
					//LOG((@"disallowing drop since it would be above home"));
					return NSDragOperationNone;
				}
				else if ( [self item:proposedParent isDescendantOfItem:firstDraggedItem] )
				{
					// a parent should not become a child of its children
					//LOG((@"disallowing drop since it would have become a child of one of its own children"));
					return NSDragOperationNone;
				}
				else if ( [[self itemsForRows:allRows] containsObject:item] )
				{
					// an item should not become a child of itself
					//LOG((@"disallowing drop since a collection would have become a child of itself"));
					return NSDragOperationNone;
				}
				else if ( ![proposedParent isCollection] )
				{
					// a page, for now, should not become a parent just by dragging something under it
					//LOG((@"disallowing drop since don't allow creating a collection via drag"));
					return NSDragOperationNone;
				}
				else if ( [proposedParent isEqual:[firstDraggedItem parent]]
						 && ((![proposedParent isRoot] && ((unsigned)anIndex == [[[firstDraggedItem parent] sortedChildren] indexOfObject:firstDraggedItem]))
							 || ([proposedParent isRoot] && ((unsigned)(anIndex-1) == [[[firstDraggedItem parent] sortedChildren] indexOfObject:firstDraggedItem]))) )
				{
					// the text of the above conditional is "if the parent is the same and
					// the index is the same or, if the parent is the same and also root and
					// the index is the same as anIndex-1 (to account for "home")"
					
					// if we're just dropping at the same place, no need to show a drag indicator
					//LOG((@"disallowing drop since we're dropping in the same place"));
					return NSDragOperationNone;
				}
				else
				{
					// if we've made it this far through the rules, we need to look at KTCollectionSortType
					switch ( proposedParentSortOrder )
					{
						case KTCollectionUnsorted:
						{
							// drop anywhere into an unsorted collection
							//LOG((@"allowing drop into unsorted collection"));
							return NSDragOperationMove;
							break;
						}
						case KTCollectionSortAlpha:
						case KTCollectionSortReverseAlpha:
						case KTCollectionSortLatestAtTop:
						case KTCollectionSortLatestAtBottom:
						{
							// only allow drop at proposedOrdering
							int childIndex = [proposedParent proposedOrderingForProposedChild:firstDraggedItem
																					 sortType:proposedParentSortOrder];
							if ( childIndex == anIndex )
							{
								//LOG((@"allowing drop in sorted collection on appropriate index"));
								return NSDragOperationMove;
							}
							else
							{
								//LOG((@"disallowing drop in sorted collection on inappropriate index"));
								return NSDragOperationNone;
							}
							break;
						}
						default:
						{
							// sort order is unknown, disallow drag?
							//LOG((@"disallowing drop: we should never get here"));
							return NSDragOperationNone;
							break;
						}
					}
				}
			}
			else if ( NO )
			{
				// other internal pboard types
				;
			}	
		}
		else if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:kKTPagesPboardType]] )
		{
			// we probably have some pages on the pasteboard that we want to add at the drop point
			// but we need to validate
			if ( NSOutlineViewDropOnItemIndex == anIndex )
			{
				// we only allow, for now, dropping onto a page if it's already a collection
				if ( [proposedParent isCollection] )
				{
					//LOG((@"allowing drop directly onto collection %@", [proposedParent fileName]));
					return NSDragOperationCopy;
				}
				else
				{
					//LOG((@"disallowing drop directly onto \"%@\" since it's not a collection", [proposedParent fileName]));
					return NSDragOperationNone;
				}
			}
			else if ( (proposedParent == root) && (anIndex == 0) )
			{
				// nothing should drop above home
				//LOG((@"disallowing drop since it would be above home"));
				return NSDragOperationNone;
			}
			else if ( ![proposedParent isCollection] )
			{
				// a page, for now, should not become a parent just by dragging something under it
				//LOG((@"disallowing drop since don't allow creating a collection via drag"));
				return NSDragOperationNone;
			}
			else
			{
				// if we've made it this far through the rules, we need to look at KTCollectionSortType
				int dropIndex = anIndex;
				if ( [proposedParent isRoot] )
				{
					--dropIndex;
				}
				
				switch ( proposedParentSortOrder )
				{
					case KTCollectionUnsorted:
					{
						// drop anywhere into an unsorted collection
						//LOG((@"allowing drop into unsorted collection"));
						return NSDragOperationCopy;
						break;
					}
					
					case KTCollectionSortAlpha:
					case KTCollectionSortReverseAlpha:
					{
						// we're going to be sorting on titles, so get a suitable title
						NSString *title = nil;
						// title will be the htmlTitle of the first page on the pasteboard
						NSData *pagesPboardData = [[info draggingPasteboard] dataForType:kKTPagesPboardType];
						if ( nil != pagesPboardData )
						{							
							NSDictionary *pboardInfo = [NSUnarchiver unarchiveObjectWithData:pagesPboardData];
							NSArray *pagesArray = [pboardInfo valueForKey:@"pages"];
							NSDictionary *firstPage = [pagesArray firstObject];
							if ( nil != [firstPage valueForKey:@"titleHTML"] )
							{
								title = [firstPage valueForKey:@"titleHTML"];
							}
						}
						if ( nil == title )
						{
							LOG((@"error: couldn't find a suitable title for alpha sort"));
							return NSDragOperationNone;
						}
						else
						{
							LOG((@"atempting alphasort with title \"%@\"", title));
						}
						
						// only allow drop at proposedOrdering
						int childIndex = [proposedParent proposedOrderingForProposedChildWithTitle:title];
						if ( childIndex == dropIndex )
						{
							//LOG((@"allowing drop in sorted collection on appropriate index"));
							return NSDragOperationCopy;
						}
						else
						{
							//LOG((@"disallowing drop in sorted collection on inappropriate index"));
							return NSDragOperationNone;
						}						
						break;
					}
					case KTCollectionSortLatestAtTop:
					{
						// if we sort latest at top, we can only add to top
						if ( dropIndex == 0 )
						{
							return NSDragOperationCopy;
						}
						else
						{
							return NSDragOperationNone;
						}
						break;
					}
					case KTCollectionSortLatestAtBottom:
					{
						if ( (unsigned)dropIndex == [[proposedParent sortedChildren] count] )
						{
							return NSDragOperationCopy;
						}
						else
						{
							return NSDragOperationNone;
						}						
						break;
					}
					default:
					{
						// sort order is unknown, disallow drag?
						//LOG((@"disallowing drop: we should never get here"));
						return NSDragOperationNone;
						break;
					}
				}
			}			
		}			
	}
	
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:@"kKTLocalLinkPboardType"]])
	{
		if ( NSOutlineViewDropOnItemIndex == anIndex )
		{
			// If our input string is a collection, then return NO if it's not a collection.
			NSString *pboardString = [pboard stringForType:@"kKTLocalLinkPboardType"];
			if ([pboardString isEqualToString:@"KTCollection"] && ![item isCollection])
			{
				[[KTPulsatingOverlay sharedOverlay] hide];
				return NSDragOperationNone;
			}
			//set up a pulsating window
			if (item)
			{
				int row = [outlineView rowForItem:item];
				NSRect rowRect = [outlineView rectOfRow:row];
				//covert the origin to window coords
				rowRect.origin = [[outlineView window] convertBaseToScreen:[outlineView convertPoint:rowRect.origin toView:nil]];
				rowRect.origin.y -= NSHeight(rowRect); //handle it because it is flipped.
				if (!NSEqualSizes(rowRect.size, NSZeroSize))
				{
					[[KTPulsatingOverlay sharedOverlay] displayWithFrame:rowRect];
				}
				else
				{
					[[KTPulsatingOverlay sharedOverlay] hide];
				}
				
				return NSDragOperationLink;
			}
			else
			{
				[[KTPulsatingOverlay sharedOverlay] hide];
				return NSDragOperationNone;
			}
		}
		else
		{
			[[KTPulsatingOverlay sharedOverlay] hide];
			return NSDragOperationNone;
		}
	}
	
	// Fall through -- external drag, or internal drag not handled above.
	
	// "children are a zero-based index"
	
	// do we have a good drag source?
	/// check the *first* item in the list ... probably not perfect but it ought to do
	KTDataSource *bestSource = [KTDataSource highestPriorityDataSourceForDrag:info index:0 isCreatingPagelet:NO];
	if ( nil != bestSource )
	{
		if ( NSOutlineViewDropOnItemIndex == anIndex )
		{
			// we only allow, for now, dropping onto a page if it's already a collection
			if ( [item isKindOfClass:[KTPage class]] && [item isCollection] )
			{
				//LOG((@"allowing direct drop onto pre-existing collection"));
				return NSDragOperationCopy;
			}
			else
			{
				//LOG((@"disallowing direct drop onto page that is not a collection"));
				return NSDragOperationNone;
			}
		}
		else if ( [proposedParent isRoot] && (0 == anIndex) )
		{
			// we don't allow dropping above "home"
			//LOG((@"disallowing drop above home"));
			return NSDragOperationNone;
		}
		else if ( [proposedParent isKindOfClass:[KTPage class]] && [proposedParent isCollection] )
		{
			//LOG((@"wants to create child of %@ at index %i", [item fileName], anIndex));
			// if we've made it this far through the rules, we need to look at KTCollectionSortType
			int dropIndex = anIndex;
			if ( [proposedParent isRoot] )
			{
				--dropIndex;
			}
			
			switch ( proposedParentSortOrder )
			{
				case KTCollectionUnsorted:
				{
					// drop anywhere into an unsorted collection
					//LOG((@"allowing drop into unsorted collection"));
					return NSDragOperationCopy;
					break;
				}
				case KTCollectionSortAlpha:
				case KTCollectionSortReverseAlpha:
				{
					// we're going to be sorting on titles, so get a suitable title
					NSMutableDictionary *sourceInfoDictionary = [NSMutableDictionary dictionary];
					[sourceInfoDictionary setValue:[info draggingPasteboard] forKey:kKTDataSourcePasteboard];	// always include this!
					// No way to really deal with multiple items here, so just take the first title
					(void)[bestSource populateDictionary:sourceInfoDictionary forPagelet:NO fromDraggingInfo:info index:0];
					NSString *title = [sourceInfoDictionary valueForKey:kKTDataSourceTitle];
					if ( nil == title )
					{
						NSFileManager *fm = [NSFileManager defaultManager];
						title = [[fm displayNameAtPath:[sourceInfoDictionary valueForKey:kKTDataSourceFileName] ] stringByDeletingPathExtension];
						if  ( nil == title )
						{
							NSString *bundleIdentifier = [bestSource pageBundleIdentifier];
							if  ( nil != bundleIdentifier  )
							{
								id plugin = [KTElementPlugin pluginWithIdentifier:bundleIdentifier];
								if ( nil != plugin )
								{
									title = [plugin pluginPropertyForKey:@"KTPluginUntitledName"];
								}
							}
						}
					}
					
					if ( nil == title )
					{
						LOG((@"error: couldn't find a suitable title for alpha sort"));
						return NSDragOperationNone;
					}
					else
					{
						LOG((@"atempting alphasort with title \"%@\"", title));
					}
					
					// only allow drop at proposedOrdering
					int childIndex = [proposedParent proposedOrderingForProposedChildWithTitle:title];
					if ( childIndex == dropIndex )
					{
						//LOG((@"allowing drop in sorted collection on appropriate index"));
						return NSDragOperationCopy;
					}
					else
					{
						//LOG((@"disallowing drop in sorted collection on inappropriate index"));
						return NSDragOperationNone;
					}						
					break;
				}
				case KTCollectionSortLatestAtTop:
				{
					// if we sort latest at top, we can only add to top
					if ( dropIndex == 0 )
					{
						return NSDragOperationCopy;
					}
					else
					{
						return NSDragOperationNone;
					}
					break;
				}
				case KTCollectionSortLatestAtBottom:
				{
					if ( (unsigned)dropIndex == [[proposedParent sortedChildren] count] )
					{
						return NSDragOperationCopy;
					}
					else
					{
						return NSDragOperationNone;
					}						
					break;
				}
				default:
				{
					// sort order is unknown, disallow drag?
					//LOG((@"disallowing drop: we should never get here"));
					return NSDragOperationNone;
					break;
				}
			}
		}
		else if ( [proposedParent isEqual:[[self siteOutline] itemAtRow:([[self siteOutline] numberOfRows]-1)]] )
		{
			// if we're dropping below the last row of the outline, accept the drag
			// but reposition the drop to be at the root level
			// NB: we add 1 to account for the row taken up by "home"
			[[self siteOutline] setDropItem:nil 
					   dropChildIndex:([[[(KTDocument *)[self document] root] children] count]+1)];
			return NSDragOperationCopy;
		}
		else
		{
			LOG((@"disallowing drop: this is an unknown case"));
		}
		
		// Done with that single pass process
		[KTDataSource doneProcessingDrag];
		
	}
	else
	{
		LOG((@"no datasource agreed to validate this drop"));
		return NSDragOperationNone;
	}
	
	return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)anIndex
{
	NSPasteboard *pboard = [info draggingPasteboard];
	(void)[pboard types];
	
	KTPage *proposedParent = item;
	if ( nil == proposedParent )
	{
		proposedParent = [(KTDocument *)[self document] root];
	}
	
	BOOL cameFromProgram = nil != [info draggingSource];
	
	if ( cameFromProgram )
	{
		if  ( [[self siteOutline] isEqual:[info draggingSource]] )
		{
			// drag is internal to document
			if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:kKTOutlineDraggingPboardType]] )
			{
				NSDictionary *pboardData = [pboard propertyListForType:kKTOutlineDraggingPboardType];
				
				// remember all selected rows
				NSArray *allRows = [pboardData objectForKey:@"allRows"];
				NSMutableArray *selectedItems = [NSMutableArray arrayWithCapacity:[allRows count]];
				NSEnumerator *e = [allRows objectEnumerator];
				id row;
				while ( row = [e nextObject] )
				{
					[selectedItems addObject:[[self siteOutline] itemAtRow:[row intValue]]];
				}
				
				// we use parentRows here as moving the parent rows should move all the children as well
				NSArray *parentRows = [pboardData objectForKey:@"parentRows"];
				
				// Adjust dropRow to account for "home"
				int dropRow;
				if ([proposedParent isRoot]) {
					dropRow = anIndex-1;
				}
				else {
					dropRow = anIndex;
				}
				
				NSMutableArray *draggedItems = [NSMutableArray arrayWithCapacity:[parentRows count]];
				
				e = [parentRows objectEnumerator];
				while ( row = [e nextObject] )
				{
					[draggedItems addObject:[[self siteOutline] itemAtRow:[row intValue]]];
				}
				
				
				
				// The behavior is different depending on if we're dropping ON or INTO.
				if (dropRow == -1)
				{
					e = [draggedItems objectEnumerator];
					KTPage *aPage;
					while (aPage = [e nextObject])
					{
						[aPage retain];
						[[aPage parent] removePage:aPage];
						[proposedParent addPage:aPage];
						[aPage release];
					}
				}
				else
				{
					e = [draggedItems reverseObjectEnumerator];	// By running in reverse we can keep inserting pages at the same index
					KTPage *draggedItem;
					while ( draggedItem = [e nextObject] )
					{
						[draggedItem retain];
						
						// When moving between collections, remove the page from its parent first.
						KTPage *draggedItemParent = [draggedItem parent];
						if (proposedParent != draggedItemParent)
						{
							[draggedItemParent removePage:draggedItem];
							[proposedParent addPage:draggedItem];
						}
						
						[draggedItem moveToIndex:dropRow];
						
						[draggedItem release];
					}
				}
				
				// select what was selected during the drag
				NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
				e = [selectedItems objectEnumerator];
				KTPage *selectedPage;
				while ( selectedPage = [e nextObject] )
				{
					int selectedRow = [[self siteOutline] rowForItem:selectedPage];
					[indexSet addIndex:selectedRow];
				}
				OFF((@"selecting indexes: %@", indexSet));
				[[self siteOutline] selectRowIndexes:indexSet byExtendingSelection:NO];
				
				[[[self document] undoManager] setActionName:NSLocalizedString(@"Drag", "action name for dragging source objects withing the outline")];
				
				return YES;
			}
			else if ( NO )
			{
				// other internal pboard types
				;
			}
		}
		else if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:kKTPagesPboardType]] )
		{
			// we have some pages on the pasteboard that we want to add at the drop point
			
			NSData *pboardData = [pboard dataForType:kKTPagesPboardType];
			if ( nil != pboardData )
			{
				//				[[self document] setSuspendSavesDuringPeerCreation:YES];
				
				
				NSArray *archivedPages = [NSKeyedUnarchiver unarchiveObjectWithData:pboardData];
				
				
				
				int i = 0;
				NSString *localizedStatus = NSLocalizedString(@"Copying...", "");
				BOOL displayProgressIndicator = NO;
				BOOL didDisplayProgressIndicator = NO;
				if ([archivedPages count] > 3)
				{
					displayProgressIndicator = YES;
				}
				else
				{
					int i;
					for ( i=0; i<[archivedPages count]; i++)
					{
						NSDictionary *pageInfo = [archivedPages objectAtIndex:i];
						if ( [[pageInfo valueForKey:@"isCollection"] boolValue] ) 
						{
							displayProgressIndicator = YES;
							break;
						}
					}
				}
				
				if ( displayProgressIndicator )
				{
					[[self windowController] beginSheetWithStatus:localizedStatus
									  minValue:1 
									  maxValue:[archivedPages count] 
										 image:nil];
					didDisplayProgressIndicator = YES;
				}
				
				// Copy pages
				if ( didDisplayProgressIndicator )
				{
					i = 1;
					[[self windowController] setSheetMinValue:1 maxValue:[archivedPages count]];
				}				
				NSEnumerator *e = [archivedPages objectEnumerator];
				NSDictionary *rep;
				while ( rep = [e nextObject] )
				{
					if ( didDisplayProgressIndicator )
					{
						localizedStatus = NSLocalizedString(@"Copying pages...", "");
						[[self windowController] updateSheetWithStatus:localizedStatus progressValue:i];
						i++;
					}
					
					KTPage *page = [KTPage pageWithPasteboardRepresentation:rep parent:proposedParent];
					
					// Whinge if the page couldn't be created
					if (!page) {
						[self raiseExceptionWithName:kKareliaDocumentException reason:@"unable to create Page"];
					}
				}
				
				[[[self document] undoManager] setActionName:NSLocalizedString(@"Drag",
																			   @"action name for dragging source objects withing the outline")];
				
				if (didDisplayProgressIndicator)
				{
					[[self windowController] endSheet];
				}
				
				return YES;				
			}
		}
	}
	else if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:@"kKTLocalLinkPboardType"]] )
	{
		// hide the pulsating window
		[[KTPulsatingOverlay sharedOverlay] hide];
		// Get the page and update the pboard with it ... a way to send the info back to the origin of the drag!
		[pboard setString:[(KTPage *)item uniqueID] forType:@"kKTLocalLinkPboardType"];
		return YES;
	}
	
	// this should be a drag in from outside the application, or an internal drag not covered above.
	// we want to find a drag source for it and let it do its thing
	int dropIndex = anIndex;
	id dropItem = item;
	if ( nil == dropItem )
	{
		dropItem = [[self document] root];
		dropIndex = anIndex-1;
	}
	//LOG((@"accepting drop from external source on %@ at index %i", [dropItem fileName], dropIndex));
	BOOL result = [[self windowController] addPagesViaDragToCollection:dropItem atIndex:dropIndex draggingInfo:info];
	return result;
}

#pragma mark -
#pragma mark Support

- (NSArray *)itemsForRows:(NSArray *)anArray
{
	NSMutableArray *items = [NSMutableArray array];
	
	NSEnumerator *e = [anArray objectEnumerator];
	id row;
	while ( row = [e nextObject] )
	{
		[items addObject:[[self siteOutline] itemAtRow:[row intValue]]];
	}
	
	return [NSArray arrayWithArray:items];
}

- (BOOL)items:(NSArray *)items containsParentOfItem:(id)item
{
	BOOL result = NO;
	
    NSEnumerator *e = [items objectEnumerator];
    id object;
    while ( object = [e nextObject] )
	{
        if ( nil != [item parent] )
		{
            if ( object == [item parent] )
			{
                result = YES;
            }
        }
    }
	
    return result;
}

- (BOOL)item:(id)anItem isDescendantOfItem:(id)anotherItem
{
	BOOL result = NO;
	
	if ( [anotherItem hasChildren] )
	{
		NSEnumerator *e = [[anotherItem children] objectEnumerator];
		KTPage *child;
		while ( child = [e nextObject] )
		{
			if ( [child isEqual:anItem] )
			{
				result = YES;
			}
			else if ( [self item:anItem isDescendantOfItem:child] )
			{
				result = YES;
			}
		}
	}
	
	return result;
}

@end
