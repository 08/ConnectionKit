//
//  WEKWebEditorView+Dragging.m
//  Sandvox
//
//  Created by Mike on 07/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import "WEKWebEditorView.h"
#import "WEKWebEditorItem.h"

#import "DOMNode+Karelia.h"
#import "NSColor+Karelia.h"


#define WEKDragImageAlpha 0.50f // name & value copied from WebKit
#define WebMaxDragImageSize NSMakeSize(200.0f, 200.f)


@interface WEKWebEditorView (DraggingPrivate)

// Dragging destination
- (void)removeDragCaretFromDOMNodes;

@end


#pragma mark -


@implementation WEKWebEditorView (Dragging)

#pragma mark Drag Types

/*  All this sort of stuff we really want to target the webview with
 */

- (void)registerForDraggedTypes:(NSArray *)pboardTypes
{
    [[self webView] registerForDraggedTypes:pboardTypes];
}

- (NSArray *)registeredDraggedTypes
{
    return [[self webView] registeredDraggedTypes];
}

- (void)unregisterDraggedTypes
{
    [[self webView] unregisterDraggedTypes];
}

#pragma mark Dragging Destination

- (void)moveDragHighlightToDOMNode:(DOMNode *)node
{
    if (node != _dragHighlightNode)
    {
        NSView *view = [self documentView];
        
        if (_dragHighlightNode)
        {
            WEKWebEditorItem *item = [[self rootItem] hitTestDOMNode:_dragHighlightNode];
            [view setNeedsDisplayInRect:[item boundingBox]];
        //[_dragHighlightNode setDocumentViewNeedsDisplayInBoundingBoxRect];
        }
        
        /*
         NSString *class = [(DOMHTMLElement *)_dragHighlightNode className];
        class = [class stringByReplacing:@" svx-dragging-destination-active" with:@""];
        [(DOMHTMLElement *)_dragHighlightNode setClassName:class];*/
        
        [_dragHighlightNode release];   _dragHighlightNode = [node retain];
        
        if (node)
        {
            WEKWebEditorItem *item = [[self rootItem] hitTestDOMNode:node];
            [view setNeedsDisplayInRect:[item boundingBox]];
        }
        
        /*
        class = [(DOMHTMLElement *)node className];
        class = [class stringByAppendingString:@" svx-dragging-destination-active"];
        [(DOMHTMLElement *)node setClassName:class];*/
    }
}

- (void)moveDragCaretToDOMRange:(DOMRange *)range;
{
    OBPRECONDITION(range);
    OBPRECONDITION([range collapsed]);
    
    
    // Dump the old caret
    [self removeDragCaretFromDOMNodes];
    
    // Draw new one
    OBASSERT(!_dragCaretDOMRange);
    _dragCaretDOMRange = [range copy];
    
    [self setNeedsDisplayInRect:[self rectOfDragCaret]];
}

- (void)removeDragCaret;
{
    //[[self webView] removeDragCaret]; — see -[WEKWebView draggingUpdated:] for why
    [self removeDragCaretFromDOMNodes];
}

// Support method that ignores any drag caret in the webview
- (void)removeDragCaretFromDOMNodes;
{
    [self setNeedsDisplayInRect:[self rectOfDragCaret]];
    
    [_dragCaretDOMRange release], _dragCaretDOMRange = nil;
}

#pragma mark Dragging Source

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    // Only support operations that all dragged items support.
    NSDragOperation result = NSDragOperationEvery;
    for (WEKWebEditorItem *anItem in [self draggedItems])
    {
        result = result & [anItem draggingSourceOperationMaskForLocal:isLocal];
    }
    
    return result;
}

