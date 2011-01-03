//
//  SVGraphicDOMController.h
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010-11 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"

#import "SVAuxiliaryPageletText.h"
#import "SVGraphic.h"

#import "SVOffscreenWebViewController.h"


@interface SVGraphicDOMController : SVDOMController <SVOffscreenWebViewControllerDelegate>
{
  @private
    DOMHTMLElement  *_bodyElement;
    
    SVOffscreenWebViewController    *_offscreenWebViewController;
    NSArray                         *_offscreenDOMControllers;
}

+ (SVGraphicDOMController *)graphicPlaceholderDOMController;

@property(nonatomic, retain) DOMHTMLElement *bodyHTMLElement;
- (DOMElement *)graphicDOMElement;
- (void)loadPlaceholderDOMElementInDocument:(DOMDocument *)document;

- (void)update;
- (void)updateSize;


@end


#pragma mark -


@interface WEKWebEditorItem (SVGraphicDOMController)
- (SVGraphicDOMController *)enclosingGraphicDOMController;
@end


#pragma mark -


// And provide a base implementation of the protocol:
@interface SVGraphic (SVDOMController) <SVDOMControllerRepresentedObject>
- (SVDOMController *)newBodyDOMController;
@end

@interface SVAuxiliaryPageletText (SVDOMController) <SVDOMControllerRepresentedObject>
@end


#pragma mark -


@interface SVGraphicBodyDOMController : SVDOMController
{
@private
    BOOL    _drawAsDropTarget;
}

@end
