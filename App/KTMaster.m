//
//  KTMaster.m
//  Marvel
//
//  Created by Mike on 23/10/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTMaster.h"

#import "KT.h"
#import "KTArchivePage.h"
#import "KTDesignPlaceholder.h"
#import "KTDocument.h"
#import "KTSite.h"
#import "KTHostProperties.h"
#import "SVHTMLContext.h"
#import "KTImageScalingSettings.h"
#import "KTImageScalingURLProtocol.h"
#import "SVLogoImage.h"
#import "SVMediaRecord.h"
#import "SVTitleBox.h"

#import "NSArray+Karelia.h"
#import "NSAttributedString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSString+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import <AddressBook/AddressBook.h>


@interface KTMaster ()
@property(nonatomic, copy) NSString *designIdentifier;
@property(nonatomic, retain, readwrite) SVLogoImage *logo;
@end


#pragma mark -


@implementation KTMaster

#pragma mark Initialization

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	
	// Prepare our continue reading link
	NSString *continueReadingLink =
		NSLocalizedString(@"Continue reading @@", "Link to read a full article. @@ is replaced with the page title");
	[self setPrimitiveValue:continueReadingLink forKey:@"continueReadingLinkFormat"];
	
	
	// Enable/disable graphical text
    BOOL imageReplacement = [[NSUserDefaults standardUserDefaults] boolForKey:@"enableImageReplacement"];
	[self setEnableImageReplacement:[NSNumber numberWithBool:imageReplacement]];
	
	
	// Timestamp
	[self setTimestampFormat:[[NSUserDefaults standardUserDefaults] integerForKey:@"timestampFormat"]];
    
    
    // Code Injection
    KTCodeInjection *codeInjection = [NSEntityDescription insertNewObjectForEntityForName:@"MasterCodeInjection"
                                                                   inManagedObjectContext:[self managedObjectContext]];
    [self setValue:codeInjection forKey:@"codeInjection"];
    
    
    
    // Site Title. Guess from a variery of sources
    SVTitleBox *box = [NSEntityDescription insertNewObjectForEntityForName:@"SiteTitle" inManagedObjectContext:[self managedObjectContext]];
    
    ABPerson *person = [[ABAddressBook sharedAddressBook] me];
    NSString *title = [person valueForProperty:kABOrganizationProperty];
    if ([title length] <= 0)
    {
        NSMutableArray *names = [[NSMutableArray alloc] initWithCapacity:2];
        NSString *aName = [person valueForProperty:kABFirstNameProperty];
        if (aName) [names addObject:aName];
        aName = [person valueForProperty:kABLastNameProperty];
        if (aName) [names addObject:aName];
        
        title = [names componentsJoinedByString:@" "];
        [names release];
    }
    
    if ([title length] <= 0)
    {
        title = NSFullUserName();
    }
    
    if ([title length] <= 0)
    {
        title = NSLocalizedString(@"My Website", "site title");
    }
    
    [box setText:title];
    [self setSiteTitle:box];
    
    
    
    // Tagline
    box = [NSEntityDescription insertNewObjectForEntityForName:@"SiteSubtitle" inManagedObjectContext:[self managedObjectContext]];
    [box setText:NSLocalizedString(@"Double-click to edit", "placeholder")];
    [self setSiteSubtitle:box];

    
    // Footer
    box = [NSEntityDescription insertNewObjectForEntityForName:@"Footer" inManagedObjectContext:[self managedObjectContext]];
    [box setTextHTMLString:[self defaultCopyrightHTML]];
    [self setFooter:box];
    
    
    // Logo
    SVLogoImage *logo = [NSEntityDescription insertNewObjectForEntityForName:@"Logo"
                                                      inManagedObjectContext:[self managedObjectContext]];
    [logo setConstrainProportions:YES];
    [self setLogo:logo];
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	
    // Existing sites may not have their timestamp format set properly
	if (![self timestampFormat])
	{
		[self setTimestampFormat:[[NSUserDefaults standardUserDefaults] integerForKey:@"timestampFormat"]];
	}
}

#pragma mark Site Title

@dynamic siteTitle;
@dynamic siteSubtitle;

#pragma mark Footer

@dynamic footer;

