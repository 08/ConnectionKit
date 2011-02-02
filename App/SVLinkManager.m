//
//  SVLinkManager.m
//  Sandvox
//
//  Created by Mike on 12/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVLinkManager.h"

#import "KSDocumentController.h"
#import "SVInspector.h"
#import "SVLinkInspector.h"
#import "KTToolbars.h"

#import "NSWorkspace+Karelia.h"


@interface SVLinkManager ()
@property(nonatomic, retain, readwrite) SVLink *selectedLink;
@property(nonatomic, readwrite, getter=isEditable) BOOL editable;
- (void)refreshLinkInspectors;
@end


@implementation SVLinkManager

#pragma mark Shared Manager

static SVLinkManager *sSharedLinkManager;

+ (SVLinkManager *)sharedLinkManager
{
    if (!sSharedLinkManager) [[[SVLinkManager alloc] init] release];    // sets sSharedLinkManager internally
    return sSharedLinkManager;
}

+ (id)allocWithZone:(NSZone *)zone;
{
    // If there's already a manager, re-use it
    if (sSharedLinkManager)
    {
        return [sSharedLinkManager retain];
    }
    else
    {
        sSharedLinkManager = [super allocWithZone:zone];
        return [sSharedLinkManager retain];
    }
}

#pragma mark Dealloc

- (void)dealloc
{
    [_selectedLink release];
    [super dealloc];
}

#pragma mark Selected Link

- (void)setSelectedLink:(SVLink *)link editable:(BOOL)editable;
{
    [self setSelectedLink:link];
    [self setEditable:editable];
    
    // Tell all open link Inspectors
    [self refreshLinkInspectors];
}

@synthesize selectedLink = _selectedLink;
@synthesize editable = _editable;

- (void)refreshLinkInspectors;
{
    NSArray *inspectors = [[KSDocumentController sharedDocumentController] inspectors];
    for (SVInspector *anInspector in inspectors)
    {
        [[anInspector linkInspector] refresh];
    }
}

#pragma mark Modifying the Link

- (void)modifyLinkTo:(SVLink *)link;    // sends -createLink: up the responder chain
{
    [self setSelectedLink:link];
    
    if (link)
    {
        [NSApp sendAction:@selector(createLink:) to:nil from:self];
    }
    else
    {
        [NSApp sendAction:@selector(unlink:) to:nil from:self];
    }
    
    // Notify Inspectors of the change
    [self refreshLinkInspectors];
}

#pragma mark UI

- (IBAction)orderFrontLinkPanel:(id)sender; // Sets the current Inspector to view links
{
    // Try to create create an example link if there isn't one already present
    if (![self selectedLink] && [self isEditable])
    {
        SVLink *link = [self guessLink];
        if (!link)
        {
            link = [[SVLink alloc] initWithURLString:@"http://example.com"
                                     openInNewWindow:YES];
            [link autorelease];
        }
        
        [self modifyLinkTo:link];
    }
    
    
    // Show the Inspector
    [[KSDocumentController sharedDocumentController] showInspectors:self];
    
    SVInspector *inspector = [[[KSDocumentController sharedDocumentController] inspectors] lastObject];
    [[inspector inspectorTabsController] setSelectedViewController:[inspector linkInspector]];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    BOOL result = YES;
    
    if ([anItem action] == @selector(orderFrontLinkPanel:))
    {
        result = [self isEditable];
        
        if ([(id <NSObject>)anItem isKindOfClass:[NSToolbarItem class]])
        {
            [(NSToolbarItem *)anItem setLabel:
             ([self selectedLink] ? TOOLBAR_EDIT_LINK : TOOLBAR_CREATE_LINK)];
        }
        else if ([(id <NSObject>)anItem isKindOfClass:[NSMenuItem class]])
        {
            [(NSMenuItem *)anItem setTitle:([self selectedLink] ?
                                            NSLocalizedString(@"Edit Link…", "menu item") :
                                            NSLocalizedString(@"Create Link…", "menu item"))];
        }
    }
    
    return result;
}

- (SVLink *)guessLink;  // looks at the user's workspace to guess what they want. Nil if no match is found
{
    SVLink *result = nil;
    
    
    // Is there something suitable on the pasteboard?
    NSURL *URL = [WebView URLFromPasteboard:[NSPasteboard generalPasteboard]];
    if (!URL)
    {
        // Try to populate from frontmost Safari URL
        // someday, we could populate the link title as well!
        URL = [[[NSWorkspace sharedWorkspace] fetchBrowserWebLocation] URL];
    }
	NSString *scheme = [URL scheme];
    
    if (URL && ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) )
	{
        result = [[SVLink alloc] initWithURLString:[URL absoluteString]
                                   openInNewWindow:NO];
        [result autorelease];
    }
    
    
    return result;
}

@end
