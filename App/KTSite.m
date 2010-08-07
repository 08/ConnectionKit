//
//  KTSite.m
//  KTComponents
//
//  Created by Terrence Talbot on 5/21/05.
//  Copyright 2005 Karelia Software. All rights reserved.
//

#import "KTSite.h"

#import "KT.h"
#import "SVApplicationController.h"
#import "KTHostProperties.h"
#import "SVHTMLTemplateParser.h"
#import "KTPage.h"

#import "NSApplication+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSStringXMLEntityEscaping.h"


@interface KTSite ()
- (NSArray *)_pagesInSiteMenu;
+ (NSArray *)_siteMenuSortDescriptors;
@end


@implementation KTSite

#pragma mark -
#pragma mark Init

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	
	// Give ourself a unique ID
	NSString *siteID = [NSString shortUUIDString];
    [self setPrimitiveValue:siteID forKey:@"siteID"];
	
	
	// Create Host Properties object as well.
	NSManagedObject *hostProperties = [NSEntityDescription insertNewObjectForEntityForName:@"HostProperties"
																	inManagedObjectContext:[self managedObjectContext]];
	[self setValue:hostProperties forKey:@"hostProperties"];
}

#pragma mark -
#pragma mark Pages

- (KTPage *)rootPage
{
    [self willAccessValueForKey:@"rootPage"];
    KTPage *result = [self primitiveValueForKey:@"rootPage"];
    if (!result)
    {
        result = [[[self siteItems] anyObject] rootPage];
        [self setPrimitiveValue:result forKey:@"rootPage"];
    }
    
    [self didAccessValueForKey:@"rootPage"];
    
    return result;
}

@dynamic siteItems;

#pragma mark Accessors

- (NSString *)siteID { return [self wrappedValueForKey:@"siteID"]; }

@synthesize document = _document;

#pragma mark Media

@dynamic copyMoviesIntoDocument;

#pragma mark UI

- (NSRect)docWindowContentRect
{
	NSString *rectAsString = [self valueForKey:@"documentWindowContentRect"];
	NSRect result = (rectAsString) ? NSRectFromString(rectAsString) : NSZeroRect;
	return result;
}

- (void)setDocWindowContentRect:(NSRect)rect
{
	[self setValue:NSStringFromRect(rect) forKey:@"documentWindowContentRect"];
}

- (NSString *)lastSelectedRows
{
	return [self wrappedValueForKey:@"lastSelectedRows"];
}

- (void)setLastSelectedRows:(NSString *)value
{
	[self setWrappedValue:value forKey:@"lastSelectedRows"];
}

#pragma mark -
#pragma mark HTML

/*!	Invoked to fill in the web pages for the meta 'generator' value
 */
- (NSString *)appNameVersion
{
	NSString *marketingVersion = [NSApplication marketingVersion];
	
	NSString *applicationName = [NSApplication applicationName];
	if ([[NSApp delegate] isPro])
	{
		applicationName = [applicationName stringByAppendingString:@" Pro"];
	}
	
	return [NSString stringWithFormat:@"%@ %@", applicationName, marketingVersion];
}

#pragma mark -
#pragma mark Site Menu

- (NSArray *)pagesInSiteMenu
{
	NSArray *result = [self wrappedValueForKey:@"pagesInSiteMenu"];
	if (!result)
	{
		result = [self _pagesInSiteMenu];
		[self setPrimitiveValue:result forKey:@"pagesInSiteMenu"];
	}
	
	OBPOSTCONDITION(result);
	return result;
}

