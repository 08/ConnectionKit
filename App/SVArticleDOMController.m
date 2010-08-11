//
//  SVArticleDOMController.m
//  Sandvox
//
//  Created by Mike on 28/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVArticleDOMController.h"

#import "SVAttributedHTML.h"
#import "SVCalloutDOMController.h"
#import "SVGraphicFactory.h"
#import "SVSidebarPageletsController.h"
#import "SVTextAttachment.h"
#import "SVWebEditorViewController.h"
#import "KTPage.h"

#import "KSWebLocation.h"

#import "NSArray+Karelia.h"
#import "NSResponder+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"


@interface DOMElement (SVParagraphedHTMLWriter)
- (DOMNodeList *)getElementsByClassName:(NSString *)name;
@end


#pragma mark -


@implementation SVArticleDOMController

- (void)dealloc
{
    [_earlyCalloutController release];
    
    [super dealloc];
}

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    [super loadHTMLElementFromDocument:document];
    
    
    // Text element is the kBlock
    id textElement = [[[self HTMLElement] getElementsByClassName:@"kBlock"] item:0];
    [self setTextHTMLElement:textElement];
    
    
    // Also guess at callout controller
    WEKWebEditorItem *parent = [self parentWebEditorItem];
    NSUInteger index = [[parent childWebEditorItems] indexOfObjectIdenticalTo:self];
    if (index >= 1)
    {
        WEKWebEditorItem *calloutController = [[self childWebEditorItems] firstObjectKS];
        if ([calloutController isKindOfClass:[SVCalloutDOMController class]])
        {
            // Early callouts are those which appear outside our subtree. Have to ensure controller's element is loaded first
            if (![calloutController isHTMLElementCreated])
            {
                [calloutController loadHTMLElementFromDocument:document];
            }
            
            if (![[calloutController HTMLElement] ks_isDescendantOfElement:[self HTMLElement]])
            {
                [self setEarlyCalloutDOMController:(SVCalloutDOMController *)calloutController];
            }
        }
    }
}

#pragma mark Properties

- (BOOL)allowsPagelets; { return YES; }

- (IBAction)insertPagelet:(id)sender;
{
    NSManagedObjectContext *context = [[self representedObject] managedObjectContext];
    
    SVGraphic *graphic = [SVGraphicFactory graphicWithActionSender:sender
                                           insertIntoManagedObjectContext:context];
    
    [graphic willInsertIntoPage:[[self HTMLContext] page]];
    [self addGraphic:graphic placeInline:NO];
}

#pragma mark Callouts

@synthesize earlyCalloutDOMController = _earlyCalloutController;

- (void)willWriteText:(SVParagraphedHTMLWriter *)writer;
{
    // Write early callouts first
    SVCalloutDOMController *calloutController = [self earlyCalloutDOMController];
    if (calloutController)
    {
        [self write:writer
         DOMElement:[calloutController HTMLElement]
               item:calloutController];
    }
    
    
    
    [super willWriteText:writer];
}

#pragma mark Insertion

- (BOOL)insertGraphics:(NSArray *)graphics beforeDOMNode:(DOMNode *)refNode;
{
    BOOL result = NO;
    
    
    // Insert into text
    if ([graphics count])
    {
        DOMRange *range = [[[self HTMLElement] ownerDocument] createRange];
        if (refNode)
        {
            [range setStartBefore:refNode];
        }
        else
        {
            [range setStart:[self textHTMLElement] offset:[[[self textHTMLElement] childNodes] length]];
        }
        
        for (SVGraphic *aGraphic in graphics)
        {
            // Give pagelet a chance to resize etc.
            [aGraphic willInsertIntoPage:[[self HTMLContext] page]];
            
            
            [self insertGraphic:aGraphic range:range];
        }
        
        
        result = YES;
    }
    
    
    return result;
}