- (void)draggedImage:(NSImage *)anImage beganAt:(NSPoint)aPoint
{
    // Hide the dragged items so it looks like a proper drag
    OBASSERT(!_draggedItems);
    _draggedItems = [[self selectedItems] copy];    // will redraw without selection borders
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation;
{
    if (operation == NSDragOperationMove || operation == NSDragOperationDelete)
    {
        [self removeDraggedItems];
        [self didChangeText];
    }
    
    // Clean up
    [self forgetDraggedItems];
}

- (NSArray *)draggedItems; { return _draggedItems; }

- (void)removeDraggedItems; // removes from DOM and item tree
{
    DOMRange *selection;
    
    if ([self draggedItems])
    {
        for (WEKWebEditorItem *anItem in [self draggedItems])
        {
            [anItem tryToRemove];
        }
        
        // Remove the objects
        [[self dataSource] webEditor:self deleteItems:[self draggedItems]];
        
        // Clean up
        [self forgetDraggedItems];
    }
    else if (selection = [self selectedDOMRange])
    {
        // The drag was initiated by WebView itself, so make it delete the dragged items
        // -shouldChangeTextInDOMRange: is needed since -delete: doesn't do so itself for some reason
        if ([self shouldChangeTextInDOMRange:selection])
        {
            [[self webView] delete:self];
        }
    }
}

- (void)forgetDraggedItems; // call if you want to take over handling of drag source
{
    [_draggedItems release]; _draggedItems = nil;
}

#pragma mark Drawing

- (void)drawDragCaretInView:(NSView *)view;
{
    if (_dragCaretDOMRange)
    {
        [[NSColor aquaColor] set];
        NSRect drawingRect = [view convertRect:[self rectOfDragCaret] fromView:self];
        NSRect outlineRect = NSInsetRect(drawingRect, 0.0f, 1.0f);
        NSEraseRect(outlineRect);
        NSRectFill(NSInsetRect(outlineRect, 0.0f, 1.0f));
    }
}

/*  When beginning a drag, you want to drag all the selected items. I haven't quite decided how to do this yet – one big image containing them all or an image for the item under the mouse and a numeric overlay? – so this is fairly temporary. Also return by reference the origin of the image within our own coordinate system.
 */
- (NSImage *)dragImageForSelectionFromItem:(WEKWebEditorItem *)item
                                  location:(NSPoint *)outImageLocation
{
    // The core items involved
    DOMElement *element = [item HTMLElement];
    NSRect box = [element boundingBox];
    
    
    // Scale down if needed
    if (box.size.width > 200 || box.size.height > 200)
    {
        if (box.size.height > box.size.width)
        {
            box = NSInsetRect(box,
                              0.5 * box.size.width - 100,
                              0.5 * box.size.height - 100);
        }
        else
        {
            box = NSInsetRect(box,
                              0.5 * box.size.width - 100,
                              0.5 * box.size.height - 100);
        }
    }
    
    
    // Get ready to draw
    NSSize size = box.size;
    size.height += 2.0f; size.width += 2.0f;    // expand by 1px to capture border
    NSImage *result = [[[NSImage alloc] initWithSize:size] autorelease];
    
    WebFrameView *frameView = [[[element ownerDocument] webFrame] frameView];
    NSView <WebDocumentView> *docView = [frameView documentView];
    
    
    // Try to capture straight from WebKit. This is a private method so may not always be available
    if ([element respondsToSelector:@selector(renderedImage)])
    {
        NSImage *elementImage = [element performSelector:@selector(renderedImage)];
        if (elementImage)
        {
            [result lockFocus];
            
            [elementImage drawInRect:NSMakeRect(1.0f, 1.0f, box.size.width, box.size.height)        
                            fromRect:NSZeroRect
                           operation:NSCompositeCopy
                            fraction:WEKDragImageAlpha];
            
            NSRect drawingRect; drawingRect.origin = NSZeroPoint; drawingRect.size = size;
            [[[NSColor grayColor] colorWithAlphaComponent:WEKDragImageAlpha] setFill];
            NSFrameRect(drawingRect);
            
            [result unlockFocus];
        }
    }
    
    
    // Otherwise, fall back to caching display. Don't forget to be semi-transparent!
    if (!result)
    {
        NSRect imageDrawingRect = [frameView convertRect:box fromView:docView];
        NSBitmapImageRep *bitmap = [frameView bitmapImageRepForCachingDisplayInRect:imageDrawingRect];
        [frameView cacheDisplayInRect:imageDrawingRect toBitmapImageRep:bitmap];
        
        NSImage *image = [[NSImage alloc] initWithSize:box.size];
        [image addRepresentation:bitmap];
        
        [result lockFocus];
        [image drawAtPoint:NSZeroPoint
                  fromRect:NSZeroRect
                 operation:NSCompositeCopy
                  fraction:WEKDragImageAlpha];
        [result unlockFocus];
        
        [image release];
    }
    
    
    // Also return rect if requested
    if (result && outImageLocation)
    {
        NSRect imageRect = [self convertRect:box fromView:docView];
        *outImageLocation = imageRect.origin;
    }
    
    
    return result;
}

#pragma mark Layout

/*  These 2 methods should one day probably be additions to DOMNode
 */

- (DOMNode *)_previousVisibleSibling:(DOMNode *)node
{
    DOMNode *result = node;
    while (result)
    {
        if (NSIsEmptyRect([result boundingBox]))
        {
            result = [result previousSibling];
        }
        else
        {
            break;
        }
    }
    
    return result;
}

- (DOMNode *)_nextVisibleSibling:(DOMNode *)node
{
    DOMNode *result = node;
    while (result)
    {
        if (NSIsEmptyRect([result boundingBox]))
        {
            result = [result nextSibling];
        }
        else
        {
            break;
        }
    }
    
    return result;
}


- (NSRect)rectOfDragCaret;
{
    DOMNodeList *childNodes = [[_dragCaretDOMRange startContainer] childNodes];
    
    
    //  Try to place between the 2 visible nodes
    DOMNode *node1 = [self _previousVisibleSibling:[childNodes item:([_dragCaretDOMRange startOffset] - 1)]];
    DOMNode *node2 = [self _previousVisibleSibling:[childNodes item:[_dragCaretDOMRange startOffset]]];
    
    NSRect box1 = [node1 boundingBox];
    NSRect box2 = [node2 boundingBox];
    
    
    //  If they don't both exist, have to tweak drawing model
    NSRect result;
    if (node1 && node2)
    {
        result.origin.x = MIN(NSMinX(box1), NSMinX(box2));
        result.origin.y = NSMaxY(box1);
        result.size.width = MAX(NSMaxX(box1), NSMaxX(box2)) - result.origin.x;
        result.size.height = NSMinY(box2) - result.origin.y;
    }
    else if (node1)
    {
        result = box1;  result.origin.y += result.size.height,  result.size.height = 0.0f;
    }
    else if (node2)
    {
        result = box2;  result.size.height = 0.0f;
    }
    else
    {
        result = [[_dragCaretDOMRange startContainer] boundingBox];
        result.size.height = 0.0f;
    }
    
    
    // It should be at least 7 pixels tall
    if (result.size.height < 7.0)
    {
        result = NSInsetRect(result, 0.0f, -0.5 * (7.0 - result.size.height));
    }
    
    
    return [self convertRect:result fromView:[[_dragCaretDOMRange commonAncestorContainer] documentView]];
}

@end


#pragma mark -


@implementation NSView (WEKWebEditorViewExtras)

- (void)dragImageForItem:(WEKWebEditorItem *)item
                   event:(NSEvent *)event
              pasteboard:(NSPasteboard *)pasteboard 
                  source:(id)source;
{
    NSPoint mouseDownPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    NSImage *dragImage;
    NSPoint origin;
    
    DOMElement *element = [item HTMLElement];
    NSImage *image = [element image];
    if (!image) image = [element performSelector:@selector(renderedImage)];
    
        NSRect rect = [element boundingBox];
        NSSize originalSize = rect.size;
        origin = rect.origin;
        
    dragImage = [[image copy] autorelease];
    [dragImage setScalesWhenResized:YES];
    [dragImage setSize:originalSize];
    
    
    // Scale down to fit 200px box, making semi-transparent in the process
    NSSize newSize = originalSize;
    if (newSize.width > WebMaxDragImageSize.width || newSize.height > WebMaxDragImageSize.height)
    {
        if (newSize.height > newSize.width)
        {
            newSize.width = newSize.width * (WebMaxDragImageSize.height / newSize.height);
            newSize.height = WebMaxDragImageSize.height;
        }
        else
        {
            newSize.height = newSize.height * (WebMaxDragImageSize.width / newSize.width);
            newSize.width = WebMaxDragImageSize.width;
        }
    }
    
    
    // Get ready to draw
    NSSize imgSize = newSize;
    imgSize.height += 2.0f; imgSize.width += 2.0f;    // expand by 1px to capture border
    NSImage *result = [[[NSImage alloc] initWithSize:imgSize] autorelease];
    
    [result lockFocus];
    
    
    // Draw the image
    [image drawInRect:NSMakeRect(1.0f, 1.0f, newSize.width, newSize.height)        
             fromRect:NSZeroRect
            operation:NSCompositeCopy
             fraction:WEKDragImageAlpha];
    
    
    // Draw image border
    NSRect drawingRect; drawingRect.origin = NSZeroPoint; drawingRect.size = imgSize;
    [[[NSColor grayColor] colorWithAlphaComponent:WEKDragImageAlpha] setFill];
    NSFrameRect(drawingRect);
    
    
    // Finish drawing
    [result unlockFocus];
    dragImage = result;
    
    
    // Properly orient the drag image and orient it differently if it's smaller than the original
    origin.x = mouseDownPoint.x - (((mouseDownPoint.x - origin.x) / originalSize.width) * newSize.width);
    origin.y = origin.y + originalSize.height;
    origin.y = mouseDownPoint.y - (((mouseDownPoint.y - origin.y) / originalSize.height) * newSize.height);
    
    [self dragImage:dragImage at:origin offset:NSZeroSize event:event pasteboard:pasteboard source:source slideBack:YES];
}

@end
