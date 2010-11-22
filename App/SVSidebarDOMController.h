//
//  SVSidebarDOMController.h
//  Sandvox
//
//  Created by Mike on 07/05/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVDOMController.h"

#import "SVSidebarPageletsController.h"


@class SVGraphicDOMController;

@interface SVSidebarDOMController : SVDOMController
{
  @private
    DOMElement  *_sidebarDiv;
    DOMElement  *_contentElement;
    
    NSArray                     *_DOMControllers;
    SVSidebarPageletsController *_pageletsController;
    
    // Drag & Drop
    DOMElement  *_dragCaret;
    BOOL        _drawAsDropTarget;
}

- (id)initWithPageletsController:(SVSidebarPageletsController *)pageletsController;

@property(nonatomic, retain) DOMElement *sidebarDivElement;
@property(nonatomic, retain) DOMElement *contentDOMElement;

@property(nonatomic, copy) NSArray *pageletDOMControllers;
@property(nonatomic, retain, readonly) SVSidebarPageletsController *pageletsController;


#pragma mark Drop
- (NSUInteger)indexOfDrop:(id <NSDraggingInfo>)dragInfo;

- (void)removeDragCaret;
- (void)moveDragCaretToAfterDOMNode:(DOMNode *)node;


#pragma mark Moving

- (void)moveGraphicWithDOMController:(SVGraphicDOMController *)graphicController
                          toPosition:(CGPoint)position
                               event:(NSEvent *)event;

- (void)moveObjectUp:(id)sender;
- (void)moveObjectDown:(id)sender;

@end


#pragma mark -


@interface WEKWebEditorItem (SVSidebarDOMController)
- (SVSidebarDOMController *)sidebarDOMController;
@end