- (NSString *)defaultCopyrightHTML
{
	NSString *result = [[NSBundle mainBundle] localizedStringForString:@"copyrightHTML" language:[self valueForKey:@"language"]
		fallback:NSLocalizedStringWithDefaultValue(@"copyrightHTML", nil, [NSBundle mainBundle], @"Parting Words (copyright, contact information, etc.)", @"Default text for page bottom")];
	return result;
}

#pragma mark Design

- (KTDesign *)design
{
	[self willAccessValueForKey:@"design"];
	KTDesign *result = [self primitiveValueForKey:@"design"];
	[self didAccessValueForKey:@"design"];
	
	if (!result)
	{
		NSString *identifier = [self designIdentifier];
        if (identifier)
        {
            result = [KTDesign pluginWithIdentifier:identifier];
            
            // In the event that the design cannot be found, we create a placeholder object
            if (!result)    
            {
                result = [[[KTDesignPlaceholder alloc] initWithBundleIdentifier:identifier] autorelease];
            }
        }
		
        [self setPrimitiveValue:result forKey:@"design"];
	}
	
	return result;
}

@dynamic designIdentifier;

/*  Special private method where you supply ONE of the parameters
 */
- (void)_setDesignIdentifier:(NSString *)identifier xorDesign:(KTDesign *)design
{
    if (!identifier)
    {
        identifier = [design identifier];
        OBASSERT(identifier);
    }
    else if (!design)
    {
        design = [KTDesign pluginWithIdentifier:identifier];
    }
    else
    {
        OBASSERT_NOT_REACHED("You should specify a design OR an identifier");
    }
    
    
    // OK, we have an identifier (and hopefully a design), let's do this thing!
    [self willChangeValueForKey:@"design"];
	[self setPrimitiveValue:design forKey:@"design"];
	[self didChangeValueForKey:@"design"];
	
	[self setDesignIdentifier:identifier];
}

- (void)setDesign:(KTDesign *)design
{
	OBASSERT(design);
    
    // Currently, we operate this as a neat cover 
	[self _setDesignIdentifier:nil xorDesign:design];
}

/*  This method is used when a design's identifier is known, but the design itself is unavailable. (e.g. importing old docs)
 */
- (void)setDesignBundleIdentifier:(NSString *)identifier
{
    OBPRECONDITION(identifier); 
    
    [self _setDesignIdentifier:identifier xorDesign:nil];
}

- (NSURL *)designDirectoryURL
{
	
    NSString *designDirectoryName = [[self design] remotePath];
    OBASSERT(designDirectoryName);
    
    NSURL *siteURL = [[[[(NSSet *)[self valueForKey:@"pages"] anyObject] site] hostProperties] siteURL];	// May be nil
    NSURL *result = [NSURL URLWithPath:designDirectoryName relativeToURL:siteURL isDirectory:YES];
	
    OBPOSTCONDITION(result);
	return result;
}

- (NSSize)thumbnailImageSize
{
	KTImageScalingSettings *settings = [[self design] imageScalingSettingsForUse:@"thumbnailImage"];
	NSSize result = [settings size];
	return result;
}

#pragma mark Banner

@dynamic banner;

- (void)setBannerWithContentsOfURL:(NSURL *)URL;   // autodeletes the old one
{
    SVMediaRecord *media = [SVMediaRecord mediaWithURL:URL entityName:@"Banner" insertIntoManagedObjectContext:[self managedObjectContext] error:NULL];
    
    [self replaceMedia:media forKeyPath:@"banner"];
}

@dynamic bannerType;

- (void)writeBannerCSS:(SVHTMLContext *)context;
{	
	// If the user has specified a custom banner and the design supports it, load it in
	if ([[self bannerType] boolValue] && [[self banner] fileURL])
	{
		NSString *bannerCSSSelector = [[self design] bannerCSSSelector];
        if (bannerCSSSelector)
        {
            NSMutableDictionary *scalingProperties = [[[self design] imageScalingPropertiesForUse:@"bannerImage"] mutableCopy];
            OBASSERT(scalingProperties);
            [scalingProperties setObject:(NSString *)kUTTypeJPEG forKey:@"fileType"];
            
            SVMediaRecord *banner = [self banner];
            
            NSURL *URL = [NSURL sandvoxImageURLWithFileURL:[banner fileURL]
                                         scalingProperties:scalingProperties];
            [scalingProperties release];
            
            URL = [context addBannerWithURL:URL];
            
            
            NSString *css = [bannerCSSSelector stringByAppendingFormat:@" { background-image: url(\"%@\"); }\n", [URL absoluteString]];
            
            
            [context addCSSString:css];
        }
	}
    
    [context addDependencyOnObject:self keyPath:@"bannerType"];
}

