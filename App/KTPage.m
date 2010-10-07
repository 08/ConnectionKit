//
//  KTPage.m
//  KTComponents
//
//  Created by Terrence Talbot on 3/10/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTPage+Paths.h"

#import "KSContainsObjectValueTransformer.h"
#import "Debug.h"
#import "SVRichText.h"
#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "SVGraphic.h"
#import "KTMaster.h"
#import "SVMediaRecord.h"
#import "SVPageTitle.h"
#import "SVPagesController.h"
#import "SVTextAttachment.h"

#import "NSBundle+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+KTExtensions.h"

#import "NSArray+Karelia.h"
#import "NSAttributedString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSError+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"


@interface KTPage ()
@property(nonatomic, retain, readwrite) SVSidebar *sidebar;
@property(nonatomic, retain, readwrite) SVRichText *article;
@end


#pragma mark -


@implementation KTPage

#ifdef DEBUG
- (NSString *)description
{
	if ([NSUserName() isEqualToString:@"dwood"])
	{
		return [NSString stringWithFormat:@"%p %@", self, [self title]];
	}
	return [super description];
}
#endif


#pragma mark Class Methods

/*!	Make sure that changes to titleHTML generate updates for new values of title, fileName
*/
+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // this is so we get notification of updaates to any properties that affect index type.
	// This is a fake attribute -- we don't actually have this accessor since it's more UI related
	[self setKeys:[NSArray arrayWithObjects:
		@"collectionShowPermanentLink",
		@"collectionHyperlinkPageTitles",
		@"collectionIndexBundleIdentifier",
		@"collectionSyndicationType", 
		@"collectionMaxSyndicatedPagesCount", 
		@"collectionSortOrder", 
		nil]
        triggerChangeNotificationsForDependentKey: @"indexPresetDictionary"];
	
	
	
	// Register transformers
	NSSet *collectionTypes = [NSSet setWithObjects:[NSNumber numberWithInt:KTSummarizeRecentList],
												   [NSNumber numberWithInt:KTSummarizeAlphabeticalList],
												   nil];
	
	NSValueTransformer *transformer = [[KSContainsObjectValueTransformer alloc] initWithComparisonObjects:collectionTypes];
	[NSValueTransformer setValueTransformer:transformer forName:@"KTCollectionSummaryTypeIsTitleList"];
	[transformer release];
	
	
	[pool release];
}

+ (NSSet *)keyPathsForValuesAffectingSummaryHTML
{
    return [NSSet setWithObject:@"collectionSummaryType"];
}

+ (NSString *)entityName { return @"Page"; }

#pragma mark -
#pragma mark Initialisation

/*	Private support method that creates a generic, blank page.
 *	It gets created either by unarchiving or the user creating a new page.
 */
+ (KTPage *)_insertNewPageWithParent:(KTPage *)parent
{
	OBPRECONDITION([parent managedObjectContext]);
	
	
	// Create the page
	KTPage *result = [NSEntityDescription insertNewObjectForEntityForName:@"Page"
                                                   inManagedObjectContext:[parent managedObjectContext]];
	
	
	// Attach to parent & other relationships
	[result setMaster:[parent master]];
	[result setSite:[parent valueForKeyPath:@"site"]];
	[parent addChildItem:result];	// Must use this method to correctly maintain ordering
	
	return result;
}

+ (KTPage *)insertNewPageWithParent:(KTPage *)aParent;
{
	// Figure out nearest sibling/parent
    KTPage *predecessor = aParent;
	NSArray *children = [aParent childrenWithSorting:SVCollectionSortByDateModified
                                           ascending:NO
                                             inIndex:NO];
	if ([children count] > 0)
	{
		predecessor = [children firstObjectKS];
	}
	
	
    // Create the page
	KTPage *page = [self _insertNewPageWithParent:aParent];
	
	
	// Load properties from parent/sibling
	[page setAllowComments:[predecessor allowComments]];
	[page setIncludeTimestamp:[predecessor includeTimestamp]];
	
	
	return page;
}

