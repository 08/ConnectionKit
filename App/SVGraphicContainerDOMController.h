//
//  SVGraphicContainerDOMController.h
//  Sandvox
//
//  Created by Mike on 23/11/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SVGraphicDOMController.h"


@interface SVGraphicContainerDOMController : SVDOMController
{
  @private
    SVOffscreenWebViewController    *_offscreenWebViewController;
    SVWebEditorHTMLContext          *_offscreenContext;
}

- (DOMElement *)graphicDOMElement;


@end


#pragma mark -


@interface WEKWebEditorItem (SVPageletDOMController)
- (SVGraphicContainerDOMController *)enclosingGraphicDOMController;
@end


#pragma mark -


@protocol SVGraphicContainerDOMController <NSObject>

@optional
- (BOOL)dragItem:(WEKWebEditorItem *)item withEvent:(NSEvent *)event offset:(NSSize)mouseOffset slideBack:(BOOL)slideBack;

- (void)addGraphic:(SVGraphic *)graphic;


@end


@interface WEKWebEditorItem (SVGraphicContainerDOMController)
- (WEKWebEditorItem <SVGraphicContainerDOMController> *)graphicContainerDOMController;
@end