#pragma mark Logo

@dynamic logo;

#pragma mark Favicon

- (id <IMBImageItem>)favicon
{
    id <IMBImageItem> result = nil;
    
    if ([[self faviconType] integerValue] > 0)
    {
        result = [self faviconMedia];
    }
    
    return result;
}

+ (NSSet *)keyPathsForValuesAffectingFavicon;
{
    return [NSSet setWithObjects:@"faviconType", @"faviconMedia", nil];
}

@dynamic faviconType;
@dynamic faviconMedia;

- (void)setFaviconWithContentsOfURL:(NSURL *)URL;   // autodeletes the old one
{    
    SVMediaRecord *media = [SVMediaRecord mediaWithURL:URL entityName:@"Favicon" insertIntoManagedObjectContext:[self managedObjectContext] error:NULL];
    
    [self replaceMedia:media forKeyPath:@"faviconMedia"];
}

#pragma mark Graphical Text

@dynamic enableImageReplacement;
@dynamic graphicalTitleSize;

#pragma mark Timestamp

- (NSDateFormatterStyle)timestampFormat { return [self wrappedIntegerForKey:@"timestampFormat"]; }

- (void)setTimestampFormat:(NSDateFormatterStyle)format
{
	[self setWrappedInteger:format forKey:@"timestampFormat"];
}

@dynamic timestampShowTime;

#pragma mark Language

@dynamic language;
- (BOOL)validateLanguage:(NSString **)language error:(NSError **)error;
{
    // Attempts at nil are coerced back to current value. Little bit of a hack. #78003
    if (!*language) *language = [self language];
    
    return YES;
}

#pragma mark Site Outline

- (KTCodeInjection *)codeInjection
{
    return [self wrappedValueForKey:@"codeInjection"];
}

#pragma mark Comments

// TODO: this is kind of hacky, for Sandvox 2 all should be combined
// into the fewest, flexible attributes possible
- (KTCommentsProvider)commentsProvider
{
	return (KTCommentsProvider)[[self valueForUndefinedKey:@"commentsProvider"] intValue];
}

- (void)setCommentsProvider:(KTCommentsProvider)aKTCommentsProvider
{
	NSSet *keys = [NSSet setWithObjects:@"wantsDisqus", @"wantsJSKit", @"wantsHaloscan", @"wantsIntenseDebate", nil];
	[self willChangeValuesForKeys:keys];
	[self setValue:[NSNumber numberWithInt:aKTCommentsProvider] forUndefinedKey:@"commentsProvider"];
	[self didChangeValuesForKeys:keys];
	
	// for backward compatibility with 1.5.4
	if ( KTCommentsProviderJSKit == aKTCommentsProvider )
	{
		[self setValue:[NSNumber numberWithBool:YES] forUndefinedKey:@"wantsJSKit"];
		[self setValue:[NSNumber numberWithBool:NO] forUndefinedKey:@"wantsHaloscan"];
	}
	else if ( KTCommentsProviderHaloscan == aKTCommentsProvider )
	{
		[self setValue:[NSNumber numberWithBool:YES] forUndefinedKey:@"wantsHaloscan"];
		[self setValue:[NSNumber numberWithBool:NO] forUndefinedKey:@"wantsJSKit"];
	}
	else
	{
		[self setValue:[NSNumber numberWithBool:NO] forUndefinedKey:@"wantsHaloscan"];
		[self setValue:[NSNumber numberWithBool:NO] forUndefinedKey:@"wantsJSKit"];
	}
}

- (BOOL)wantsIntenseDebate
{
	return (KTCommentsProviderIntenseDebate == [self commentsProvider]);
}

- (void)setWantsIntenseDebate:(BOOL)aBool
{
	[self setCommentsProvider:KTCommentsProviderIntenseDebate];
}

