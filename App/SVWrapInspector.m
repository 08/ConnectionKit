//
//  SVWrapInspector.m
//  Sandvox
//
//  Created by Mike on 22/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVWrapInspector.h"

#import "SVGraphic.h"


@implementation SVWrapInspector

- (void)dealloc
{
    [self unbind:@"graphicPlacement"];
    [_placement release];
    
    [super dealloc];
}

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    [self bind:@"graphicPlacement"
      toObject:self
   withKeyPath:@"inspectedObjectsController.selection.placement"
       options:nil];
}

#pragma mark Placement - model driven

@synthesize graphicPlacement = _placement;
- (void)setGraphicPlacement:(NSNumber *)placement;
{
    placement = [placement copy];
    _placement = placement;
    
    
    // Update UI to match
    if (!placement || NSIsControllerMarker(placement))
    {
        [oPlacementRadioButtons setEnabled:NO];
    }
    else
    {
        [oPlacementRadioButtons setEnabled:YES];
        
        // Set their value too
        [oPlacementRadioButtons selectCellWithTag:[placement integerValue]];
    }
}

@end
