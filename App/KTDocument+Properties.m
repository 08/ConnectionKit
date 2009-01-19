//
//  KTDocument+Properties.m
//  Marvel
//
//  Created by Terrence Talbot on 4/6/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTDocument.h"

#import "Debug.h"

#import "KTDocWindowController.h"
#import "KTDocSiteOutlineController.h"
#import "KTDocumentInfo.h"
#import "KTHTMLInspectorController.h"
#import "KTStalenessManager.h"

#import "NSIndexSet+Karelia.h"
#import "NSObject+Karelia.h"

#import <iMediaBrowser/RBSplitView.h>


@interface KTDocument (PropertiesPrivate)
- (void)updateDefaultDocumentProperty:(NSString *)key;
@end


#pragma mark -


@implementation KTDocument (Properties)

#pragma mark -

/*  We store the thread the document was intialised on so that threading-critical operation
 *  like saves can assert that they're being run on the right thread. You can change this thread
 *  using -setThread, but this shouldn't generally be needed.
 *
 *  Normal documents are on the main thread, but data migration docs work in the background.
 */

- (NSThread *)thread { return myThread; }

- (void)setThread:(NSThread *)thread
{
    [thread retain];
    [myThread release];
    myThread = thread;
}

#pragma mark .... relationships

/*  This method is no longer public, just there for backwards-compatibility. Use -documentInfo instead.
 */
- (KTPage *)root { return [[self documentInfo] root]; }

#pragma mark -
#pragma mark Managers

- (KTMediaManager *)mediaManager
{
	return myMediaManager;
}

- (KTStalenessManager *)stalenessManager
{
	/*if (!myStalenessManager)
	{
		myStalenessManager = [[KTStalenessManager alloc] initWithDocument:self];
	}*/
	
	return myStalenessManager;
}

#pragma mark -
#pragma mark Other

- (KTDocumentInfo *)documentInfo
{
    return myDocumentInfo;
}

- (void)setDocumentInfo:(KTDocumentInfo *)aDocumentInfo
{
    [aDocumentInfo retain];
    [myDocumentInfo release];
    myDocumentInfo = aDocumentInfo;
}

#pragma mark -
#pragma mark Publishing

- (void)setHTMLInspectorController:(KTHTMLInspectorController *)anHTMLInspectorController
{
    [anHTMLInspectorController retain];
    [myHTMLInspectorController release];
    myHTMLInspectorController = anHTMLInspectorController;
}

- (KTHTMLInspectorController *)HTMLInspectorControllerWithoutLoading	// lazily instantiate
{
	return myHTMLInspectorController;
}

- (KTHTMLInspectorController *)HTMLInspectorController	// lazily instantiate
{
	if ( nil == myHTMLInspectorController )
	{
		KTHTMLInspectorController *controller = [[[KTHTMLInspectorController alloc] init] autorelease];
		[self setHTMLInspectorController:controller];
		[self addWindowController:controller];
	}
	return myHTMLInspectorController;
}

#pragma mark -
#pragma mark Document Display Properties

- (BOOL)showDesigns
{
	return myShowDesigns;
}

- (void)setShowDesigns:(BOOL)value
{
	myShowDesigns = value;
}

- (BOOL)displaySiteOutline { return myDisplaySiteOutline; }

- (void)setDisplaySiteOutline:(BOOL)value
{
	myDisplaySiteOutline = value;
	[self updateDefaultDocumentProperty:@"displaySiteOutline"];
}

- (BOOL)displayStatusBar { return myDisplayStatusBar; }

- (void)setDisplayStatusBar:(BOOL)value
{
	myDisplayStatusBar = value;
	[self updateDefaultDocumentProperty:@"displayStatusBar"];
}

- (BOOL)displayEditingControls { return myDisplayEditingControls; }

- (void)setDisplayEditingControls:(BOOL)value
{
	myDisplayEditingControls = value;
	[self updateDefaultDocumentProperty:@"displayEditingControls"];
}

- (BOOL)displaySmallPageIcons { return myDisplaySmallPageIcons; }

