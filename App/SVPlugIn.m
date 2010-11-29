//
//  SVContentPlugIn.m
//  Sandvox
//
//  Created by Mike on 20/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPlugIn.h"
#import "SVPlugInGraphic.h"

#import "SVPageProtocol.h"

#import "KTDataSourceProtocol.h"
#import "KTElementPlugInWrapper.h"
#import "SVRichText.h"
#import "SVDOMController.h"
#import "SVGraphic.h"
#import "SVHTMLTemplateParser.h"
#import "SVInspectorViewController.h"
#import "SVIndexInspectorViewController.h"
#import "SVIndexPlugIn.h"
#import "KTPage.h"
#import "SVPlugIn.h"
#import "SVSidebar.h"
#import "SVTemplate.h"

#import "NSBundle+KTExtensions.h"

#import "NSManagedObject+KTExtensions.h"


@interface SVPlugIn ()
@property(nonatomic, assign, readwrite) SVPlugInGraphic *container;
- (NSBundle *)bundle;
@end


#pragma mark -


@implementation SVPlugIn

#pragma mark Initialization & Tear Down

- (void)awakeFromFetch; { }

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
    
    
    // Size
    [self makeOriginalSize];
}

- (void)dealloc
{
    [_template release];
    
    [super dealloc];
}

#pragma mark HTML

static id <SVPlugInContext> sCurrentContext;

- (SVTemplate *)HTMLTemplate;
{
    if (!_template)
    {
        // Is there already a globally cached template for us to use?
        NSString *templateName = [self className];
        _template = [SVTemplate templateNamed:templateName];    // it'll be retained in a mo'
        if (_template)
        {
            [_template retain];
        }
        else
        {
            // Have to read in from disk directly then
            NSString *path = [[self bundle] pathForResource:@"Template" ofType:@"html"];
            if (path)
            {
                _template = [[SVTemplate alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]];
                
                // Add to global cache for benefit of other plug-in instances
                [(SVTemplate *)_template setName:templateName];
            }
        }
    }
    
    return _template;
}

- (void)writeHTML:(id <SVPlugInContext>)context;
{
    // add any SVPlugInCSSFiles
    NSArray *cssFiles = [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"SVPlugInCSSFiles"];
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
    
    // Parse our built-in template
    SVTemplate *template = [self HTMLTemplate];
    if ( template )
    {
        SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:[template templateString]
                                                                            component:self];
        
        [parser parseIntoHTMLContext:(SVHTMLContext *)context];
        [parser release];
    }
    
    sCurrentContext = nil;
}

+ (id <SVPlugInContext>)currentContext; { return sCurrentContext; }
- (id <SVPlugInContext>)currentContext; { return [SVPlugIn currentContext]; }

- (NSString *)inlineGraphicClassName;
{
    NSString *result = [[self bundle] objectForInfoDictionaryKey:@"KTCSSClassName"];
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

#pragma mark Layout

- (NSString *)title { return [[self container] title]; }
- (void)setTitle:(NSString *)title { [[self container] setTitle:title]; }

- (BOOL)showsTitle { return [[self container] showsTitle]; }
- (void)setShowsTitle:(BOOL)show { [[self container] setShowsTitle:show]; }

- (BOOL)showsIntroduction { return [[self container] showsIntroduction]; }
- (void)setShowsIntroduction:(BOOL)show { [[self container] setShowsIntroduction:show]; }

- (BOOL)showsCaption { return [[self container] showsCaption]; }
- (void)setShowsCaption:(BOOL)show { [[self container] setShowsCaption:show]; }

- (BOOL)isBordered { return [[self container] isBordered]; }
- (void)setBordered:(BOOL)show { [[self container] setBordered:show]; }

#pragma mark Metrics

- (NSNumber *)width; { return [[self container] width]; }
- (NSNumber *)height; { return [[self container] height]; }

- (void)setWidth:(NSNumber *)width height:(NSNumber *)height;
{
    [[self container] setWidth:width];
    [[self container] setHeight:height];
}

- (NSNumber *)minWidth; { return [NSNumber numberWithInt:200]; }
- (NSNumber *)minHeight; { return [NSNumber numberWithInt:1]; }

- (void)makeOriginalSize;
{
    [self setWidth:[NSNumber numberWithInt:200] height:nil];
}

#pragma mark Resizing

+ (BOOL)isExplicitlySized; { return NO; }

- (NSNumber *)elementWidthPadding; { return nil; }
- (NSNumber *)elementHeightPadding; { return nil; }

- (NSNumber *)constrainedAspectRatio; { return nil; }

#pragma mark Pages

- (void)didAddToPage:(id <SVPage>)page; { }

#pragma mark Thumbnail

- (NSURL *)thumbnailURL; { return nil; }

#pragma mark The Wider World

- (NSBundle *)bundle { return [NSBundle bundleForClass:[self class]]; }

#if DEBUG
- (id)link; { return NSNotApplicableMarker; }   // dirty hack to stop Inspector throwing exceptions
#endif

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
        // are we an Index?
        Class PrincipalClass = [bundle principalClass];
        if ( [PrincipalClass isSubclassOfClass:[SVIndexPlugIn class]] )
        {
            class = [SVIndexInspectorViewController class];
        }
        else 
        {
            class = [SVInspectorViewController class];
        }
    }
    else if (![class isSubclassOfClass:[SVInspectorViewController class]])
    {
        class = nil;
    }
    
    if ( nil == [bundle pathForResource:nibName ofType:@"nib"] )
    {
        nibName = nil;
    }
    
    
    // Make Inspector
    if (nibName || class)
    {
        result = [[class alloc] initWithNibName:nibName bundle:bundle];
        [result setTitle:[[bundle localizedInfoDictionary] objectForKey:@"KTPluginName"]];
        [result autorelease];
    }
    
    return result;
}

#pragma mark Undo

- (void)disableUndoRegistration;
{
    NSUndoManager *undoManager = [[[self container] managedObjectContext] undoManager];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification
                                                        object:undoManager];
    
    [undoManager disableUndoRegistration];
}

- (void)enableUndoRegistration;
{
    NSUndoManager *undoManager = [[[self container] managedObjectContext] undoManager];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification
                                                        object:undoManager];
    
    [undoManager enableUndoRegistration];
}

#pragma mark Pasteboard

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard; { return nil; }

+ (SVPasteboardPriority)priorityForPasteboardItem:(id <SVPasteboardItem>)item; { return SVPasteboardPriorityNone; }

- (BOOL)awakeFromPasteboardItems:(NSArray *)items; { return NO; }

+ (BOOL)supportsMultiplePasteboardItems; { return NO; }

#pragma mark Other

@synthesize container = _container;

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
