//
//  SVPlugInGraphicFactory.m
//  Sandvox
//
//  Created by Mike on 15/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPlugInGraphicFactory.h"

#import "KTDataSourceProtocol.h"
#import "KTElementPlugInWrapper.h"
#import "SVPlugInGraphic.h"

#import "KSWebLocation+SVWebLocation.h"

#import "NSImage+Karelia.h"


@implementation SVPlugInGraphicFactory

- (id)initWithBundle:(NSBundle *)bundle;
{
    [self init];
    _bundle = [bundle retain];
    return self;
}

- (void)dealloc;
{
    [_bundle release];
    [_class release];
    [_icon release];
	[_pageIcon release];

    [super dealloc];
}

#pragma mark Properties

- (NSString *)identifier; { return [[self plugInBundle] bundleIdentifier]; }

- (Class)plugInClass;
{
    if (!_class)
    {
        _class = [[[self plugInBundle] principalClass] retain];
    }
    return _class;
}

@synthesize plugInBundle = _bundle;

- (NSString *)name;
{
    NSString *result = [[self plugInBundle] objectForInfoDictionaryKey:@"KTPluginName"];
    if (!result) result = [[self plugInBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (!result) result = [[self plugInBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
    return result;
}

- (NSString *)graphicDescription; { return [[self plugInBundle] objectForInfoDictionaryKey:@"SVPlugInDescription"]; }

- (NSImage *)iconWithName:(NSString *)aName;
{
	NSImage *result = nil;
	// It could be a relative (to the bundle) or absolute path
	NSString *filename = [[self plugInBundle] objectForInfoDictionaryKey:aName];
	NSString *path = nil;
	if ([filename isAbsolutePath])
	{
		path = filename;
	}
	else
	{
		path = [[self plugInBundle] pathForImageResource:filename];
		if (!path)
		{
			path = [[NSBundle mainBundle] pathForImageResource:filename];
		}
	}
	
	// TODO: We should not be referencing absolute paths.  Instead, we should check for 'XXXX' pattern and convert that to an OSType.
	
	//	Create the icon, falling back to the broken image if necessary
	/// BUGSID:34635	Used to use -initByReferencingFile: but seems to upset Tiger and the Pages/Pagelets popups
	result = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	if (!result)
	{
		result = [NSImage brokenImage];
	}
	
	return result;
}

- (NSImage *)icon;
{
	// The icon is cached; load it if not cached yet
	if (!_icon)
	{
		_icon = [[self iconWithName:@"SVIconPath"] retain];
	}
	return _icon;
}

- (NSImage *)pageIcon;
{
	// The icon is cached; load it if not cached yet
	if (!_pageIcon)
	{
		_pageIcon = [[self iconWithName:@"KTPageIconName"] retain];
	}
	return _pageIcon;
}

#pragma mark Factory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVGraphic *result = [SVPlugInGraphic
                         insertNewGraphicWithPlugInIdentifier:[self identifier]
                         inManagedObjectContext:context];
    
    // Guess title
    [result setTitle:[self name]];
    
    return result;
}

- (NSArray *)readablePasteboardTypes;
{
    NSArray *result = [KSWebLocation readableTypesForPasteboard:nil];
    return result;
}

- (SVPlugInPasteboardReadingOptions)readingOptionsForType:(NSString *)type
                                               pasteboard:(NSPasteboard *)pasteboard;
{
    SVPlugInPasteboardReadingOptions result = SVPlugInPasteboardReadingAsWebLocation;
    return result;
}

- (NSUInteger)priorityForPasteboardItem:(id <SVPasteboardItem>)item;
{
    NSUInteger result = [super priorityForPasteboardItem:item];
    
    @try
    {
        result = [[self plugInClass] priorityForPasteboardItem:item];
    }
    @catch (NSException *exception)
    {
        // TODO: log
    }
    
    return result;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ %@", [super description], [self plugInClass]];
}

@end
