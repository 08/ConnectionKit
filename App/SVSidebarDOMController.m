//
//  SVSidebarDOMController.m
//  Sandvox
//
//  Created by Mike on 07/05/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSidebarDOMController.h"

#import "SVArticleDOMController.h"
#import "SVAttributedHTML.h"
#import "SVGraphicDOMController.h"
#import "KTPage.h"
#import "SVTextAttachment.h"
#import "SVWebEditorViewController.h"
#import "WebEditingKit.h"

#import "NSArray+Karelia.h"
#import "DOMNode+Karelia.h"


@interface SVSidebarDOMController ()

// Pagelets
- (NSRect)rectOfDropZoneBelowDOMNode:(DOMNode *)node1
                        aboveDOMNode:(DOMNode *)node2
                              height:(CGFloat)height;
- (NSRect)rectOfDropZoneBelowDOMNode:(DOMNode *)node height:(CGFloat)height;
- (NSRect)rectOfDropZoneAboveDOMNode:(DOMNode *)node height:(CGFloat)minHeight;
- (NSRect)rectOfDropZoneInDOMElement:(DOMElement *)element
                           belowNode:(DOMNode *)node
                           minHeight:(CGFloat)minHeight;

@end


#pragma mark -


@implementation SVSidebarDOMController

#pragma mark Init/Dealloc

static NSString *sSVSidebarDOMControllerPageletsObservation = @"SVSidebarDOMControllerPageletsObservation";

- (id)initWithPageletsController:(SVSidebarPageletsController *)pageletsController;
{
    [self initWithElementIdName:@"sidebar-container"];
    
    _pageletsController = [pageletsController retain];
    [_pageletsController addObserver:self
                          forKeyPath:@"arrangedObjects"
                             options:0
                             context:sSVSidebarDOMControllerPageletsObservation];
    
    return self;
}

- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
{
    [super awakeFromHTMLContext:context];
    [self setPageletDOMControllers:[self childWebEditorItems]];
}

- (void)dealloc;
{
    [_pageletsController removeObserver:self forKeyPath:@"arrangedObjects"];
    [_pageletsController release];
    
    [_DOMControllers release];
    [_sidebarDiv release];
    [_contentElement release];
    
    [super dealloc];
}

#pragma mark DOM

@synthesize sidebarDivElement = _sidebarDiv;
@synthesize contentDOMElement = _contentElement;

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    [super loadHTMLElementFromDocument:document];
    
    // Also seek out sidebar divs
    [self setSidebarDivElement:[document getElementById:@"sidebar"]];
    [self setContentDOMElement:[document getElementById:@"sidebar-content"]];
}

- (void)update;
{
    // Arrange DOM nodes to match. Start by removing all
    DOMElement *contentElement = [self contentDOMElement];
    [[contentElement mutableChildDOMNodes] removeAllObjects];
    
    NSArray *pagelets = [[self pageletsController] arrangedObjects];
    NSMutableArray *controllers = [[NSMutableArray alloc] initWithCapacity:[pagelets count]];
    
    SVGraphic *aPagelet;
    WEKWebEditorItem *nextController = nil;
    
    for (NSUInteger i = [pagelets count] - 1; i < NSNotFound;)
    {
        aPagelet = [pagelets objectAtIndex:i];
        i--;
        
        
        // Grab controller for item. Create it if needed
        id controller = [self hitTestRepresentedObject:aPagelet];
        if (!controller)
        {            
            controller = [[aPagelet newDOMController] autorelease];
            [controller loadPlaceholderDOMElementInDocument:[contentElement ownerDocument]];
            [self addChildWebEditorItem:controller];
            [controller setHTMLContext:[self HTMLContext]];
            
            [controller setNeedsUpdate];
            [controller updateIfNeeded];    // push it through quickly
        }
        
             
        // Insert before what should be its next sibling
        DOMElement *element = [controller HTMLElement];
        [contentElement insertBefore:element
                            refChild:[nextController HTMLElement]];
        
        [controllers insertObject:controller atIndex:0];
        
        
        // Loop
        nextController = controller;
    }
    
    [self setPageletDOMControllers:controllers];
    [controllers release];
    
    [super update];
}

- (SVSidebarDOMController *)sidebarDOMController; { return self; }