- (NSString *)IntenseDebateAccountID
{
	return [self valueForUndefinedKey:@"IntenseDebateAccountID"];
}

- (void)setIntenseDebateAccountID:(NSString *)aString
{
	[self setValue:aString forUndefinedKey:@"IntenseDebateAccountID"];
}

- (BOOL)wantsDisqus
{
	return (KTCommentsProviderDisqus == [self commentsProvider]);
}

- (void)setWantsDisqus:(BOOL)aBool
{
	[self setCommentsProvider:KTCommentsProviderDisqus];
}

- (NSString *)disqusShortName
{
	return [self valueForUndefinedKey:@"disqusShortName"];
}

- (void)setDisqusShortName:(NSString *)aString
{
	[self setValue:aString forUndefinedKey:@"disqusShortName"];
}

- (BOOL)wantsHaloscan
{
	return (KTCommentsProviderHaloscan == [self commentsProvider]);
}

- (void)setWantsHaloscan:(BOOL)aBool
{
	[self setCommentsProvider:KTCommentsProviderHaloscan];
}

- (BOOL)wantsJSKit
{
	return (KTCommentsProviderJSKit == [self commentsProvider]);
}

- (void)setWantsJSKit:(BOOL)aBool
{
	[self setCommentsProvider:KTCommentsProviderJSKit];
}

- (NSString *)JSKitModeratorEmail
{
	return [self valueForUndefinedKey:@"JSKitModeratorEmail"];
}

- (void)setJSKitModeratorEmail:(NSString *)aString
{
	[self setValue:aString forUndefinedKey:@"JSKitModeratorEmail"];
}

#pragma mark Placeholder Image

- (SVMediaRecord *)makePlaceholdImageMediaWithEntityName:(NSString *)entityName;
{
    NSURL *URL = [[self design] placeholderImageURL];
    if (!URL)
    {
        URL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForImageResource:@"placeholder"]];
    }
    OBASSERT(URL);
    
    
    return [SVMediaRecord placeholderMediaWithURL:URL
                                       entityName:entityName
                   insertIntoManagedObjectContext:[self managedObjectContext]];
}

#pragma mark Support

- (BOOL)usesExtensiblePropertiesForUndefinedKey:(NSString *)key
{
    BOOL result = [super usesExtensiblePropertiesForUndefinedKey:key];
    
    if ([key isEqualToString:@"commentsProvider"])
    {
        result = YES;
    }
    
    return result;
}


@end


#pragma mark -


/*  KTDesign is not publicly exposed to plug-ins. So, we have to mirror any methods they need here.
 */

@implementation KTMaster (PluginAPI)

- (NSDictionary *)imageScalingPropertiesForUse:(NSString *)mediaUse
{
    return [[self design] imageScalingPropertiesForUse:mediaUse];
}

@end


#pragma mark -


@implementation KTMaster (Deprecated)

#pragma mark Site Title

- (NSString *)siteTitleHTMLString
{
    return [[self siteTitle] textHTMLString];
}

+ (NSSet *)keyPathsForValuesAffectingSiteTitleHTMLString
{
    return [NSSet setWithObject:@"siteTitle.textHTMLString"];
}

- (NSString *)siteTitleText	// get title, but without attributes
{
	return [[self siteTitle] text];
}

- (void)setSiteTitleText:(NSString *)value
{
	[[self siteTitle] setText:value];
}

+ (NSSet *)keyPathsForValuesAffectingSiteTitleText
{
    return [NSSet setWithObject:@"siteTitle.textHTMLString"];
}

#pragma mark Site Subtitle

- (NSString *)siteSubtitleHTMLString
{
    return [[self siteSubtitle] textHTMLString];
}

+ (NSSet *)keyPathsForValuesAffectingSiteSubtitleHTMLString
{
    return [NSSet setWithObject:@"siteSubtitle.textHTMLString"];
}

- (NSString *)siteSubtitleText	// get title, but without attributes
{
	return [[self siteSubtitle] text];
}

- (void)setSiteSubtitleText:(NSString *)value
{
	[[self siteSubtitle] setText:value];
}

+ (NSSet *)keyPathsForValuesAffectingSiteSubtitleText
{
    return [NSSet setWithObject:@"siteSubtitle.textHTMLString"];
}

@end