- (BOOL)webEditorTextShouldInsertNode:(DOMNode *)node
                    replacingDOMRange:(DOMRange *)range
                          givenAction:(WebViewInsertAction)action;
{
    // When moving an inline element, want to actually do that move
    
    BOOL result = YES;
    
    
    WEKWebEditorView *webEditor = [self webEditor];
    NSPasteboard *pasteboard = [webEditor insertionPasteboard];
    if (pasteboard)
    {
        // Prepare to write HTML
        NSMutableString *editingHTML = [[NSMutableString alloc] init];
        OBASSERT(!_changeHTMLContext);
        _changeHTMLContext = [[SVWebEditorHTMLContext alloc] initWithOutputWriter:editingHTML
                                                               inheritFromContext:[self HTMLContext]];
        
        
        // Try to de-archive custom HTML
        NSAttributedString *attributedHTML = [NSAttributedString
                                              attributedHTMLStringFromPasteboard:pasteboard
                                              insertAttachmentsIntoManagedObjectContext:[[self representedObject] managedObjectContext]];
        
        if (attributedHTML)
        {
            // Generate HTML for the DOM
            [_changeHTMLContext writeAttributedHTMLString:attributedHTML];
        }
        
        
        
        
        // Insert HTML into the DOM
        if ([editingHTML length])
        {
            DOMHTMLDocument *domDoc = (DOMHTMLDocument *)[node ownerDocument];
            
            DOMDocumentFragment *fragment = [domDoc
                                             createDocumentFragmentWithMarkupString:editingHTML
                                             baseURL:nil];
            
            [[node mutableChildDOMNodes] removeAllObjects];
            [node appendChildNodes:[fragment childNodes]];
            
            
            // Remove source dragged items if they came from us. No need to call -didChangeText as the insertion will do that
            [webEditor removeDraggedItems];
        }
        
        [editingHTML release];
    }
    
    
    // Pretend we Inserted nothing. MUST supply empty text node otherwise WebKit interprets as a paragraph break for some reason
    if (!result)
    {
        [[node mutableChildDOMNodes] removeAllObjects];
        [node appendChild:[[node ownerDocument] createTextNode:@""]];
        result = YES;
    }
    
    if (result) result = [super webEditorTextShouldInsertNode:node replacingDOMRange:range givenAction:action];
    return result;
}

#pragma mark Placement

- (void)moveToBlockLevel:(id)sender;
{
    // It's a bit of a tricky manoeuvre. Want to pull the graphic back to the start of its paragraph
    
    
    WEKWebEditorView *webEditor = [self webEditor];
    if ([webEditor shouldChangeText:self])
    {
        // Move graphic back to be top-level. Finding the right element to operate on can be a little tricky. Normally it's the controller's own node, but in the case of callouts, want to operate on the callout, not element. #83445
        WEKWebEditorItem *controller = [webEditor selectedItem];
        while ([controller parentWebEditorItem] != self)
        {
            controller = [controller parentWebEditorItem];
        }
        
        DOMElement *element = [controller HTMLElement];
        DOMNode *parent = [element parentNode];
        
        while (parent != [self textHTMLElement])
        {
            [[parent parentNode] insertBefore:element refChild:parent];
            parent = [element parentNode];
        }
        
        // Push the change to the model ready for the update to pick it up
        [webEditor didChangeText];
    }
}

- (IBAction)placeInline:(id)sender;    // tells all selected graphics to become placed as block
{
    SVWebEditorViewController *viewController = [self webEditorViewController];
    OBASSERT(viewController);
    
    for (SVGraphic *aGraphic in [[viewController graphicsController] selectedObjects])
    {
        SVGraphicPlacement placement = [[aGraphic placement] integerValue];
        switch (placement)
        {
            case SVGraphicPlacementCallout:
                // The graphic be transformed on the spot. #79017
                [[aGraphic textAttachment] setPlacement:[NSNumber numberWithInt:SVGraphicPlacementInline]];
                break;
                
            case SVGraphicPlacementInline:
                // Nothing to do
                break;
                
            default:
                // er, what on earth is it then?
                NSBeep();
        }
    }
}