#pragma mark Pagelets Controller

@synthesize pageletDOMControllers = _DOMControllers;
@synthesize pageletsController = _pageletsController;

#pragma mark Placement Actions

- (void)placeSelection:(SVGraphicPlacement)placement;
{
    SVRichText *article = [[[self HTMLContext] page] article];
    NSMutableAttributedString *html = [[article attributedHTMLString] mutableCopy];
    
    SVWebEditorViewController *viewController = [self webEditorViewController];
    OBASSERT(viewController);
    
    for (SVGraphic *aGraphic in [[viewController graphicsController] selectedObjects])
    {
        // Remove from all pages
        [[aGraphic mutableSetValueForKey:@"sidebars"] removeAllObjects];
        
        // Insert at start of page
        NSAttributedString *graphicHTML = [NSAttributedString attributedHTMLStringWithGraphic:aGraphic];
        [[aGraphic textAttachment] setPlacement:[NSNumber numberWithInt:placement]];
        [html insertAttributedString:graphicHTML atIndex:0];
    }
    
    // Store html
    [article setAttributedHTMLString:html];
    [html release];
}

- (void)placeInline:(id)sender;
{
    [self placeSelection:SVGraphicPlacementInline];
}

- (void)placeAsCallout:(id)sender;
{
    [self placeSelection:SVGraphicPlacementCallout];
}

- (void)placeInSidebar:(id)sender;
{
    // Already there, so do nothing. Need to implement this otherwise view controller will have nowhere to send the message, and thus beep.
}

#pragma mark Insertion Actions

- (IBAction)insertPagelet:(id)sender;
{
    // Create element
    KTPage *page = [[self HTMLContext] page];
    if (!page) return NSBeep(); // pretty rare. #75495
    
    
    SVGraphic *pagelet = [SVGraphicFactory graphicWithActionSender:sender
                                    insertIntoManagedObjectContext:[page managedObjectContext]];
    
    
    // Insert it
    [pagelet willInsertIntoPage:page];
    
    // Place at end of the sidebar
    [[self pageletsController] addObject:pagelet];
    
    // Add to main controller too
    NSArrayController *controller = [[self webEditorViewController] graphicsController];
    
    BOOL selectInserted = [controller selectsInsertedObjects];
    [controller setSelectsInsertedObjects:YES];
    [controller addObject:pagelet];
    [controller setSelectsInsertedObjects:selectInserted];
}

#pragma mark Drop

/*  Similar to NSTableView's concept of dropping above a given row
 */
- (NSUInteger)indexOfDrop:(id <NSDraggingInfo>)dragInfo;
{
    NSUInteger result = NSNotFound;
    NSView *view = [[self HTMLElement] documentView];
    NSArray *pageletControllers = [self pageletDOMControllers];
    NSPoint location = [view convertPointFromBase:[dragInfo draggingLocation]];
    
    
    // Ideally, we're making a drop *before* a pagelet
    WEKWebEditorItem *previousItem = nil;
    NSUInteger i, count = [pageletControllers count];
    for (i = 0; i < count; i++)
    {
        // Calculate drop zone
        WEKWebEditorItem *anItem = [pageletControllers objectAtIndex:i];
        
        NSRect dropZone = [self rectOfDropZoneBelowDOMNode:[previousItem HTMLElement]
                                              aboveDOMNode:[anItem HTMLElement]
                                                    height:25.0f];
        
        
        // Is it a match?
        if ([view mouse:location inRect:dropZone])
        {
            result = i;
            break;
        }
        
        previousItem = anItem;
    }
    
    
    // If not, is it a drop *after* the last pagelet, or into an empty sidebar?
    if (result == NSNotFound)
    {
        NSRect dropZone = [self rectOfDropZoneInDOMElement:[self sidebarDivElement]
                                                 belowNode:[[pageletControllers lastObject] HTMLElement]
                                                 minHeight:25.0f];
        
        if ([view mouse:location inRect:dropZone])
        {
            result = [pageletControllers count];
        }
    }
    
    
    // There's nothing to do if the drop is same as source
    if (result != NSNotFound)
    {
        if ([dragInfo draggingSource] == [self webEditor])
        {
            NSArray *draggedItems = [[self webEditor] draggedItems];
            
            if (result >= 1 && [draggedItems containsObject:[pageletControllers objectAtIndex:result-1]])
            {
                result = NSNotFound;
            }
            else if (!(result >= [pageletControllers count]) &&
                     [draggedItems containsObject:[pageletControllers objectAtIndex:result]])
            {
                result = NSNotFound;
            }
        }
    }
    
    
    return result;
}

