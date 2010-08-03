//
//  WEKWebEditorItem.h
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import "WEKDOMController.h"
#import "SVSelectionBorder.h"


@class WEKWebEditorView;


@interface WEKWebEditorItem : WEKDOMController
{
  @private
    // Tree
    NSArray             *_childControllers;
    WEKWebEditorItem    *_parentController; // weak ref
    
    BOOL    _selected;
    BOOL    _editing;
}

@property(nonatomic, assign, readonly) WEKWebEditorView *webEditor;  // NOT KVO-compliant


#pragma mark Tree

@property(nonatomic, copy) NSArray *childWebEditorItems;
@property(nonatomic, assign, readonly) WEKWebEditorItem *parentWebEditorItem;

- (void)addChildWebEditorItem:(WEKWebEditorItem *)controller;
- (void)replaceChildWebEditorItem:(WEKWebEditorItem *)oldItem with:(WEKWebEditorItem *)newItem;
- (void)removeFromParentWebEditorItem;

- (void)itemWillMoveToParentWebEditorItem:(WEKWebEditorItem *)newParentItem;
- (void)itemDidMoveToParentWebEditorItem;

- (NSEnumerator *)enumerator;


#pragma mark Selection

- (BOOL)isSelectable;   // convenience for -selectableDOMElement
- (DOMElement *)selectableDOMElement;   // default is nil. Subclass for more complexity, shouldn't worry about KVO
- (unsigned int)resizingMask;

@property(nonatomic, getter=isSelected) BOOL selected;  // draw selection handles & outline when YES
@property(nonatomic, getter=isEditing) BOOL editing;    // draw outline when YES

- (void)updateToReflectSelection;
- (BOOL)allowsDirectAccessToWebViewWhenSelected;

- (NSArray *)selectableAncestors;   // Search up the tree for all parent items returning YES for -isSelectable
- (NSArray *)selectableTopLevelDescendants;


#pragma mark Searching the Tree
- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node;  // like -[NSView hitTest:]
- (WEKWebEditorItem *)hitTestRepresentedObject:(id)object;


#pragma mark Editing
// Feels like somewhat of a hack: removes item from tree, asking enclosing text for permission
- (BOOL)tryToRemove;


#pragma mark Drag Source
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)flag;


#pragma mark Resizing
- (unsigned int)resizingMask;   // default is 0
- (SVGraphicHandle)resizeByMovingHandle:(SVGraphicHandle)handle toPoint:(NSPoint)point;


#pragma mark Layout
- (NSRect)boundingBox;  // like -[DOMNode boundingBox] but performs union with subcontroller boxes
- (NSRect)rect;
- (NSRect)drawingRect;  // expressed in our DOM node's document view's coordinates


#pragma mark Drawing
// dirtyRect is expressed in the view's co-ordinate system. view is not necessarily the context being drawn into (but generally is)
- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;

- (SVSelectionBorder *)newSelectionBorder;


#pragma mark Debugging
- (NSString *)descriptionWithIndent:(NSUInteger)level;
- (NSString *)blurb;


@end
