//
//  SVSummaryDOMController.m
//  Sandvox
//
//  Created by Mike on 02/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSummaryDOMController.h"
#import "SVSiteItem.h"


@implementation SVSummaryDOMController

- (void)dealloc;
{
    [_page release];
    
    [super dealloc];
}

- (NSString *)elementIdName;
{
    // We probably shouldn't have to implement this! Instead context should generate IDs automatically of something like that
    return [NSString stringWithFormat:@"%p", self];
}

@synthesize itemToSummarize = _page;

- (NSArray *)contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems;
{
    // Tack on control over custom summary
    NSMutableArray *result = [[defaultMenuItems mutableCopy] autorelease];
    
    [result addObject:[NSMenuItem separatorItem]];
    
    NSMenuItem *command = [[NSMenuItem alloc] initWithTitle:@""
                                                     action:@selector(toggleCustomSummary:)
                                              keyEquivalent:@""];
    [command setTarget:self];
    
    [result addObject:command];
    [command release];
    
    return result;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
{
    if ([menuItem action] == @selector(toggleCustomSummary:))
    {
        NSString *title;
        if ([[self itemToSummarize] customSummaryHTML])
        {
            title = NSLocalizedString(@"Remove Custom Summary", "context menu item");
        }
        else
        {
            title = NSLocalizedString(@"Add Custom Summary", "context menu item");
        }
        [menuItem setTitle:title];
    }
    
    return YES;
}

- (void)toggleCustomSummary:(NSMenuItem *)sender;
{
    [[self itemToSummarize] setCustomSummaryHTML:nil];
}

@end
