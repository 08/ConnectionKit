//
//  SVContentDOMController.m
//  Sandvox
//
//  Created by Mike on 30/07/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVContentDOMController.h"


@implementation SVContentDOMController

@synthesize webEditorViewController = _viewController;

- (void)setNeedsUpdate;
{
    [[self webEditorViewController] setNeedsUpdate];
}

@end
