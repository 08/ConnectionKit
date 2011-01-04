//
//  SVGraphicContainerDOMController.m
//  Sandvox
//
//  Created by Mike on 23/11/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVGraphicContainerDOMController.h"


@implementation SVGraphicDOMController (SVGraphicContainerDOMController)

- (id <SVGraphicContainerDOMController>)graphicContainerDOMController;
{
    id result = [self parentWebEditorItem];
    while (result && ![result conformsToProtocol:@protocol(SVGraphicContainerDOMController)])
    {
        result = [result parentWebEditorItem];
    }
    
    return result;
}

@end
