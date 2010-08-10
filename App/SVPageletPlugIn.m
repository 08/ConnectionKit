//
//  SVContentPlugIn.m
//  Sandvox
//
//  Created by Mike on 20/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPlugIn.h"
#import "SVPageProtocol.h"

#import "KTDataSourceProtocol.h"
#import "KTHTMLPlugInWrapper.h"
#import "SVRichText.h"
#import "SVDOMController.h"
#import "SVGraphic.h"
#import "SVHTMLTemplateParser.h"
#import "SVInspectorViewController.h"
#import "KTPage.h"
#import "SVPlugIn.h"
#import "SVSidebar.h"
#import "SVTemplate.h"

#import "NSBundle+KTExtensions.h"

#import "NSManagedObject+KTExtensions.h"


NSString *SVPageWillBeDeletedNotification = @"SVPageWillBeDeleted";


@interface SVPlugIn ()
@property(nonatomic, assign, readwrite) id <SVPageletPlugInContainer> container;
@end


#pragma mark -


@implementation SVPlugIn

#pragma mark Initialization & Tear Down

- (void)awakeFromFetch;
{
    [self awakeFromBundleAsNewlyCreatedObject:NO];
}

- (void)awakeFromNew;
{
    // Load initial properties from bundle
    NSBundle *bundle = [self bundle];
    NSDictionary *localizedInfoDictionary = [bundle localizedInfoDictionary];
    NSDictionary *initialProperties = [bundle objectForInfoDictionaryKey:@"KTPluginInitialProperties"];
    
    for (NSString *aKey in initialProperties)
    {
        id value = [initialProperties objectForKey:aKey];
        if ([value isKindOfClass:[NSString class]])
        {
            // Try to localize the string
            NSString *localized = [localizedInfoDictionary objectForKey:aKey];
            if (localized) value = localized;
        }
        
        [self setSerializedValue:value forKey:aKey];
    }
    
    
    // Legacy
    [self awakeFromBundleAsNewlyCreatedObject:YES];
}

#pragma mark HTML

static id <SVPlugInContext> sCurrentContext;

- (void)writeHTML:(id <SVPlugInContext>)context;
{
    // add any KTPluginCSSFilesNeeded
    NSArray *cssFiles = [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"KTPluginCSSFilesNeeded"];
    for ( NSString *filename in cssFiles )
    {
        NSString *cssPath = [[NSBundle bundleForClass:[self class]] pathForResource:filename ofType:nil];
        if ( cssPath )
        {
            NSURL *cssURL = [NSURL fileURLWithPath:cssPath];
            [context addCSSWithURL:cssURL];
        }
    }
    
    
    sCurrentContext = context;
    [self writeInnerHTML:context];
    sCurrentContext = nil;
    
    return;
        
    [[context HTMLWriter] startElement:@"div" idName:[self elementID] className:nil];
    [self writeInnerHTML:context];
    [[context HTMLWriter] endElement];
}

+ (id <SVPlugInContext>)currentContext; { return sCurrentContext; }

- (NSString *)elementID
{
    NSString *result = [NSString stringWithFormat:@"%p", self];
    return result;
}

- (void)writeInnerHTML:(id <SVPlugInContext>)context;
{
    // Parse our built-in template
    SVTemplate *template = [[self bundle] HTMLTemplate];
    if ( template )
    {
        SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:[template templateString]
                                                                            component:self];
        
        [parser parseIntoHTMLContext:(SVHTMLContext *)context];
        [parser release];
    }
    else if ( [[self bundle] objectForInfoDictionaryKey:@"KTTemplateName"] )
    {
        OBPRECONDITION(template); // we're defining a template in Info.plist but there isn't one there!
    }	
}

#pragma mark Identifier

+ (NSString *)plugInIdentifier; // use standard reverse DNS-style string
{
    NSBundle *bundle = [NSBundle bundleForClass:self];
    NSString *result = [bundle bundleIdentifier];
    return result;
}

#pragma mark Storage

+ (NSArray *)plugInKeys; { return [NSArray array]; }

- (id)serializedValueForKey:(NSString *)key;
{
    id result = [self valueForKey:key];
    
    if (![result isKindOfClass:[NSString class]] &&
        ![result isKindOfClass:[NSNumber class]] &&
        ![result isKindOfClass:[NSDate class]])
    {
        result = [NSKeyedArchiver archivedDataWithRootObject:result];
    }
    
    return result;
}

- (void)setSerializedValue:(id)serializedValue forKey:(NSString *)key;
{
    if ([serializedValue isKindOfClass:[NSData class]])
    {
        serializedValue = [NSKeyedUnarchiver unarchiveObjectWithData:serializedValue];
    }
    
    [self setValue:serializedValue forKey:key];
}

- (void)setNilValueForKey:(NSString *)key;  // default implementation calls -setValue:forKey: with 0 number
{
    [self setValue:[NSNumber numberWithInteger:0] forKey:key];
}

#pragma mark Pages

- (void)didAddToPage:(id <SVPage>)page; { }

#pragma mark Thumbnail

- (id <IMBImageItem>)thumbnail; { return nil; }

#pragma mark The Wider World

- (NSBundle *)bundle { return [NSBundle bundleForClass:[self class]]; }

#pragma mark UI

+ (SVInspectorViewController *)makeInspectorViewController;
{
    SVInspectorViewController *result = nil;
    
    // Take a stab at Inspector class name
    NSString *className = [NSStringFromClass([self class])
                           stringByReplacing:@"PlugIn" with:@"Inspector"];
    
    
    // Take a stab at Inspector nib
    NSBundle *bundle = [NSBundle bundleForClass:self];
    NSString *nibName = [bundle objectForInfoDictionaryKey:@"KTPluginNibFile"];
    if ( !nibName ) nibName = className;
    
    Class class = NSClassFromString(className);
    if (!class && nibName)
    {
        class = [SVInspectorViewController class];
    }
    else if (![class isSubclassOfClass:[SVInspectorViewController class]])
    {
        class = nil;
    }
    
    
    // Make Inspector
    if (nibName || class)
    {
        result = [[class alloc] initWithNibName:nibName bundle:bundle];
        [result autorelease];
    }
    
    return result;
}

#pragma mark Other

@synthesize container = _container;

#pragma mark Legacy

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard; { return nil; }

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject { }
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary { }		// we may want to do something different.

@end


#pragma mark -


@implementation SVPlugIn (SVPage)

- (id <SVPage>)pageWithIdentifier:(NSString *)identifier;
{
    KTPage *result = [KTPage
                      pageWithUniqueID:identifier
                      inManagedObjectContext:[(NSManagedObject *)[self container] managedObjectContext]];
    return result;
}

@end