- (void)setDisplaySmallPageIcons:(BOOL)aSmall
{
	myDisplaySmallPageIcons = aSmall;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KTDisplaySmallPageIconsDidChange"
														object:self];
														
	[[self windowController] updatePopupButtonSizesSmall:aSmall];
	[self updateDefaultDocumentProperty:@"displaySmallPageIcons"];
}

- (BOOL)displayCodeInjectionWarnings { return myDisplayCodeInjectionWarnings; }

- (void)setDisplayCodeInjectionWarnings:(BOOL)flag
{
	myDisplayCodeInjectionWarnings = flag;
	[self updateDefaultDocumentProperty:@"displayCodeInjectionWarnings"];
}

#pragma mark support

/*	Support method for whenever the user changes a view property of the document.
 *	We write a copy of the last used properties out to the defaults so that new documents can use them.
 */
- (void)updateDefaultDocumentProperty:(NSString *)key
{
	NSDictionary *existingProperties =
		[[NSUserDefaults standardUserDefaults] objectForKey:@"defaultDocumentProperties"];
	
	NSMutableDictionary *updatedProperties;
	if (existingProperties)
	{
		updatedProperties = [NSMutableDictionary dictionaryWithDictionary:existingProperties];
		[updatedProperties setObject:[self valueForKey:key] forKey:key];
	}
	else
	{
		updatedProperties = [NSDictionary dictionaryWithObject:[self valueForKey:key] forKey:key];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:updatedProperties forKey:@"defaultDocumentProperties"];
}

/*	Generally this method is used when saving the document.
 *	We don't want manage these view properties in the model normally since they would be affected by undo/redo.
 *	Instead, they are kept within KTDocument and then only written out at save-time. If the user
 *  happens to hit undo and change the property, it is ignored.
 */
- (void)copyDocumentDisplayPropertiesToModel
{
	// Selected pages
	NSIndexSet *outlineSelectedRowIndexSet = [[[[self windowController] siteOutlineController] siteOutline] selectedRowIndexes];
	[[self documentInfo] setLastSelectedRows:[outlineSelectedRowIndexSet indexSetAsString]];
	
	
	// Source Outline width
	float width = [[[[self windowController] siteOutlineSplitView] subviewAtPosition:0] dimension];
	[[self documentInfo] setInteger:width forKey:@"sourceOutlineSize"];
	
	
	// Icon size
	[[self documentInfo] setBool:[self displaySmallPageIcons] forKey:@"displaySmallPageIcons"];
	
	
	// Window size
	NSWindow *window = [[self windowController] window];
	if (window)
	{
		[[self documentInfo] setDocWindowContentRect:[window contentRectForFrameRect:[window frame]]];
	}
}

#pragma mark -
#pragma mark *valueForKey: support

- (id)wrappedInheritedValueForKey:(NSString *)aKey
{
	OFF((@"WARNING: wrappedInheritedValueForKey: %@ is being called on KTDocument -- is this a property stored in defaults?", aKey));
    id result = [[self documentInfo] valueForKey:aKey];
	if ( nil == result )
	{
		result = [[NSUserDefaults standardUserDefaults] objectForKey:aKey];
		if ( nil != result )
		{
			// for now, we're going to specialize support for known entities
			// in the model that we want to be inheritied.
			KTDocumentInfo *documentInfo = [self documentInfo];
//				[documentInfo lockPSCAndMOC];
			[documentInfo setPrimitiveValue:result forKey:aKey];
//				[self refreshObjectInAllOtherContexts:(KTManagedObject *)documentInfo];
//				[documentInfo unlockPSCAndMOC];
		}
	}
	return result;
}

- (void)setWrappedInheritedValue:(id)aValue forKey:(NSString *)aKey
{
	OFF((@"WARNING: setWrappedInheritedValue:forKey: %@ is being called on KTDocument -- is this a property stored in defaults?", aKey));

	[[self documentInfo] setValue:aValue forKey:aKey];
	
	// we only want to be storing property values in defaults
	// for now, we're going to specialize support for known entities
	// in the model that we want to be inheritied.
	id value = aValue;
	if ( [aKey isEqualToString:@"hostProperties"] )
	{
		value = [value dictionary]; // convert KTStoredSet to NSDictionary
	}
	[[NSUserDefaults standardUserDefaults] setObject:value forKey:aKey];
}

@end