#pragma mark Awake

/*!	Early initialization.  Note that we don't know our bundle yet!  Use awakeFromBundle for later init.
*/
- (void)awakeFromInsert
{
	[super awakeFromInsert];
    
    
    // Create a corresponding sidebar
    SVSidebar *sidebar = [NSEntityDescription insertNewObjectForEntityForName:@"Sidebar"
                                                       inManagedObjectContext:[self managedObjectContext]];
    
    [self setSidebar:sidebar];
	
    
    // Placeholder text
    [self setTitle:NSLocalizedString(@"Untitled", "placeholder text")];
	
    
    // Body text. Give it a starting paragraph
    SVRichText *body = [SVRichText insertPageBodyIntoManagedObjectContext:[self managedObjectContext]];
    [body setString:@"<p><br /></p>"];
    [self setArticle:body];
    
    
	id maxTitles = [[NSUserDefaults standardUserDefaults] objectForKey:@"MaximumTitlesInCollectionSummary"];
    if ([maxTitles isKindOfClass:[NSNumber class]])
    {
        [self setPrimitiveValue:maxTitles forKey:@"collectionMaxSyndicatedPagesCount"];
    }
    
    [self setPrimitiveValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"RSSFileName"]
                     forKey:@"RSSFileName"];
    
    
    // Code Injection
    KTCodeInjection *codeInjection = [NSEntityDescription insertNewObjectForEntityForName:@"PageCodeInjection"
                                                                   inManagedObjectContext:[self managedObjectContext]];
    [self setValue:codeInjection forKey:@"codeInjection"];
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *title = [aDictionary valueForKey:kKTDataSourceTitle];
    if ( nil == title )
	{
		// No title specified; use file name (minus extension)
		NSFileManager *fm = [NSFileManager defaultManager];
		title = [[fm displayNameAtPath:[aDictionary valueForKey:kKTDataSourceFileName]] stringByDeletingPathExtension];
	}
	if (nil != title)
	{
		NSString *titleHTML = [[self titleBox] textHTMLString];
		if (nil == titleHTML || [titleHTML isEqualToString:@""])
		{
			[self setTitle:title];
		}
	}
	if ([defaults boolForKey:@"SetDateFromSourceMaterial"])
	{
		if (nil != [aDictionary objectForKey:kKTDataSourceCreationDate])	// date set from drag source?
		{
			[self setValue:[aDictionary objectForKey:kKTDataSourceCreationDate] forKey:@"creationDate"];
		}
		else if (nil != [aDictionary objectForKey:kKTDataSourceFilePath])
		{
			// Get creation date from file if it's not specified explicitly
			NSDictionary *fileAttrs = [[NSFileManager defaultManager]
				fileAttributesAtPath:[aDictionary objectForKey:kKTDataSourceFilePath]
						traverseLink:YES];
			NSDate *date = [fileAttrs objectForKey:NSFileCreationDate];
			[self setValue:date forKey:@"creationDate"];
		}
	}
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
}

#pragma mark Title

@dynamic titleBox;

- (NSString *)title
{
    return [[self titleBox] text];
}
- (void)setTitle:(NSString *)title;
{
    SVPageTitle *titleBox = [self titleBox];
    if (!titleBox)
    {
        titleBox = [NSEntityDescription insertNewObjectForEntityForName:@"PageTitle" inManagedObjectContext:[self managedObjectContext]];
        [self setTitleBox:titleBox];
    }
    [titleBox setText:title];
}
+ (NSSet *)keyPathsForValuesAffectingTitle { return [NSSet setWithObject:@"titleBox.text"]; }

// For bindings.  We can edit title if we aren't root;
- (BOOL)canEditTitle
{
	BOOL result = ![self isRoot];
	return result;
}

- (NSString *)titleHTMLString
{
    return [[self titleBox] textHTMLString];
}

- (void)writeTitle:(id <SVPlugInContext>)context;   // uses rich txt/html when available
{
    [[context HTMLWriter] writeHTMLString:[self titleHTMLString]];
}

