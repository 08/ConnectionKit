//
//  KTDocWindowController+Toolbar.m
//  Marvel
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

/*
 PURPOSE OF THIS CLASS/CATEGORY:
 Manage document's toolbar
 
 TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
 x
 
 IMPLEMENTATION NOTES & CAUTIONS:
 x
 
 TO DO:
 x
 
 */

#import "KTDocWindowController.h"

#import "SVApplicationController.h"
#import "KT.h"
#import "KTElementPlugInWrapper.h"
#import "SVGraphicFactory.h"
#import "SVLinkManager.h"
#import "SVPageTemplate.h"
#import "KTToolbars.h"

#import "NSImage+KTExtensions.h"
#import "NSMenuItem+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSToolbar+Karelia.h"

#import "Debug.h"

#import <BWToolkitFramework/BWToolkitFramework.h>


@interface KTDocWindowController ( PrivateToolbar )

- (NSToolbar *)toolbarNamed:(NSString *)toolbarName;

- (NSToolbarItem *)makeGraphicsToolbarItemWithIdentifier:(NSString *)identifier;

@end

// NB: there's about two-thirds the work here to make this a separate controller
//  it needs a way to define views that aren't app specific, should all be doable via xml
//  for "standard" controls, like a pulldown button item

@implementation KTDocWindowController (Toolbar)

- (void)makeDocumentToolbar
{
    NSToolbar *toolbar = [self toolbarNamed:@"document2"];
	
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    [toolbar setDisplayMode:NSToolbarDisplayModeDefault];
    [toolbar setDelegate:self];
	
    [[self window] setToolbar:toolbar];
	[self updateToolbar];		// get the states right
}


- (void)updateToolbar
{
}

/*  Holding down the option key should change "Publish" to "Publish All" (unless the publishAll item is there)
 *  Similar code also exists in -validateToolbarItem: since their's a few edge cases that -flagsChanged: doesn't catch
 */
- (void)flagsChanged:(NSEvent *)theEvent
{
    NSToolbarItem *publishAllToolbarItem = [[[self window] toolbar] itemWithIdentifier:@"publishAll"];
	if (!publishAllToolbarItem)
	{
		NSToolbarItem *toolbarItem = [[[self window] toolbar] itemWithIdentifier:@"saveToHost:"];
		[toolbarItem setLabel:([theEvent modifierFlags] & NSAlternateKeyMask ? TOOLBAR_PUBLISH_ALL : TOOLBAR_PUBLISH)];
		[toolbarItem setImage:[NSImage imageNamed:([theEvent modifierFlags] & NSAlternateKeyMask ? @"toolbar_publish_all" : @"toolbar_publish")]];
	}
    
    [super flagsChanged:theEvent];
}

#pragma mark -
#pragma mark Setup

- (NSToolbar *)toolbarNamed:(NSString *)toolbarName
{
    NSString *path = [[NSBundle mainBundle] pathForResource:toolbarName ofType:@"toolbar"];
	
    if ( nil != path ) 
	{
        NSMutableDictionary *toolbarInfo = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        if ( nil != toolbarInfo ) 
		{
            NSString *toolbarIdentifier = [toolbarInfo valueForKey:@"toolbar name"];
            if ( nil != toolbarIdentifier ) 
			{
                NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:toolbarIdentifier] autorelease];
                NSMutableDictionary *toolbarsEntry = [NSMutableDictionary dictionary];
				
                [toolbarsEntry setObject:toolbar forKey:@"toolbar"];
                [toolbarsEntry setObject:toolbarInfo forKey:@"info"];
                [myToolbars setObject:toolbarsEntry forKey:toolbarIdentifier];
				
                return toolbar;
            }
            else 
			{
                LOG((@"KTDocWindowController: unable to find key 'toolbar name' for toolbar: %@", toolbarName));
            }
        }
        else 
		{
            LOG((@"KTDocWindowController: unable to read configuration for toolbar at path: %@\nError in plist?", path));
        }
    }
    else 
	{
        LOG((@"KTDocWindowController: unable to locate toolbar: %@", toolbarName));
    }
	
    return nil;
}

