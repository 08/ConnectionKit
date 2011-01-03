//
//  SVMetricsInspector.m
//  Sandvox
//
//  Created by Mike on 29/03/2010.
//  Copyright 2010-11 Karelia Software. All rights reserved.
//

#import "SVMetricsInspector.h"

#import "KTDocument.h"
#import "SVMediaGraphic.h"


@implementation SVMetricsInspector

- (IBAction)enterExternalURL:(id)sender;
{
    NSWindow *window = [oURLField window];
    [window makeKeyWindow];
    [oURLField setHidden:NO];
    [window makeFirstResponder:oURLField];
}

- (IBAction)chooseFile:(id)sender;
{
    KTDocument *document = [self representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
    
    if ([panel runModalForTypes:[panel allowedFileTypes]] == NSFileHandlingPanelOKButton)
    {
        NSURL *URL = [panel URL];
        
        [[self inspectedObjects] makeObjectsPerformSelector:@selector(setSourceWithURL:)
                                                 withObject:URL];
    }
}

- (IBAction)makeOriginalSize:(NSButton *)sender;
{
    for (SVMediaGraphic *aGraphic in [self inspectedObjects])
    {
        [aGraphic makeOriginalSize];
    }
}

@end
