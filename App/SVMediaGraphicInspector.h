//
//  SVMediaGraphicInspector.h
//  Sandvox
//
//  Created by Mike on 10/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVInspectorViewController.h"


@class KSURLInfoField;


@interface SVMediaGraphicInspector : SVInspectorViewController
{
    IBOutlet KSURLInfoField *oFileInfoField;
    IBOutlet NSTextField    *oURLField;
}

- (IBAction)enterExternalURL:(id)sender;
- (IBAction)chooseFile:(id)sender;

@end
