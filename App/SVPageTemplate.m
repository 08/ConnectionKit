//
//  SVPageTemplate.m
//  Sandvox
//
//  Created by Mike on 28/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageTemplate.h"

#import "KTElementPlugInWrapper.h"
#import "SVGraphicFactory.h"

#import "NSDictionary+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSString+KTExtensions.h"


@implementation SVPageTemplate

- (id)initWithCollectionPreset:(NSDictionary *)presetDict;
{
    // Find corresponding bundle
    NSString *bundleIdentifier = [presetDict objectForKey:@"KTPresetIndexBundleIdentifier"];
    
    KTElementPlugInWrapper *plugin = (bundleIdentifier ?
                                      [KTElementPlugInWrapper pluginWithIdentifier:bundleIdentifier] :
                                      nil);
    
    
    // Init with the right graphic factory
    SVGraphicFactory *factory = [plugin graphicFactory];
    if (factory)
    {
        [self initWithGraphicFactory:factory];
    }
    else
    {
        [self init];
    }
    
    
    // Other Stuff
    [self setPageProperties:[presetDict ks_dictionaryBySettingObject:[NSNumber numberWithBool:YES]
                                                              forKey:@"isCollection"]];
    
    NSString *presetTitle = [presetDict objectForKey:@"KTPresetTitle"];
    if (plugin) presetTitle = [[plugin bundle] localizedStringForKey:presetTitle
                                                               value:presetTitle
                                                               table:nil];
    [self setTitle:presetTitle];

	NSString *presetSubtitle = [presetDict objectForKey:@"KTPresetSubtitle"];
    if (plugin) presetSubtitle = [[plugin bundle] localizedStringForKey:presetSubtitle
                                                               value:presetSubtitle
                                                               table:nil];
    [self setSubtitle:presetSubtitle];
	
    
    id priorityID = [presetDict objectForKey:@"KTPluginPriority"];
    int priority = 5;
    if (nil != priorityID)
    {
        priority = [priorityID intValue];
    } 
    
    
    NSImage *icon = nil;
    if (plugin)
    {
        icon = [[plugin graphicFactory] pageIcon];
#ifdef DEBUG
        if (nil == icon)
        {
            NSLog(@"nil pluginIcon for %@", presetTitle);
        }
#endif
    }
    else	// built-in, no bundle, so try to get icon directly
    {
        icon = [presetDict objectForKey:@"KTPageIconName"];
    }
    [self setIcon:icon];
    
    
    
    return self;
}

- (id)initWithGraphicFactory:(SVGraphicFactory *)factory;
{
    OBPRECONDITION(factory);
    
    [self init];
    
    _graphicFactory = [factory retain]; // TOOD: Factories are immutable at the moment, so could copy instead
    
    [self setIcon:[factory pageIcon]];
    
    return self;
}

- (void)dealloc;
{
	[_title release];
	[_subtitle release];
	[_icon release];
    [_properties release];
    [_graphicFactory release];
    
    [super dealloc];
}

+ (NSArray *)collectionPresets;
{
    // Order plug-ins first by priority, then by name
    //      I've turned off priority support for now to try a pure alphabetical approach - Mike
    //NSSortDescriptor *prioritySort = [[NSSortDescriptor alloc] initWithKey:@"priority"
    //                                                             ascending:YES];
    NSSortDescriptor *nameSort = [[NSSortDescriptor alloc]
                                  initWithKey:@"KTPresetTitle"
                                  ascending:YES
                                  selector:@selector(caseInsensitiveCompare:)];
    
    NSArray *sortDescriptors = [NSArray arrayWithObjects:/*prioritySort, */nameSort, nil];
    //[prioritySort release];
    [nameSort release];
    
    NSArray *result = [[KTElementPlugInWrapper collectionPresets]
                       KS_sortedArrayUsingDescriptors:sortDescriptors];
    return result;
}