#pragma mark Body

@dynamic article;

- (void)writeContent:(SVHTMLContext *)context recursively:(BOOL)recursive;
{
    [super writeContent:context recursively:recursive];
    
    
    // Custom window title if specified
    NSString *windowTitle = [self windowTitle];
    if (windowTitle)
    {
        [context writeText:windowTitle];
        [context writeString:@"\n"];
    }
    
    // Custom meta description if specified
    NSString *meta = [self metaDescription];
    if (meta)
    {
        [context writeText:meta];
        [context writeString:@"\n"];
    }
    
    // Body
    [[self article] writeText:context];
    
    // Children
    if (recursive)
    {
        for (SVSiteItem *anItem in [self sortedChildren])
        {
            [anItem writeContent:context recursively:recursive];
        }
    }
}

#pragma mark Properties

- (void)setSite:(KTSite *)site recursively:(BOOL)recursive;
{
    [super setSite:site recursively:recursive];
    
    if (recursive)
    {
        for (SVSiteItem *anItem in [self childItems])
        {
            [anItem setSite:site recursively:recursive];
        }
    }
}

@dynamic sidebar;
@dynamic showSidebar;

#pragma mark Master

- (NSString *)language { return [[self master] language]; }

#pragma mark Dates

/*  When updating one of the plug-in's properties, also update the modification date
 */
- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    [super setValue:value forUndefinedKey:key];
    
    
    static NSSet *excludedKeys;
    if (!excludedKeys)
    {
        excludedKeys = [[NSSet alloc] initWithObjects:
                        @"shouldUpdateFileNameWhenTitleChanges",
                        @"windowTitle",
                        @"metaDescription",
                        @"publishedDataDigest",
                        nil];
    }
    
    if (![excludedKeys containsObject:key])
    {
        [self setModificationDate:[NSDate date]];
    }
}

#pragma mark Paths

/*	A custom file extension of nil signifies that the value should be taken from the user defaults.
 */
- (NSString *)customPathExtension { return [self wrappedValueForKey:@"customFileExtension"]; }

- (void)setCustomPathExtension:(NSString *)extension
{
	[self setWrappedValue:extension forKey:@"customFileExtension"];
	[self recursivelyInvalidateURL:NO];
}

/*	KTAbstractPage doesn't support recursive operations, so we do instead
 */
- (void)recursivelyInvalidateURL:(BOOL)recursive
{
	[self willChangeValueForKey:@"URL"];
	[self setPrimitiveValue:nil forKey:@"URL"];
    
    [super recursivelyInvalidateURL:recursive];
	
	// Children should be affected last since they depend on parents' path
	if (recursive)
	{
		NSSet *children = [self childItems];
		for (SVSiteItem *anItem in children)
		{
			OBASSERT(![self isDescendantOfItem:anItem]); // lots of assertions for #44139
            OBASSERT(anItem != self);
            OBASSERT(![[anItem childItems] containsObject:self]);
            
            [anItem recursivelyInvalidateURL:YES];
		}
	}
    
	[self didChangeValueForKey:@"URL"];
}

#pragma mark Thumbnail

