//
//  AmazonListDelegate.m
//  Amazon List
//
//  Created by Mike on 22/12/2006.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import "AmazonListPlugIn.h"

#import "APManualListProduct.h"
#import "AmazonListInspector.h"

#import <AmazonSupport/AmazonSupport.h>


#import "NSURL+AmazonPagelet.h"


NSString * const APDisplayTabIdentifier = @"display";
NSString * const APProductsOrListTabIdentifier = @"productsOrList";


// LocalizedStringInThisBundle(@"Drag Amazon products here from your web browser", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"Please specify an Amazon list (e.g. a wish list or listmania) to display using the Inspector.", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"This is a placeholder; your Amazon list will appear here once published or if you enable live data feeds in the preferences.", "Placeholder text")
// LocalizedStringInThisBundle(@"This is a placeholder for an Amazon product; It will appear here once published or if you enable live data feeds in the preferences.", "Placeholder text")


@interface AmazonListPlugIn ()
@end


#pragma mark -


@implementation AmazonListPlugIn

#pragma mark Initalization

+ (void)initialize
{
	// Register value transformers
	KSIsEqualValueTransformer *transformer = nil;
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:APLayoutCentered]];
	[NSValueTransformer setValueTransformer:transformer forName:@"AmazonListLayoutIsCentered"];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:APLayoutBullets]];
	[transformer setNegatesResult:YES];
	[NSValueTransformer setValueTransformer:transformer forName:@"AmazonListLayoutIsNotBullets"];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:APLayoutEnhanced]];
	[NSValueTransformer setValueTransformer:transformer forName:@"AmazonListLayoutIsEnhanced"];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:APLayoutEnhanced]];
	[transformer setNegatesResult:YES];
	[NSValueTransformer setValueTransformer:transformer forName:@"AmazonListLayoutIsNotEnhanced"];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:APLayoutRandom]];
	[transformer setNegatesResult:YES];
	[NSValueTransformer setValueTransformer:transformer forName:@"AmazonListLayoutIsNotRandom"];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:AmazonWishList]];
	[NSValueTransformer setValueTransformer:transformer forName:@"AutomaticAmazonListTypeIsWishList"];
	[transformer release];
	
	
	
	// Prepare Amazon operations
	[AmazonOperation setAccessKeyID:@"AKIAILC2YRBONHT2JFVA"];	// amazon_nomoney@karelia.com secret key, no monetary accounts hooked up to this account!
	[AmazonOperation setHash:@"zxPWQOd2RAGbj2z4eQurrD1061DHuXZlgy8/ZpyC"];

	//[AmazonOperation setAssociateID:@"karelsofwa-20"];
}

- (id)init;
{
    self = [super init];
    
    
    // Observer storage
    [self addObserver:self
			  forKeyPath:@"manualListProducts"
				  options:0
				  context:NULL];
    
    
    return self;
}

- (void) awakeFromNewIgnoringWebBrowser
{
    [super awakeFromNew];
    
    
	// When creating a new pagelet, try to use the most recent Amazon store
    NSNumber *lastSelectedStore = [[NSUserDefaults standardUserDefaults] objectForKey:@"AmazonLatestStore"];
    if (lastSelectedStore) [self setStore:[lastSelectedStore integerValue]];
    
    
    // And also most recent layout
    NSNumber *lastLayout = [[NSUserDefaults standardUserDefaults] objectForKey:@"AmazonLastLayout"];
    if (lastLayout) [self setLayout:[lastLayout integerValue]];
    
}

- (void)awakeFromNew
{
    [self awakeFromNewIgnoringWebBrowser];
    
    
    
    // Get the current URL from Safari and look for a possible product or list
    NSURL *browserURL = nil;
    id<SVWebLocation> location = [[NSWorkspace sharedWorkspace] fetchBrowserWebLocation];
    if ( location )
    {
        browserURL = [location URL];
    }
    
    NSString *ASIN = [browserURL amazonProductASIN];	// Product
    if (ASIN && ![ASIN isEqualToString:@""])
    {
        APManualListProduct *product = [[APManualListProduct alloc] initWithURL:browserURL];
        [self insertObject:product inProductsAtIndex:0];
        
        [product release];
    }
}

#pragma mark Dealloc

- (void)dealloc
{
	// Remove old observations
	[self removeObserver:self forKeyPath:@"manualListProducts"];
	
	// End KVO
    for (NSString *aKey in [self productChangeKeyPaths])
    {
        [_products removeObserver:self
             fromObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_products count])]
                      forKeyPath:aKey];
    }
	
					
	// Relase iVars
	[_products release];
	
	[super dealloc];
}

#pragma mark Properties

+ (NSArray *)plugInKeys
{
    return [NSSet setWithObjects:@"store", @"layout", @"showProductPreviews", @"frame", @"showPrices", @"showThumbnails", @"centeredThumbnailWidths", @"showNewPricesOnly", @"showTitles", @"showComments", @"showCreators", @"products", @"showLinkToList", nil];
}

@synthesize store = _store;
- (void)setStore:(AmazonStoreCountry)newStore
{
    _store = newStore;
    
	// Save the new value in the prefs for future plugins
	[[NSUserDefaults standardUserDefaults] setInteger:newStore forKey:@"AmazonLatestStore"];
	
	// Reload the products
	NSEnumerator *enumerator = [[self products] objectEnumerator];
	APManualListProduct *product;
	while (product = [enumerator nextObject]) {
		[product setStore:newStore];
	}
	
	[self loadAllManualListProducts];
}