- (NSMutableDictionary *)infoForToolbar:(NSToolbar *)toolbar
{
    // walk the toolbars looking for the toolbar
    NSEnumerator *enumerator = [myToolbars objectEnumerator];
    NSDictionary *toolbarEntry;
	
    while ( toolbarEntry = [enumerator nextObject] ) 
	{
        if ( [toolbarEntry objectForKey:@"toolbar"] == toolbar ) 
		{
            return [toolbarEntry objectForKey:@"info"];
        }
    }
	
    return nil;
}

#pragma mark Item creation

- (NSToolbarItem *)makeNewPageToolbarItemWithIdentifier:(NSString *)identifier
                                              imageName:(NSString *)imageName;
{
    BWToolbarPullDownItem *result = [[BWToolbarPullDownItem alloc] initWithItemIdentifier:identifier];
    
    
    // construct pulldown button ... composite the Add.
	
    NSImage *image = [NSImage imageNamed:imageName];
	image = [[image copy] autorelease];
	[image setScalesWhenResized:YES];
	[image setSize:NSMakeSize(32.0,32.0)];
	
    image = [image imageWithCompositedAddBadge];
    [result setImage:image];
	
    
    // Generate the menu
    NSPopUpButton *pulldownButton = [result popUpButton];
    NSMenu *menu = [pulldownButton menu];
	
    [SVPageTemplate populateMenu:menu withPageTemplates:[SVPageTemplate pageTemplates] index:1];
	
    
    
    // Collections
    //NSMenuItem *item = [menu addItemWithTitle:NSLocalizedString(@"Collections", "toolbar menu")
    //                                   action:nil
    //                            keyEquivalent:@""];
	
	//[[pulldownButton lastItem] setIconImage:[NSImage imageNamed:@"toolbar_collection"]];

    //NSMenu *collectionsMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Collections", "toolbar menu")];
    //[item setSubmenu:collectionsMenu];
    [KTElementPlugInWrapper populateMenuWithCollectionPresets:menu atIndex:2];
    //[collectionsMenu release];
    

    [menu addItem:[NSMenuItem separatorItem]];
    

    [menu addItemWithTitle:NSLocalizedString(@"External Link", "New page pulldown button menu item title")
                    action:@selector(addExternalLinkPage:)
             keyEquivalent:@""];
	
	[[pulldownButton lastItem] setIconImage:[NSImage imageFromOSType:kGenericURLIcon]];
	
	
	[menu addItemWithTitle:NSLocalizedString(@"Raw HTML/Text", "New page pulldown button menu item title")
					action:@selector(addRawTextPage:) keyEquivalent:@""];
	
	
	self.HTMLTextPageMenuItem = [pulldownButton lastItem];		// save for later since this gets hidden if not Pro
	[self.HTMLTextPageMenuItem setIconImage:[NSImage imageNamed:@"toolbar_html_element"]];
	
    [menu addItem:[NSMenuItem separatorItem]];
    
    [menu addItemWithTitle:NSLocalizedString(@"Choose…", "New page pulldown button menu item title")
                    action:@selector(addFilePage:)
             keyEquivalent:@""];
    
    
    return [result autorelease];
}

- (NSToolbarItem *)makeIndexesToolbarItemWithIdentifier:(NSString *)identifier
											  imageName:(NSString *)imageName;
{
    BWToolbarPullDownItem *result = [[BWToolbarPullDownItem alloc] initWithItemIdentifier:identifier];
    
	// construct pulldown button ... composite the Add.
	
    NSImage *image = [NSImage imageNamed:imageName];
	image = [[image copy] autorelease];
	[image setScalesWhenResized:YES];
	[image setSize:NSMakeSize(32.0,32.0)];
	
    image = [image imageWithCompositedAddBadge];
    [result setImage:image];

	
    // Generate the menu
    NSPopUpButton *pulldownButton = [result popUpButton];
    NSMenu *menu = [pulldownButton menu];
    [SVGraphicFactory insertItemsWithGraphicFactories:[SVGraphicFactory indexFactories]
                                               inMenu:menu
                                              atIndex:1
									  withDescription:YES];
    
    
    return [result autorelease];
}