+ (NSArray *)pageTemplates;
{
    static NSArray *result;
    
    if (!result)
    {
        NSMutableArray *buffer = [[NSMutableArray alloc] init];
        SVPageTemplate *aTemplate;
        
        aTemplate = [[SVPageTemplate alloc] init];
        [aTemplate setTitle:NSLocalizedString(@"Empty/Text", "New page pulldown button menu item title")];
        [aTemplate setIcon:[NSImage imageNamed:@"page_empty_sb"]];
        [aTemplate setPageProperties:NSDICT(NSBOOL(YES), @"showSidebar")];
        [buffer addObject:aTemplate];
        [aTemplate release];
        
        aTemplate = [[SVPageTemplate alloc] init];
        [aTemplate setTitle:NSLocalizedString(@"Empty/Text", "menu item title")];
		[aTemplate setSubtitle:NSLocalizedString(@"Without Sidebar", "menu item subtitle")];
		[aTemplate setIcon:[NSImage imageNamed:@"page_empty"]];
        [aTemplate setPageProperties:[NSDictionary dictionaryWithObject:NSBOOL(NO) forKey:@"showSidebar"]];
        [buffer addObject:aTemplate];
        [aTemplate release];
        
        SVGraphicFactory *aGraphicFactory = [SVGraphicFactory mediaPlaceholderFactory];
        aTemplate = [[SVPageTemplate alloc] initWithGraphicFactory:aGraphicFactory];
		[aTemplate setIcon:[NSImage imageNamed:@"page_photo_sb"]];
		[aTemplate setTitle:NSLocalizedString(@"Photo/Video", "menu item title")];
        [aTemplate setPageProperties:NSDICT(NSBOOL(YES), @"showSidebar", NSLocalizedString(@"Photo", "page title"), @"title")];
		[buffer addObject:aTemplate];
        [aTemplate release];
        
        aTemplate = [[SVPageTemplate alloc] initWithGraphicFactory:aGraphicFactory];
 		[aTemplate setIcon:[NSImage imageNamed:@"page_photo"]];
		[aTemplate setTitle:NSLocalizedString(@"Photo/Video", "menu item title")];
  		[aTemplate setSubtitle:NSLocalizedString(@"Without Sidebar", "menu item subtitle")];
        [aTemplate setPageProperties:NSDICT(NSBOOL(NO), @"showSidebar", NSLocalizedString(@"Photo", "page title"), @"title")];
		[buffer addObject:aTemplate];
        [aTemplate release];
        
        
        // Collection Presets
        for (NSDictionary *aPreset in [self collectionPresets])
        {
            aTemplate = [[SVPageTemplate alloc] initWithCollectionPreset:aPreset];            
            [buffer addObject:aTemplate];
            [aTemplate release];
        }
        
        
        // One-shot pages ... (Is there some better way to instantiate these, so we don't have a problem if they are gone?)
		
        aGraphicFactory = [SVGraphicFactory factoryWithIdentifier:@"sandvox.ContactElement"];
        aTemplate = [[SVPageTemplate alloc] initWithGraphicFactory:aGraphicFactory];
  		[aTemplate setIcon:[NSImage imageNamed:@"page_contact_sb"]];
		[aTemplate setTitle:NSLocalizedString(@"Contact Form", "menu item title")];
        [buffer addObject:aTemplate];
        [aTemplate release];
        
        aGraphicFactory = [SVGraphicFactory factoryWithIdentifier:@"sandvox.SiteMapElement"];
        aTemplate = [[SVPageTemplate alloc] initWithGraphicFactory:aGraphicFactory];
   		[aTemplate setIcon:[NSImage imageNamed:@"page_sitemap_sb"]];
		[aTemplate setTitle:NSLocalizedString(@"Sitemap", "menu item title")];
        [buffer addObject:aTemplate];
        [aTemplate release];
        
                
        result = [buffer copy];
        [buffer release];
    }
    
    return result;
}

@synthesize title = _title;
@synthesize subtitle = _subtitle;
@synthesize icon = _icon;
@synthesize pageProperties = _properties;
@synthesize graphicFactory = _graphicFactory;

- (NSMenuItem *)makeMenuItem;
{
    NSMenuItem *result = [[NSMenuItem alloc] initWithTitle:[self title]
                                                    action:@selector(addPage:)
                                             keyEquivalent:@""];
	if ([self subtitle])
	{
		NSAttributedString *attributedTitle = [NSAttributedString attributedMenuTitle:[self title] subtitle:[self subtitle]];
		[result setAttributedTitle:attributedTitle];
	}
   
    NSImage *icon = [[self icon] copy];
    [icon setSize:NSMakeSize(38.0,42.0)];
    [result setImage:icon];
    [icon release];
    
    [result setRepresentedObject:self];
    
    return [result autorelease];
}

+ (void)populateMenu:(NSMenu *)menu withPageTemplates:(NSArray *)templates index:(NSUInteger)index;
{
    for (SVPageTemplate *aTemplate in templates)
    {
        NSMenuItem *menuItem = [aTemplate makeMenuItem];
        [menu insertItem:menuItem atIndex:index];
        index++;
    }
}

@end
