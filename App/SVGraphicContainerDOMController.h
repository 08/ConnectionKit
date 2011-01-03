//
//  SVGraphicContainerDOMController.h
//  Sandvox
//
//  Created by Mike on 23/11/2010.
//  Copyright 2010-11 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SVGraphicDOMController.h"


@protocol SVGraphicContainerDOMController <NSObject>

- (void)moveGraphicWithDOMController:(SVDOMController *)graphicController
                          toPosition:(CGPoint)position
                               event:(NSEvent *)event;

@optional - (void)addGraphic:(SVGraphic *)graphic;


@end


@interface SVGraphicDOMController (SVGraphicContainerDOMController)
- (id <SVGraphicContainerDOMController>)graphicContainerDOMController;
@end