@synthesize layout = _layout;
- (void) setLayout:(APListLayout)layout;
{
    _layout = layout;
    // Save the new layout to the defaults
    [[NSUserDefaults standardUserDefaults] setInteger:layout
                                               forKey:@"AmazonLastLayout"];
    
    //	Changes to the layout or list source need us to recalculate the availability of the
	//	"showPrices" appearance option
    [self willChangeValueForKey:@"showPricesOptionAvailable"];
    [self didChangeValueForKey:@"showPricesOptionAvailable"];
}

@synthesize showProductPreviews = _showProductPreviews;
@synthesize frame = _frame;

@synthesize showPrices = _showPrices;

@synthesize showThumbnails = _showThumbnails;
- (void) setShowThumbnails:(BOOL)thumbnails;
{
    _showThumbnails = thumbnails;
    
    // When setting showThumbnails to false, ensure showing titles is true
    if (!thumbnails) {
        [self setShowTitles:YES];
    }
}

@synthesize showNewPricesOnly = _showNewPricesOnly;

@synthesize showTitles = _showTitles;
- (void) setShowTitles:(BOOL)titles;
{
    _showTitles = titles;
    
    // When setting showThumbnails to false, ensure showing titles is true
    if (!titles)
    {
        [self setShowThumbnails:YES];
    }
}

@synthesize showComments = _showComments;
@synthesize showCreators = _showCreators;
@synthesize showLinkToList = _showLinkToList;

@synthesize centeredThumbnailWidths = _centeredThumbnailWidths;


#pragma mark KVC / KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
					    change:(NSDictionary *)change
					   context:(void *)context
{
	// Pass on manual list observations
	if ([[self products] indexOfObjectIdenticalTo:object] != NSNotFound)
	{
		[self observeValueForKeyPath:keyPath ofManualListProduct:object change:change context:context];
	}
}

#pragma mark -
#pragma mark Store

- (BOOL)validateStore:(NSNumber **)outStore error:(NSError **)error
{
    AmazonStoreCountry store = [*outStore integerValue];
    
    
	// If there are existing list items, warn the user of the possible implications
		if ([self products] && [[self products] count] > 0)
		{
			NSString *titleFormat = LocalizedStringInThisBundle(@"Change to the %@ Amazon store?", "alert title");
			NSString *storeName = [AmazonECSOperation nameOfStore:store];	// already localized
			NSString *title = [NSString stringWithFormat:titleFormat, storeName];
			
			NSAlert *alert =
				[NSAlert alertWithMessageText:title
								defaultButton:LocalizedStringInThisBundle(@"Change Store", "button text")
							  alternateButton:LocalizedStringInThisBundle(@"Cancel", "button text")
								  otherButton:nil
					informativeTextWithFormat:LocalizedStringInThisBundle(@"Not all products are available in every country. By changing the store, some of the products in your list may no longer be found.", "alert message")];
			
			int result = [alert runModal];
			if (result == NSAlertAlternateReturn) *outStore = [self valueForKey:@"store"];
		}
	
	return YES;
}

#pragma mark Markup

- (NSString *)layoutCSSClassName;
{
    return [[self class] CSSClassNameForLayout:[self layout]];
}

+ (NSString *)CSSClassNameForLayout:(APListLayout)layout;
{
	NSString *result = nil;
	
	switch (layout)
	{
		case APLayoutLeft:
			result = @"amazonListLayoutLeft";
			break;
		case APLayoutRight:
			result = @"amazonListLayoutRight";
			break;
		case APLayoutAlternating:
			result = @"amazonListLayoutAlt";
			break;
		case APLayoutCentered:
			result = @"amazonListLayoutCenter";
			break;
		case APLayoutTwoUp:
			result = @"amazonListLayoutTwoUp";
			break;
		case APLayoutEnhanced:
			result = @"amazonListLayoutEnhanced";
			break;
		case APLayoutRandom:
			result = @"amazonListLayoutRandom";
			break;
        default:
            result = @"";
            break;
	}
	
	return result;
}

- (BOOL)showPricesOptionAvailable
{
	// Not available in all circumstances
	BOOL result = ([self layout] == APLayoutEnhanced ||
				   [self layout] == APLayoutRandom);
				   
	return result;
}

#pragma mark Product Previews

- (void)writeHTML:(id <SVPlugInContext>)context;
{
    [super writeHTML:context];
    
	// If the user has requested it, add the product preview popups javascript to the end of the page
    if ([self showProductPreviews])
	{
		NSString *script = [AmazonECSOperation productPreviewsScriptForStore:[self store]];
		if (script)
		{
			// Only append the script if it's not already there (e.g. if there's > 1 element)
            NSMutableString *ioString = [context endBodyMarkup];
			if ([ioString rangeOfString:script].location == NSNotFound) {
				[ioString appendString:script];
			}
		}
	}
}

#pragma mark Pasteboard

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;
{
    return SVWebLocationGetReadablePasteboardTypes(pasteboard);
}

+ (NSUInteger)priorityForPasteboardItem:(id <SVPasteboardItem>)item
{
    KTSourcePriority result = KTSourcePriorityNone;
    
	NSURL *URL = [item URL];
	if ([URL amazonProductASIN])
	{
        result = KTSourcePriorityIdeal;
	}
	
	return result;
}

- (BOOL)awakeFromPasteboardItems:(NSArray *)items;
{
    BOOL result = NO;
    
    // need some initial properties. #96302
    if (![self layout])
    {
        [self awakeFromNewIgnoringWebBrowser];
    }
    
    for (id <SVPasteboardItem> item in items)
    {
        APManualListProduct *product = [[APManualListProduct alloc] initWithURL:[item URL]];
        [[self mutableArrayValueForKey:@"products"] addObject:product];
        [product release];
        
        result = YES;
    }
    
    return result;
}

+ (BOOL)supportsMultiplePasteboardItems; { return YES; }

@end
