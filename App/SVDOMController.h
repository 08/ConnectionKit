//
//  SVDOMController.h
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "WebEditingKit.h"

#import "SVContentObject.h"
#import "SVHTMLContext.h"


@class SVWebEditorHTMLContext, KSObjectKeyPathPair, SVWebEditorViewController, SVGraphic, SVSizeBindingDOMController;
@protocol SVDOMControllerRepresentedObject;


@interface SVDOMController : WEKWebEditorItem
{
  @private
    // Loading
    NSString    *_elementID;
    
    // Updating
    NSMutableSet            *_updateSelectors;
    NSMutableSet            *_dependencies;
    BOOL                    _isObservingDependencies;
    SVWebEditorHTMLContext  *_context;
    
    // Dragging
    NSArray *_dragTypes;
}

#pragma mark Creating a DOM Controller

//  1.  Calls -initWithElementIdName: with the result of [content elementIdName]. Subs in a custom ID if the content provides nil
//  2.  Set content as .representedObject
- (id)initWithRepresentedObject:(id <SVDOMControllerRepresentedObject>)content;

- (SVSizeBindingDOMController *)newSizeBindingControllerWithRepresentedObject:(id)object;


#pragma mark Hierarchy
- (WEKWebEditorItem *)itemForDOMNode:(DOMNode *)node;


#pragma mark Content

//  Asks content object to locate node in the DOM, then stores it as receiver's .HTMLElement. Removes the element's ID attribute from the DOM if it's only there for editing support (so as to keep the Web Inspector tidy)
- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
@property(nonatomic, copy) NSString *elementIdName;

@property(nonatomic, retain, readwrite) SVWebEditorHTMLContext *HTMLContext;


#pragma mark Updating
- (BOOL)canUpdate;  // default is [self respondsToSelector:@selector(update)]
- (void)didUpdateWithSelector:(SEL)selector;    // you MUST call this after updating


#pragma mark Marking for Update

// If the receiver supports updating itself (-canUpdate), schedules an update with -setNeedsUpdateWithSelector:
// Otherwise, proceeds up the hierarchy looking for a controller that does support updating
- (void)setNeedsUpdate;

// Direct action to schedule a selector on next runloop pass
- (void)setNeedsUpdateWithSelector:(SEL)selector;

@property(nonatomic, readonly) BOOL needsUpdate;    // have any updates been registered?
- (BOOL)needsToUpdateWithSelector:(SEL)selector;    // has a specific selector been registered?

- (void)updateIfNeeded; // recurses down the tree


#pragma mark Dependencies
@property(nonatomic, copy, readonly) NSSet *dependencies;
- (void)addDependency:(KSObjectKeyPathPair *)pair;
- (void)removeAllDependencies;
- (BOOL)isObservingDependencies;


#pragma mark Resizing
- (NSSize)minSize;
- (CGFloat)maxWidth;
- (void)resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle snapToFit:(BOOL)snapToFit;
- (unsigned int)resizingMaskForDOMElement:(DOMElement *)element;    // support


#pragma mark Dragging
- (void)registerForDraggedTypes:(NSArray *)newTypes;
- (void)unregisterDraggedTypes;
- (NSArray *)registeredDraggedTypes;


@end


#pragma mark -


@protocol SVDOMControllerRepresentedObject <NSObject>

//  A subclass of SVDOMController that the WebEditor will create and maintain in order to edit the object. The default is a vanilla SVDOMController.
//  I appreciate this slightly crosses the MVC divide, but the important thing is that the receiver never knows about any _specific_ controller, just the class involved.
- (SVDOMController *)newDOMController;

// The returned ID should be suitable for using as a DOMElement's ID attribute. It should be unique for the page being generated. The default implementation is based upon the receiver's location in memory, as it is assumed that the object will be retained for the duration of the editing cycle. Subclasses can override to specify a different ID format, perhaps because the object will already generate a unique ID as part of its HTML.
- (NSString *)elementIdName;

// Default is NO. Override if you want it to be published.
- (BOOL)shouldPublishEditingElementID;

@end


// And provide a base implementation of the protocol:
@interface SVContentObject (SVDOMController) <SVDOMControllerRepresentedObject>
@end


#pragma mark -


/*  We want all Web Editor items to be able to handle updating in some form, just not necessarily the full complexity of it.
*/

@interface WEKWebEditorItem (SVDOMController)

#pragma mark DOM
- (void)loadHTMLElementFromDocument:(DOMDocument *)document;    // does nothing


#pragma mark Updating
- (SVWebEditorViewController *)webEditorViewController;
- (void)setNeedsUpdate; // pass up to parent
- (void)updateIfNeeded; // recurses down the tree
- (SVWebEditorHTMLContext *)HTMLContext;


#pragma mark Dependencies
- (void)startObservingDependencies; // recursive
- (void)stopObservingDependencies;  // recursive


#pragma mark Drag & Drop
- (NSArray *)registeredDraggedTypes;


@end