- (NSArray *)_pagesInSiteMenu
{
	NSArray *result;
    
    
    // Fetch all the pages qualifying to fit in the Site Menu.
	NSManagedObjectModel *model = [[[self managedObjectContext] persistentStoreCoordinator] managedObjectModel];
	NSFetchRequest *request = [model fetchRequestTemplateForName:@"SiteOutlinePages"];
	
	NSError *error = nil;
	NSArray *unsortedResult = [[self managedObjectContext] executeFetchRequest:request error:&error];
	if (error) {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert setIcon:[NSApp applicationIconImage]];
		[alert runModal];	
		return nil;
	}
	
    
    // We have an odd bug where occasionally, a page will have a parent, but the parent will not recognise it as a child.
    // To fix, we need to delete such pages.
    static NSPredicate *orphansPredicate;
    if (!orphansPredicate) orphansPredicate = [[NSPredicate predicateWithFormat:@"indexPath == nil"] retain];
    
    NSArray *orphanedPages = [unsortedResult filteredArrayUsingPredicate:orphansPredicate];
    if ([orphanedPages count] > 0)
    {
        NSLog(@"Deleting orphaned pages:\n%@", orphanedPages);
        [[self managedObjectContext] deleteObjectsInCollection:orphanedPages];
        
        result = [self _pagesInSiteMenu]; // After the deletion, it should be safe to run again
    }
    else
    {
        // Sort the pages according to their index path from root
        result = [unsortedResult sortedArrayUsingDescriptors:[[self class] _siteMenuSortDescriptors]];
    }
    
    
    return result;
}

- (void)invalidatePagesInSiteMenuCache
{
	[self setWrappedValue:nil forKey:@"pagesInSiteMenu"];
}

+ (NSArray *)_siteMenuSortDescriptors
{
	static NSArray *result;
	
	if (!result)
	{
		NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"indexPath" ascending:YES];
		result = [[NSArray alloc] initWithObject:sortDescriptor];
		[sortDescriptor release];
	}
	
	return result;
}

#pragma mark -
#pragma mark Google Sitemap

/*  Recursively build map.  Home page gets priority 1.0; second level pages 0.5, third 0.33, etc.
 *  Items in the site map (besides home page) get 0.95, 0.90, 0.85, ... 0.55 in order that they appear
 *  This should make the site map be prioritized nicely.
 */
- (void)appendGoogleMapOfPage:(KTPage *)aPage toArray:(NSMutableArray *)ioArray siteMenuCounter:(int *)ioSiteMenuCounter level:(int)aLevel
{
	NSURL *siteURL = [[self hostProperties] siteURL];
    if (![siteURL hasDirectoryPath])
    {
        siteURL = [siteURL URLByDeletingLastPathComponent];
    }
    
    NSString *url = [[aPage URL] absoluteString];
	if (![url hasPrefix:[siteURL absoluteString]])
	{
		return;	// an external link not in this site
	}
	
	BOOL excluded = [aPage excludedFromSiteMap];
//	NSLog(@"%@ exclude? %d", url, excluded);
	if (excluded)	// excluded checkbox checked, or it's an unpublished draft
	{
//		NSLog(@"...so I'm skipping this");
		return;	// addBool1 is indicator to EXCLUDE from a sitemap.
	}
	
	OBPRECONDITION(aLevel >= 1);
	NSMutableDictionary *entry = [NSMutableDictionary dictionary];
	[entry setObject:url forKey:@"loc"];
	float levelFraction = 1.0 / aLevel;
	if ([[aPage includeInSiteMenu] boolValue] && aLevel > 1)	// boost items in site menu?
	{
		if (ioSiteMenuCounter)
		{
			(*ioSiteMenuCounter)++;	// we have one more site menu item
			levelFraction = 0.95 - (0.05 * (*ioSiteMenuCounter));	// .90, .85, 0.80, 0.75 etc.
			if (levelFraction < 0.55) levelFraction = .55;	// keep site menu above .5
		}
	}
	OBASSERT(levelFraction <= 1.0 && levelFraction > 0.0);
	[entry setObject:[NSNumber numberWithFloat:levelFraction] forKey:@"priority"];
    
	NSDate *lastModificationDate = [aPage modificationDate];
	NSString *timestamp = [lastModificationDate descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%SZ" timeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"] locale:nil];
	[entry setObject:timestamp forKey:@"lastmod"];
	
	// Note: we are not trying to support the "changefreq" parameter
	
	[ioArray addObject:entry];
	
    
	NSArray *children = [aPage sortedChildren];
	if ([children count])
	{
		NSEnumerator *theEnum = [children objectEnumerator];
		KTPage *aChildPage;
		
		while (nil != (aChildPage = [theEnum nextObject]) )
		{
			[self appendGoogleMapOfPage:aChildPage toArray:ioArray siteMenuCounter:ioSiteMenuCounter level:aLevel+1];
		}
	}
}