- (IBAction)placeAsCallout:(id)sender;
{
    // Can't have any inline elements
    [self moveToBlockLevel:sender];
    
    
    SVWebEditorViewController *viewController = [self webEditorViewController];
    OBASSERT(viewController);
    
    for (SVGraphic *aGraphic in [[viewController graphicsController] selectedObjects])
    {        
        SVGraphicPlacement placement = [[aGraphic placement] integerValue];
        switch (placement)
        {
            case SVGraphicPlacementCallout:
                break;
                
            case SVGraphicPlacementInline:
                [[aGraphic textAttachment] setPlacement:[NSNumber numberWithInt:SVGraphicPlacementCallout]];
                break;
        
            default:
                // er, what on earth is it then?
                NSBeep();
        }
    }
}

- (IBAction)placeInSidebar:(id)sender;
{
    // Insert copies into sidebar
    SVWebEditorHTMLContext *context = [self HTMLContext];
    SVSidebarPageletsController *sidebarController = [context sidebarPageletsController];
    SVWebEditorViewController *viewController = [self webEditorViewController]; OBASSERT(viewController);
    NSArrayController *graphicsController = [viewController graphicsController];
    
    NSArray *graphics = [graphicsController selectedObjects];
    NSMutableArray *sidebarPagelets = [[NSMutableArray alloc] initWithCapacity:[graphics count]];
    
    for (SVGraphic *aGraphic in graphics)
    {
        // Serialize
        id serializedPagelet = [aGraphic serializedProperties];
        
        // Deserialize into controller
        SVGraphic *pagelet = [sidebarController addObjectFromSerializedPagelet:serializedPagelet];
        if (pagelet) [sidebarPagelets addObject:pagelet];
    }
    
    
    // Remove originals. For some reason -delete: does not fire change notifications
    [[self webEditor] deleteForward:self];
    
    
    // Update selection
    BOOL selectInserted = [graphicsController selectsInsertedObjects];
    [graphicsController setSelectsInsertedObjects:YES];
    [graphicsController addObjects:sidebarPagelets];
    [graphicsController setSelectsInsertedObjects:selectInserted];
    
    [sidebarPagelets release];
}


#pragma mark Other Actions

- (void)paste:(id)sender;
{
    // Normally WebView should handle the paste. But we want control of pagelet pastes
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    if (![[pboard types] containsObject:kSVGraphicPboardType])
    {
        return [[self webEditor] forceWebViewToPerform:_cmd withObject:sender];
    }
    
    
    // Insert deserialized pagelet from pboard
    NSManagedObjectContext *moc = [[self representedObject] managedObjectContext];
    
    NSArray *attachments = [SVTextAttachment textAttachmentsFromPasteboard:pboard
                                            insertIntoManagedObjectContext:moc];
    NSArray *pagelets = [attachments valueForKey:@"graphic"];
    
    
    // Insert pagelets into text
    DOMNode *refNode = [[[self webEditor] selectedDOMRange] ks_startNode:NULL];
    
    if ([[self webEditor] shouldChangeText:self] &&
        [self insertGraphics:pagelets beforeDOMNode:refNode])
    {
        [[self webEditor] didChangeText];
    }
    else
    {
        NSBeep();
    }
}

#pragma mark Dragging Destination