- (BOOL)writeThumbnail:(SVHTMLContext *)context
              maxWidth:(NSUInteger)width
             maxHeight:(NSUInteger)height
        imageClassName:(NSString *)className
                dryRun:(BOOL)dryRun;
{
    switch ([[self thumbnailType] integerValue])
    {
        case SVThumbnailTypePickFromPage:
        {
            // Grab thumbnail from appropriate graphic and write that
            SVGraphic *source = [self thumbnailSourceGraphic];
            if ([source thumbnailMedia])
            {
                if (!dryRun)
                {
                    // Start anchor
                    [context pushClassName:@"imageLink"];
                    [context startAnchorElementWithPage:self];
                    
                    // Write image itself
                    CGFloat aspectRatio = [source thumbnailAspectRatio];
                    if (aspectRatio > 1.0f)
                    {
                        height = width / aspectRatio;
                    }
                    else if (aspectRatio < 1.0f)
                    {
                        width = height * aspectRatio;
                    }
                    
                    id <SVMedia> media = [source thumbnailMedia];
                    NSString *type = [(SVMediaRecord *)media typeOfFile];
                    
                    [context writeImageWithSourceMedia:media
                                                   alt:@""
                                                 width:[NSNumber numberWithUnsignedInteger:width]
                                                height:[NSNumber numberWithUnsignedInteger:height]
                                                  type:type];
                    
                    // Finish up
                    [context endElement];
                }
                return YES;
            }
            else
            {
                // Write placeholder if desired
                return [super writeThumbnail:context maxWidth:width maxHeight:height imageClassName:className dryRun:dryRun];
            }
        }
            
        case SVThumbnailTypeFirstChildItem:
        {
            // Just ask the page in question to write its thumbnail
            NSArrayController *controller = [SVPagesController controllerWithPagesToIndexInCollection:self];
            
            SVSiteItem *page = [[controller arrangedObjects] firstObjectKS];
            [context addDependencyOnObject:controller keyPath:@"arrangedObjects"];
            
            return [page writeThumbnail:context
                               maxWidth:width
                              maxHeight:height
                         imageClassName:className
                                 dryRun:dryRun];
        }
            
        case SVThumbnailTypeLastChildItem:
        {
            // Just ask the page in question to write its thumbnail
            NSArrayController *controller = [SVPagesController controllerWithPagesToIndexInCollection:self];
            
            SVSiteItem *page = [[controller arrangedObjects] lastObject];
            [context addDependencyOnObject:controller keyPath:@"arrangedObjects"];
            
            return [page writeThumbnail:context
                               maxWidth:width
                              maxHeight:height
                         imageClassName:className
                                 dryRun:dryRun];
        }
            
        default:
            // Hand off to super for custom/no thumbnail
            return [super writeThumbnail:context
                                maxWidth:width
                               maxHeight:height
                          imageClassName:className
                                  dryRun:dryRun];
    }
}

@dynamic thumbnailSourceGraphic;

- (BOOL)validateThumbnailType:(NSNumber **)outType error:(NSError **)error;
{
    SVThumbnailType maxType = ([self isCollection] ? 
                               SVThumbnailTypeLastChildItem : 
                               SVThumbnailTypePickFromPage);
    
    BOOL result = ([*outType intValue] <= maxType);
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSValidationNumberTooLargeError localizedDescription:@"thumbnailType is too large for this type of page"];
    }
    
    return result;
}

- (id)imageRepresentation;
{
    id result;
    if ([[self thumbnailType] integerValue] == SVThumbnailTypePickFromPage)
    {
        result = [[self thumbnailSourceGraphic] imageRepresentation];
    }
    else
    {
        result = [super imageRepresentation];
    }
    
    // Fallback to regular icon
    if (!result)
    {
        result = [NSImage imageNamed:@"toolbar_new_page.tiff"];
    }
    
    return result;
}

- (NSString *)imageRepresentationType;
{
    id result = nil;
    if ([[self thumbnailType] integerValue] == SVThumbnailTypePickFromPage)
    {
        SVGraphic *graphic = [self thumbnailSourceGraphic];
        if ([graphic imageRepresentation])
        {
            result = [graphic imageRepresentationType];
        }
    }
    else
    {
        result = [super imageRepresentationType];
    }
    
    // Fallback to regular icon
    if (!result)
    {
        result = IKImageBrowserNSImageRepresentationType;
    }
    
    return result;
}

#pragma mark Editing

- (KTPage *)pageRepresentation { return self; }

#pragma mark Debugging

// More human-readable description
- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"%@ <%p> %@ : %@ %@ %@", [self class], self, ([self isRoot] ? @"(root)" : ([self isCollection] ? @"(collection)" : @"")),
		[self fileName], [self wrappedValueForKey:@"uniqueID"], [self wrappedValueForKey:@"pluginIdentifier"]];
}

@end
