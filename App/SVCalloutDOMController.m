//
//  SVCalloutDOMController.m
//  Sandvox
//
//  Created by Mike on 28/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVCalloutDOMController.h"


@implementation SVCalloutDOMController

- (NSString *)elementIdName;
{
    return [NSString stringWithFormat:@"callout-controller-%p", self];
}

- (SVCalloutDOMController *)calloutDOMController;
{
    return self;
}

@end


#pragma mark -


@implementation WEKWebEditorItem (SVCalloutDOMController)

- (SVCalloutDOMController *)calloutDOMController; { return [[self parentWebEditorItem] calloutDOMController]; }

@end