- (NSRect)rectOfDropZoneBelowDOMNode:(DOMNode *)node1
                        aboveDOMNode:(DOMNode *)node2
                              height:(CGFloat)height;
{
    OBPRECONDITION(node2);
    
    if (node1)
    {
        NSRect result = [self rectOfDropZoneAboveDOMNode:node2 height:25.0f];
        
        NSRect upperDropZone = [self rectOfDropZoneBelowDOMNode:node1
                                                         height:25.0f];
        result = NSUnionRect(upperDropZone, result);
        
        return result;
    }
    else
    {
        NSRect parentBox = [[node2 parentNode] boundingBox];
        NSRect nodeBox = [node2 boundingBox];
        
        CGFloat y = NSMinY(parentBox);
        NSRect result = NSMakeRect(NSMinX(nodeBox),
                                   y - 0.5*height,
                                   nodeBox.size.width,
                                   NSMinY(nodeBox) - y + height);
        
        return result;
    }
}

- (NSRect)rectOfDropZoneBelowDOMNode:(DOMNode *)node height:(CGFloat)height;
{
    NSRect nodeBox = [node boundingBox];
    
    // Claim the strip at the bottom of the node
    NSRect result = NSMakeRect(NSMinX(nodeBox),
                               NSMaxY(nodeBox) - 0.5*height,
                               nodeBox.size.width,
                               height);
    
    return result;
}

- (NSRect)rectOfDropZoneAboveDOMNode:(DOMNode *)node height:(CGFloat)height;
{
    NSRect nodeBox = [node boundingBox];
    
    NSRect result = NSMakeRect(NSMinX(nodeBox),
                               NSMinY(nodeBox) - 0.5*height,
                               nodeBox.size.width,
                               height);
    
    return result;
}

- (NSRect)rectOfDropZoneInDOMElement:(DOMElement *)element
                           belowNode:(DOMNode *)node
                           minHeight:(CGFloat)minHeight;
{
    //Normally equal to element's -boundingBox.
    NSRect result = [element boundingBox];
    
    
    //  But then shortened to only include the area below boundingBox
    if (node)
    {
        NSRect nodeBox = [node boundingBox];
        CGFloat nodeBottom = NSMaxY(nodeBox);
        
        result.size.height = NSMaxY(result) - nodeBottom;
        result.origin.y = nodeBottom;
    }
    
    
    //  Finally, expanded again to minHeight if needed.
    if (result.size.height < minHeight)
    {
        result = NSInsetRect(result, 0.0f, -0.5 * (minHeight - result.size.height));
    }
    
    
    return result;
}

- (NSArray *)registeredDraggedTypes;
{
    return [SVGraphicFactory graphicPasteboardTypes];
}