/*	Support method that turns toolbarItem into a "Add Pagelet" button
 */
- (NSToolbarItem *)makeGraphicsToolbarItemWithIdentifier:(NSString *)identifier;
{
	BWToolbarPullDownItem *result = [[BWToolbarPullDownItem alloc] initWithItemIdentifier:identifier];
    
	// Generate the menu
    NSPopUpButton *pulldownButton = [result popUpButton];
    NSMenu *menu = [pulldownButton menu];
    
    NSMenuItem *item = nil;
	SVGraphicFactory *factory = nil;
	
    
    // Text box item
	factory = [SVGraphicFactory textBoxFactory];
	item = [factory makeMenuItemWithDescription:YES];
	[menu addItem:item];
	
    
    // Indexes
	item = [SVGraphicFactory menuItemWithGraphicFactories:[SVGraphicFactory indexFactories]
                                                   title:NSLocalizedString(@"Indexes", "menu item")
										  withDescription:YES];
 	[item setIconImage:[NSImage imageNamed:@"toolbar_index"]];
	[menu addItem:item];
    
    
    // Media Placeholder
	factory = [SVGraphicFactory mediaPlaceholderFactory];
	item = [factory makeMenuItemWithDescription:YES];
	[menu addItem:item];
	
	
    // Raw HTML
    self.rawHTMLMenuItem = item = [[SVGraphicFactory rawHTMLFactory] makeMenuItemWithDescription:YES];
    
	[menu addItem:item];
	
    
    // ---
    item = [NSMenuItem separatorItem];
	[menu addItem:item];
    
    
	/*/ Badges
    item = [self makeMenuItemForGraphicFactories:[SVGraphicFactory badgeFactories]
                                           title:NSLocalizedString(@"Badges", "menu item")];
	[item setIconImage:[NSImage imageNamed:@"toolbar_badge"]];
	[menu addItem:item];*/
	
    
	/*/ Embedded
    item = [self makeMenuItemForGraphicFactories:[SVGraphicFactory embeddedFactories]
                                           title:NSLocalizedString(@"Embedded", "menu item")];
	[item setIconImage:[NSImage imageNamed:@"toolbar_frame"]];
    [menu addItem:item];*/
	
    
	/*/ Social
    item = [self makeMenuItemForGraphicFactories:[SVGraphicFactory socialFactories]
                                           title:NSLocalizedString(@"Social", "menu item")];
	[item setIconImage:[NSImage imageNamed:@"toolbar_social"]];
    [menu addItem:item];*/
	
    
	// More
    [SVGraphicFactory insertItemsWithGraphicFactories:[SVGraphicFactory moreGraphicFactories]
                                               inMenu:menu
                                              atIndex:[[menu itemArray] count]
									  withDescription:YES];
	
	
    return [result autorelease];
}