- (NSString *)googleSiteMapXMLString
{
	NSMutableArray *array = [NSMutableArray array];
	int siteMenuCounter = 0;
	[self appendGoogleMapOfPage:[self rootPage] toArray:array siteMenuCounter:&siteMenuCounter level:1];
    
	NSMutableString *result = [NSMutableString string];
	[result appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n"];
	
	NSDictionary *dict;
    for (dict in array)
	{
		[result appendFormat:
         @"<url><loc>%@</loc><lastmod>%@</lastmod><priority>%.02f</priority></url>\n",
         [[dict objectForKey:@"loc"] stringByEscapingHTMLEntities],
         [dict objectForKey:@"lastmod"],
         [[dict objectForKey:@"priority"] floatValue] ];
	}
	
    [result appendString:@"</urlset>\n"];
    
	return result;
}

#pragma mark jQuery

- (void)writeJQueryImport
{
	// We might want to update this if a major new stable update comes along. We'd put fresh copies in the app resources.
#define JQUERY_VERSION @"1.4.2"
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
	NSURL *jQueryURL = nil;
	NSString *minimizationSuffix = @".min";
	NSURL *siteURL = [self.hostProperties siteURL];
	NSString *scheme = [siteURL scheme];
	if (!scheme) scheme = @"http";		// for instance, when newly set up. Better to show something for page source.

	if ([defaults boolForKey:@"jQueryDevelopment"])
	{
		minimizationSuffix = @"";		// Use the development version instead, not the minimized.
	}
	
	// This is either the local version, or not uploaded to a web server, or user preference to keep their own copy of jQuery.
	if ([context isForEditing] || [scheme isEqualToString:@"file"] || [defaults boolForKey:@"jQueryLocal"])
	{
		NSURL *localJQueryURL = [NSURL fileURLWithPath:[[NSBundle mainBundle]
											pathForResource:[NSString stringWithFormat:@"jquery-%@%@", JQUERY_VERSION, minimizationSuffix]
											ofType:@"js"]];
		
		jQueryURL = [context addResourceWithURL:localJQueryURL];
		
	}
	else	// Normal publishing case: remote version from google, fastest for downloading.
			// Match http/https scheme of uploaded site.
	{
		jQueryURL = [NSURL URLWithString:
					 [NSString stringWithFormat:@"%@://ajax.googleapis.com/ajax/libs/jquery/%@/jquery%@.js",
					  scheme, JQUERY_VERSION, minimizationSuffix]];
	}
	
	[context writeJavascriptWithSrc:[jQueryURL absoluteString]];

	// Note: I may want to also get: http://ajax.googleapis.com/ajax/libs/jqueryui/1.8.2/jquery-ui.min.js
	// I would just put in parallel code.  However this might be better to be added with code injection by people who want it.
}

#pragma mark -
#pragma mark Publishing

@dynamic hostProperties;
@dynamic lastExportDirectoryPath;

#pragma mark -
#pragma mark Quick Look

- (NSString *)pageCount
{
	NSArray *pages = [[self managedObjectContext] fetchAllObjectsForEntityForName:@"Page" error:NULL];
	NSString *result = [NSString stringWithFormat:@"%u", [pages count]];
	return result;
}

/*	This could go anywhere really, it's just a convenience method for Quick Look
 */
- (NSString *)currentDate
{
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	NSString *result = [formatter stringFromDate:[NSDate date]];
	
	// Tidy up
	[formatter release];
	return result;
}

@end