#pragma mark NSDraggingDestination

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    return [self draggingUpdated:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)dragInfo;
{
    NSDragOperation result = NSDragOperationNone;
    
    NSUInteger dropIndex = [self indexOfDrop:dragInfo];
    if (dropIndex != NSNotFound)
    {
        NSDragOperation mask = [dragInfo draggingSourceOperationMask];
        result = mask & NSDragOperationGeneric;
        if (!result) result = mask & NSDragOperationCopy;
        
        
        if (result)
        {
            // Place the drag caret to match the drop index
            NSArray *pageletControllers = [self pageletDOMControllers];
            if (dropIndex >= [pageletControllers count])
            {
                DOMNode *node = [[self sidebarDivElement] lastChild];
                DOMRange *range = [[node ownerDocument] createRange];
                [range setStartAfter:node];
                [[self webEditor] moveDragCaretToDOMRange:range];
                //[self moveDragCaretToAfterDOMNode:node];
            }
            else
            {
                WEKWebEditorItem *aPageletItem = [pageletControllers objectAtIndex:dropIndex];
                
                DOMRange *range = [[[aPageletItem HTMLElement] ownerDocument] createRange];
                [range setStartBefore:[aPageletItem HTMLElement]];
                [[self webEditor] moveDragCaretToDOMRange:range];
                //[self moveDragCaretToAfterDOMNode:[[aPageletItem HTMLElement] previousSibling]];
            }
        }
    }
    
    
    // Finish up
    if (result)
    {
        [[self webEditor] moveDragHighlightToDOMNode:[self sidebarDivElement]];
    }
    else
    {
        [self removeDragCaret];
        [[self webEditor] moveDragHighlightToDOMNode:nil];
    }
    
    return result;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self removeDragCaret];
    [[self webEditor] moveDragHighlightToDOMNode:nil];
    [[self webEditor] removeDragCaret];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)dragInfo;
{
    NSUInteger dropIndex = [self indexOfDrop:dragInfo];
    if (dropIndex == NSNotFound)
    {
        NSBeep();
        return NO;
    }
    
    
    BOOL result = NO;
    
    WEKWebEditorView *webEditor = [self webEditor];
    SVSidebarPageletsController *pageletsController = [self pageletsController];
    
    
    //  When dragging within the sidebar, want to move the selected pagelets
    if ([dragInfo draggingSource] == webEditor &&
        [dragInfo draggingSourceOperationMask] & NSDragOperationGeneric)
    {
        NSArray *sidebarPageletControllers = [self pageletDOMControllers];
        NSArray *graphicControllers = [[webEditor draggedItems] copy];
        
        for (SVDOMController *aPageletItem in graphicControllers)
        {
            if ([sidebarPageletControllers containsObjectIdenticalTo:aPageletItem])
            {
                result = YES;
                [webEditor forgetDraggedItems];
                
                SVGraphic *pagelet = [aPageletItem representedObject];
                [pageletsController
                 moveObject:pagelet toIndex:dropIndex];
            }
        }
        
        [graphicControllers release];
    }
    
    
    if (!result)
    {
        // Fallback to inserting a new pagelet from the pasteboard
        result = [pageletsController insertPageletsFromPasteboard:[dragInfo draggingPasteboard]
                                            atArrangedObjectIndex:dropIndex];
        
        
        if (result)
        {
            // Remove dragged items early since the WebView is about to refresh. If they came from an outside source has no effect
            if ([dragInfo draggingSourceOperationMask] & NSDragOperationGeneric)
            {
                [webEditor removeDraggedItems];
            }
            [webEditor didChangeText];  // -removeDraggedItems calls -shouldChangeText: etc. internally
        }
    }
    
    return result;
}

#pragma mark Drag Caret

- (void)removeDragCaret;
{
    // Schedule removal
    [[_dragCaret style] setHeight:@"0px"];
    
    [_dragCaret performSelector:@selector(ks_removeFromParentNode)
                     withObject:nil
                     afterDelay:0.25];
    
    [_dragCaret release]; _dragCaret = nil;
}

- (void)moveDragCaretToAfterDOMNode:(DOMNode *)node;
{
    // Do we actually need do anything?
    if (_dragCaret == node || [_dragCaret previousSibling] == node) return;
    
    
    [self removeDragCaret];
    
    OBASSERT(!_dragCaret);
    _dragCaret = [[[self HTMLElement] ownerDocument] createElement:@"div"];
    [_dragCaret retain];
    
    DOMCSSStyleDeclaration *style = [_dragCaret style];
    [style setWidth:@"100%"];
    [style setProperty:@"-webkit-transition-duration" value:@"0.25s" priority:@""];
    
    [[node parentNode] insertBefore:_dragCaret refChild:[node nextSibling]];
    [style setHeight:@"75px"];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sSVSidebarDOMControllerPageletsObservation)
    {
        [self setNeedsUpdate];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


#pragma mark -


@implementation WEKWebEditorItem (SVSidebarDOMController)

- (SVSidebarDOMController *)sidebarDOMController;
{
    return [[self parentWebEditorItem] sidebarDOMController];
}

@end



#pragma mark -


@implementation SVSidebar (SVSidebarDOMController)

- (SVDOMController *)newDOMController;
{
    return [[SVSidebarDOMController alloc] initWithRepresentedObject:self];
}

@end