#pragma mark Delegate (NSToolbar)

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString*)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *result = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    [result setImage:nil];
	
    NSArray *itemsArray = [[self infoForToolbar:toolbar] objectForKey:@"item array"];
    for (NSDictionary *itemInfo in itemsArray) 
	{
        if ( [[itemInfo valueForKey:@"identifier"] isEqualToString:itemIdentifier] ) 
		{
            // Custom?
            if ([[itemInfo objectForKey:@"view"] isEqualToString:@"NewPagePopUpButton"])
            {
                result = [self makeNewPageToolbarItemWithIdentifier:itemIdentifier
                                                          imageName:[itemInfo valueForKey:@"image"]];
            }
            else if ([[itemInfo valueForKey:@"view"] isEqualToString:@"myAddPageletPopUpButton"]) 
            {
                result = [self makeGraphicsToolbarItemWithIdentifier:itemIdentifier];
            }
            else if ([[itemInfo valueForKey:@"view"] isEqualToString:@"IndexesPopUpButton"])
            {
                result = [self makeIndexesToolbarItemWithIdentifier:itemIdentifier
						  imageName:[itemInfo valueForKey:@"image"]];
            }
            // cosmetics
			
            [result setLabel:[[NSBundle mainBundle] localizedStringForKey:[itemInfo valueForKey:@"label"] value:@"" table:nil]];
            [result setPaletteLabel:[[NSBundle mainBundle] localizedStringForKey:[itemInfo valueForKey:@"paletteLabel"] value:@"" table:nil]];
            [result setToolTip:[[NSBundle mainBundle] localizedStringForKey:[itemInfo valueForKey:@"help"] value:@"" table:nil]];
			
            // action
            if ( (nil != [itemInfo valueForKey:@"action"]) && ![[itemInfo valueForKey:@"action"] isEqualToString:@""] ) 
			{
				[result setAction:NSSelectorFromString([itemInfo valueForKey:@"action"])];
            }
            else
			{
                [result setAction:nil];
            }
			
			// target
			NSString *target = [[itemInfo valueForKey:@"target"] lowercaseString];
            if ( [target isEqualToString:@"windowcontroller"] ) 
			{
                [result setTarget:self];
            }
            else if ( [target isEqualToString:@"firstresponder"] ) 
			{
                if ([result action] == @selector(orderFrontLinkPanel:))
                {
                    [result setTarget:[SVLinkManager sharedLinkManager]];
                }
                else
                {
                    [result setTarget:nil];		// but can we do validation?
                }
            }
            else if ( [target isEqualToString:@"document"] ) 
			{
                [result setTarget:[self document]];
            }
            else
			{
                [result setTarget:nil];
            }
			
            NSString *imageName = [itemInfo valueForKey:@"image"];
            // are we a view or an image?
            // views can still have images, so we check whether it's a view first
            if ([imageName length] > 0 && ![result image]) 
			{
				NSImage *theImage = nil;
				if ([imageName hasPrefix:@"/"])	// absolute path -- instantiate thusly
				{
					theImage = [[[NSImage alloc] initWithData:[NSData dataWithContentsOfFile:imageName]] autorelease];
				}
				else
				{
					theImage = [NSImage imageNamed:imageName];
				}
				if (!theImage)
				{
					NSLog(@"Unable to create toolbar image '%@'", imageName);
				}
				[theImage normalizeSize];
				[theImage setDataRetained:YES];	// allow image to be scaled.
                [result setImage:theImage];
            }
        }
    }
	
    return result;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [[self infoForToolbar:toolbar] objectForKey:@"default set"];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar 
{
    NSMutableArray *allowedIdentifiers = [NSMutableArray array];
	
    NSArray *itemArray = [[self infoForToolbar:toolbar] objectForKey:@"item array"];
    NSDictionary *itemInfo;
	
    for ( itemInfo in itemArray ) 
	{
        NSString *itemIdentifier = [itemInfo valueForKey:@"identifier"];
        [allowedIdentifiers addObject:itemIdentifier];
    }
    return [NSArray arrayWithArray:allowedIdentifiers];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return nil; // since we're using the toolbar for actions, none are selectable
}

- (void)toolbarWillAddItem:(NSNotification *)notification
{
	NSToolbar *toolbar = [notification object];
    OBPRECONDITION(toolbar == [[self window] toolbar]);
                   
	NSToolbarItem *item = [[notification userInfo] objectForKey:@"item"];
	if ([[item itemIdentifier] isEqualToString:NSToolbarShowColorsItemIdentifier])
	{
		[item setImage:[NSImage imageInBundleForClass:[BWToolbarPullDownItem class]
												named:@"ToolbarItemColors.tiff"]];
	}
	else if ([[item itemIdentifier] isEqualToString:NSToolbarShowFontsItemIdentifier])
	{
		[item setImage:[NSImage imageInBundleForClass:[BWToolbarPullDownItem class]
												named:@"ToolbarItemFonts.tiff"]];
	}
}

@end