- (DOMNode *)childForDraggingInfo:(id <NSDraggingInfo>)sender;
{
    DOMElement *element = [self textHTMLElement];
    NSPoint location = [[element documentView] convertPointFromBase:[sender draggingLocation]];
    
    DOMTreeWalker *treeWalker = [[element ownerDocument] createTreeWalker:element
                                                               whatToShow:DOM_SHOW_ELEMENT
                                                                   filter:nil
                                                   expandEntityReferences:NO];
    
    DOMNode *aNode = [treeWalker firstChild];
    while (aNode)
    {
        NSRect bounds = [aNode boundingBox];
        CGFloat mid = NSMidY(bounds);
        
        if (location.y < mid)
        {
            // We've found our target, but dissallow it if won't cause any result
            WEKWebEditorView *webEditor = [self webEditor];
            if ([sender draggingSource] == webEditor)
            {
                for (WEKWebEditorItem *anItem in [webEditor draggedItems])
                {
                    DOMHTMLElement *anItemElement = [anItem HTMLElement];
                    if (aNode == anItemElement || [treeWalker previousSibling] == anItemElement)
                    {
                        aNode = (id)[NSNull null];  // ugly, I know
                        break;
                    }
                }
            }
            
                  
            return aNode;
        }
        
        aNode = [treeWalker nextSibling];
    }
    
    
    // No match was found, so insert at end. But if the end is a <BR>, use that!
    DOMElement *result = (DOMElement *)[treeWalker currentNode];
    if (![[result tagName] isEqualToString:@"BR"]) result = nil; 
        
    return result;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    return [self draggingUpdated:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
{
    // Ignore drags originating in our own WebView
    NSDragOperation result = NSDragOperationNone;
    
    id source = [sender draggingSource];
    if ([source isKindOfClass:[NSResponder class]])
    {
        WEKWebEditorView *webEditor = [self webEditor];
        
        if (source != webEditor && [webEditor ks_followsResponder:source]) 
        {
            return result;
        }
    }
    
    
    DOMNode *aNode = [self childForDraggingInfo:sender];
    if ((id)aNode == [NSNull null]) return NSDragOperationNone;
    
    
    // What action to take though?
    NSDragOperation mask = [sender draggingSourceOperationMask];
    if ([sender draggingSource] == [self webEditor])
    {
        result = mask & NSDragOperationGeneric;
    }
    
    if (!result) result = mask & NSDragOperationCopy;
    if (!result) result = mask & NSDragOperationGeneric;
    
    if (result) 
    {
        [self moveDragCaretToBeforeDOMNode:aNode draggingInfo:sender];
        [[self webEditor] moveDragHighlightToDOMNode:[self dropOutlineDOMElement]];
    }
    
    
    if (!result)
    {
        [self removeDragCaret];
        [[self webEditor] moveDragHighlightToDOMNode:nil];
    }
        
    return result;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self removeDragCaret];
    [[self webEditor] removeDragCaret];
    [[self webEditor] moveDragHighlightToDOMNode:nil];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)dragInfo;
{
    BOOL result = NO;
    
    
    // Insert serialized graphic from the pasteboard
    NSManagedObjectContext *moc = [[self representedObject] managedObjectContext];
    NSPasteboard *pasteboard = [dragInfo draggingPasteboard];
    
    NSArray *attachments = [SVTextAttachment textAttachmentsFromPasteboard:pasteboard
                                            insertIntoManagedObjectContext:moc];
    NSArray *pagelets = [attachments valueForKey:@"graphic"];
    
    
    // Fallback to generic pasteboard support
    if ([pagelets count] < 1)
    {
        pagelets = [SVGraphicFactory graphicsFomPasteboard:pasteboard
                            insertIntoManagedObjectContext:moc];
        
        // Prep them. #79398
        for (SVGraphic *aPagelet in pagelets)
        {
            [aPagelet setShowsTitle:NO];
        }
    }
    
    
    // Insert HTML into DOM, using caret if possible
    if ([[self webEditor] shouldChangeText:self])
    {
        DOMNode *node = [self childForDraggingInfo:dragInfo];
        [self moveDragCaretToBeforeDOMNode:node draggingInfo:dragInfo];
        
        if (result = [self insertGraphics:pagelets beforeDOMNode:node])
        {
            // Remove source too?
            NSDragOperation mask = [dragInfo draggingSourceOperationMask];
            if (mask & NSDragOperationMove | mask & NSDragOperationGeneric)
            {
                [[self webEditor] removeDraggedItems];
            }
            
            [[self webEditor] didChangeText];
        }
    }
    
    
    
    
    return result;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;
{
    [self removeDragCaret];
    [[self webEditor] moveDragHighlightToDOMNode:nil];
    [[self webEditor] removeDragCaret];
}

- (NSArray *)registeredDraggedTypes;
{
    NSMutableSet *result = [[NSMutableSet alloc] initWithArray:
                            [SVGraphicFactory graphicPasteboardTypes]];
    
    [result addObjectsFromArray:[NSAttributedString attributedHTMStringPasteboardTypes]];
    [result addObject:kSVGraphicPboardType];
    
    // Weed out string and image types since we want Web Editor to handle them.
    [result minusSet:
     [NSSet setWithArray:[NSImage imageUnfilteredPasteboardTypes]]];
    [result removeObject:NSStringPboardType];
    [result removeObject:WebArchivePboardType];
    [result removeObject:NSHTMLPboardType];
    [result removeObject:NSRTFDPboardType];
    [result removeObject:NSRTFPboardType];
    
                      

    
    NSArray *result2 = [result allObjects];
    [result release];
    return result2;
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

- (void)moveDragCaretToBeforeDOMNode:(DOMNode *)node draggingInfo:(id <NSDraggingInfo>)dragInfo;
{
    DOMRange *range = [[[self HTMLElement] ownerDocument] createRange];
    if (node)
    {
        [range setStartBefore:node];
    }
    else
    {
        [range setStartAfter:[[self textHTMLElement] lastChild]];
    }
    
    [[self webEditor] moveDragCaretToDOMRange:range];
    return;
    
    
    // Do we actually need do anything?
    if (node)
    {
        if (node == _dragCaret || [_dragCaret nextSibling] == node) return;
    }
    else
    {
        if ([[self textHTMLElement] lastChild] == node) return;
    }
    
    
    [self removeDragCaret];
    
    // Create rough approximation of a pagelet
    OBASSERT(!_dragCaret);
    _dragCaret = [[[self HTMLElement] ownerDocument] createElement:@"div"];
    [_dragCaret retain];
    [_dragCaret setAttribute:@"class" value:@"pagelet wide center untitled"];
    
    DOMCSSStyleDeclaration *style = [_dragCaret style];
    [style setMarginTop:@"0px"];
    [style setMarginBottom:@"0px"];
    [style setPaddingTop:@"0px"];
    [style setPaddingBottom:@"0px"];
    
    [style setProperty:@"-webkit-transition-duration" value:@"0.25s" priority:@""];
    
    [[self textHTMLElement] insertBefore:_dragCaret refChild:node];
    
    NSNumber *height = [NSNumber numberWithFloat:[[dragInfo draggedImage] size].height];
    [style setHeight:[NSString stringWithFormat:@"%@px", height]];
}

- (void)replaceDragCaretWithHTMLString:(NSString *)html;
{
    OBASSERT(_dragCaret);
    
    [(DOMHTMLElement *)_dragCaret setOuterHTML:html];
    
    [_dragCaret release]; _dragCaret = nil;
}

- (DOMElement *)dropOutlineDOMElement;
{
    return [self HTMLElement];
    return [[[self HTMLElement] ownerDocument] getElementById:@"main-content"];
}

#pragma mark Hit-Test

- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node
{
    // Early callout controller sits outside our HTML element, so test it specially
    WEKWebEditorItem *result = [[self earlyCalloutDOMController] hitTestDOMNode:node];
    
    if (!result)
    {
        result = [super hitTestDOMNode:node];
    }
    
    return result;
}

@end


@implementation SVArticle (SVArticleDOMController)

- (SVDOMController *)newDOMController;
{
    SVTextDOMController *result = [[SVArticleDOMController alloc] initWithRepresentedObject:self];
    [result setRichText:YES];
    
    return result;
}

@end

