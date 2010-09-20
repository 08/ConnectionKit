//
//  KTPageDetailsController.m
//  Marvel
//
//  Created by Mike on 04/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//
#import <QuartzCore/QuartzCore.h>
#import "KTPageDetailsController.h"
#import "KSShadowedRectView.h"
#import "KSPopUpButton.h"
#import "KSValidateCharFormatter.h"
#import "KSFocusingTextField.h"
#import "MAAttachedWindow.h"
#import "NSImage+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "SVPagesController.h"
#import "SVSiteItem.h"
#import "KSURLFormatter.h"
#import "SVMediaProtocol.h"
#import "SVDownloadSiteItem.h"
#import "SVMediaRecord.h"
#import "KTDocument.h"
#import "KTDocWindowController.h"
#import "SVURLPreviewViewController.h"

#import "NTBoxView.h"

#import "NSCharacterSet+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"

static NSString *sMetaDescriptionObservationContext = @"-metaDescription observation context";
static NSString *sWindowTitleObservationContext = @"-windowTitle observation context";
static NSString *sFileNameObservationContext = @"-fileName observation context";
static NSString *sBaseExampleURLStringObservationContext = @"-baseExampleURLString observation context";
static NSString *sTitleObservationContext = @"-titleText observation context";
static NSString *sSelectedObjectsObservationContext = @"-selectedObjects observation context";
static NSString *sSelectedViewControllerObservationContext = @"-selectedViewController observation context";
static NSString *sCharacterDescription0Count = nil;
static NSString *sCharacterDescription1Count = nil;
static NSString *sCharacterDescriptionPluralCountFormat = nil;

#define ATTACHED_WINDOW_TRANSP 0.6

enum { kUnknownPageDetailsContext, kFileNamePageDetailsContext, kWindowTitlePageDetailsContext, kMetaDescriptionPageDetailsContext
};

@interface KTPageDetailsController ()
- (void)metaDescriptionDidChangeToValue:(id)value;
- (void)windowTitleDidChangeToValue:(id)value;
- (void)fileNameDidChangeToValue:(id)value;
- (void) resetTitlePlaceholderToComboTitleText:(NSString *)comboTitleText;
- (void) resetDescriptionPlaceholder:(NSString *)metaDescriptionText;
- (void) layoutPageURLComponents;
- (NSColor *)metaDescriptionCharCountColor;
- (NSColor *)windowTitleCharCountColor;
- (NSColor *)fileNameCharCountColor;
- (void) updateFieldsBasedOnSelectedSiteOutlineObjects:(NSArray *)selObjects;
- (void)updateWidthForActiveTextField:(NSTextField *)textField;
- (void) rebindWindowTitleAndMetaDescriptionFields;
@end


#pragma mark -


@implementation KTPageDetailsController

+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	sCharacterDescription0Count = NSLocalizedString(@"0 characters", @"format string for showing that ZERO characters have been typed");
	sCharacterDescription1Count = NSLocalizedString(@"1 character", @"format string for showing that ONE character has been typed");
	sCharacterDescriptionPluralCountFormat = NSLocalizedString(@"%d characters", @"format string for showing how many characters have been typed");

	[pool release];
}

@synthesize activeTextField = _activeTextField;
@synthesize attachedWindow = _attachedWindow;
@synthesize whatKindOfItemsAreSelected = _whatKindOfItemsAreSelected;
@synthesize initialWindowTitleBindingOptions = _initialWindowTitleBindingOptions;
@synthesize initialMetaDescriptionBindingOptions = _initialMetaDescriptionBindingOptions;

#pragma mark -
#pragma mark Init & Dealloc

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSViewBoundsDidChangeNotification
												  object:[self view]];
	
	self.view = nil;		// stop observing early.
	
	self.activeTextField = nil;
	[_metaDescriptionCount release];
	[_windowTitleCount release];
	[_fileNameCount release];
	self.initialWindowTitleBindingOptions = nil;
	self.initialMetaDescriptionBindingOptions = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark View

- (void)setView:(NSView *)aView
{	
	// Remove observers
	if (!aView)
	{
		[oPagesController removeObserver:self forKeyPath:@"selection.metaDescription"];
		[oPagesController removeObserver:self forKeyPath:@"selection.windowTitle"];
		[oPagesController removeObserver:self forKeyPath:@"selection.fileName"];
		[oPagesController removeObserver:self forKeyPath:@"selection.baseExampleURLString"];
		[oPagesController removeObserver:self forKeyPath:@"selection.title"];
		[oPagesController removeObserver:self forKeyPath:@"selectedObjects"];
				
		[[oDocWindowController webContentAreaController] removeObserver:self forKeyPath:@"selectedViewController"];

	}
	
	[super setView:aView];
}

#pragma mark -
#pragma mark Appearance

- (void)awakeFromNib
{
	if (!_awokenFromNib)
	{
		// Save these so we can restore them quickly when we are re-binding
		self.initialWindowTitleBindingOptions = [[oWindowTitleField infoForBinding:NSValueBinding] valueForKey:NSOptionsKey];
		self.initialMetaDescriptionBindingOptions = [[oMetaDescriptionField infoForBinding:NSValueBinding] valueForKey:NSOptionsKey];
		
		[oExternalURLField setFormatter:[[[KSURLFormatter alloc] init] autorelease]];
		
		// Detail panel needs the right appearance
		
		[[self view] setPostsFrameChangedNotifications:YES];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(backgroundFrameChanged:)
													 name:NSViewFrameDidChangeNotification
												   object:[self view]];
		
		[self layoutPageURLComponents];
		
		// Observe changes to the meta description and fake an initial observation
		[oPagesController addObserver:self
						   forKeyPath:@"selection.metaDescription"
							  options:NSKeyValueObservingOptionNew
							  context:sMetaDescriptionObservationContext];
		[self metaDescriptionDidChangeToValue:[oPagesController valueForKeyPath:@"selection.metaDescription"]];
		[self resetDescriptionPlaceholder:[oPagesController valueForKeyPath:@"selection.metaDescription"]];
		
		[oPagesController addObserver:self
						   forKeyPath:@"selection.windowTitle"
							  options:NSKeyValueObservingOptionNew
							  context:sWindowTitleObservationContext];
		[self windowTitleDidChangeToValue:[oPagesController valueForKeyPath:@"selection.windowTitle"]];
		[oPagesController addObserver:self
						   forKeyPath:@"selection.fileName"
							  options:NSKeyValueObservingOptionNew
							  context:sFileNameObservationContext];
		[self fileNameDidChangeToValue:[oPagesController valueForKeyPath:@"selection.fileName"]];
		
		[oPagesController addObserver:self
						   forKeyPath:@"selection.baseExampleURLString"
							  options:NSKeyValueObservingOptionNew
							  context:sBaseExampleURLStringObservationContext];
		
		
		[oPagesController addObserver:self
						   forKeyPath:@"selection.title"
							  options:NSKeyValueObservingOptionNew
							  context:sTitleObservationContext];
		[self resetTitlePlaceholderToComboTitleText:[oPagesController valueForKeyPath:@"selection.comboTitleText"]];
		
		[oPagesController addObserver:self
						   forKeyPath:@"selectedObjects"
							  options:NSKeyValueObservingOptionNew
							  context:sSelectedObjectsObservationContext];
		[self updateFieldsBasedOnSelectedSiteOutlineObjects:[oPagesController selectedObjects]];
		
		[[oDocWindowController webContentAreaController]
		 addObserver:self
		 forKeyPath:@"selectedViewController"
		 options:NSKeyValueObservingOptionNew
		 context:sSelectedViewControllerObservationContext];
		[self rebindWindowTitleAndMetaDescriptionFields];
		
		
		/// turn off undo within the cell to avoid exception
		/// -[NSBigMutableString substringWithRange:] called with out-of-bounds range
		/// this still leaves the setting of keywords for the page undo'able, it's
		/// just now that typing inside the field is now not undoable
		//[[oKeywordsField cell] setAllowsUndo:NO];
		
		
		// Limit entry in file name fields
		NSCharacterSet *illegalCharSetForPageTitles = [[NSCharacterSet legalPageTitleCharacterSet] invertedSet];
		NSFormatter *formatter = [[[KSValidateCharFormatter alloc]
								   initWithIllegalCharacterSet:illegalCharSetForPageTitles] autorelease];
		[oFileNameField setFormatter:formatter];
		
		[oExtensionPopup bind:@"defaultValue"
					 toObject:oPagesController
				  withKeyPath:@"selection.defaultFileExtension"
					  options:nil];
		
		_awokenFromNib = YES;
	}
}

#pragma mark -
#pragma mark Count fields

/*  This code manages the meta description field in the Page Details panel. It's a tad complicated,
 *  so here's how it works:
 *
 *  For the really simple stuff, you can bind directly to the object controller responsible for the
 *  Site Outline selection. i.e. The meta description field is bound this way. Its contents are
 *  saved back to the model ater the user ends editing
 *
 *  To complicate matters, we have a count label. This is derived from whatever is currently
 *  entered into the description field. It does NOT map directly to what is in the model. The
 *  count label is bound directly to the -metaDescriptionCount property of
 *  KTPageDetailsController. To update the GUI, you need to call -setMetaDescriptionCount:
 *  This property is an NSNumber as it needs to return NSMultipleValuesMarker sometimes. We update
 *  the count in response to either:
 *
 *      A)  The selection/model changing. This is detected by observing the Site Outline controller's
 *          selection.metaDescription property
 *      B)  The user editing the meta description field. This is detected through NSControl's
 *          delegate methods. We do NOT store these changes into the model immediately as this would
 *          conflict with the user's expectations of how undo/redo should work.
 *
 * This count behavior is reflected similarly with the windowTitle property.
 */

- (NSNumber *)metaDescriptionCount { return _metaDescriptionCount; }

- (void)setMetaDescriptionCount:(NSNumber *)count
{
	[count retain];
	[_metaDescriptionCount release];
	_metaDescriptionCount = count;
}

- (NSNumber *)windowTitleCount { return _windowTitleCount; }

- (void)setWindowTitleCount:(NSNumber *)count
{
	[count retain];
	[_windowTitleCount release];
	_windowTitleCount = count;
}

- (NSNumber *)fileNameCount { return _fileNameCount; }

- (void)setFileNameCount:(NSNumber *)count
{
	[count retain];
	[_fileNameCount release];
	_fileNameCount = count;
}

// Properly pluralizing character count strings

- (NSString *)metaDescriptionCountString
{
	int intValue = [self.metaDescriptionCount intValue];
	switch(intValue)
	{
		case 0:
			return sCharacterDescription0Count;
		case 1:
			return sCharacterDescription1Count;
		default:
			return [NSString stringWithFormat:sCharacterDescriptionPluralCountFormat, intValue];
	}
}

- (NSString *)fileNameCountString
{
	int intValue = [self.fileNameCount intValue];
	switch(intValue)
	{
		case 0:
			return sCharacterDescription0Count;
		case 1:
			return sCharacterDescription1Count;
		default:
			return [NSString stringWithFormat:sCharacterDescriptionPluralCountFormat, intValue];
	}
}

- (NSString *)windowTitleCountString
{
	int intValue = [self.windowTitleCount intValue];
	switch(intValue)
	{
		case 0:
			return sCharacterDescription0Count;
		case 1:
			return sCharacterDescription1Count;
		default:
			return [NSString stringWithFormat:sCharacterDescriptionPluralCountFormat, intValue];
	}
}

+ (NSSet *)keyPathsForValuesAffectingMetaDescriptionCountString
{
    return [NSSet setWithObject:@"metaDescriptionCount"];
}

+ (NSSet *)keyPathsForValuesAffectingFileNameCountString
{
    return [NSSet setWithObject:@"fileNameCount"];
}

+ (NSSet *)keyPathsForValuesAffectingWindowTitleCountString
{
    return [NSSet setWithObject:@"windowTitleCount"];
}


/*	Called in response to a change of selection.metaDescription or the user typing
 *	We update our own count property in response
 */
- (void)metaDescriptionDidChangeToValue:(id)value
{
	if (value)
	{
		if (NSIsControllerMarker(value))
		{
			value = nil;
		}
		else
		{
			OBASSERT([value isKindOfClass:[NSString class]]);
			value = [NSNumber numberWithInt:[value length]];
		}
	}
	else
	{
		value = [NSNumber numberWithInt:0];
	}

	[self setMetaDescriptionCount:value];

	NSColor *windowColor = [self metaDescriptionCharCountColor];
	[self.attachedWindow setBackgroundColor:windowColor];

}

/*	Called in response to a change of selection.windowTitle or the user typing
 *	We update our own count property in response
 */
- (void)windowTitleDidChangeToValue:(id)value
{
	if (value)
	{
		if (NSIsControllerMarker(value))
		{
			value = nil;
		}
		else
		{
			OBASSERT([value isKindOfClass:[NSString class]]);
			value = [NSNumber numberWithInt:[value length]];
		}
	}
	else
	{
		value = [NSNumber numberWithInt:0];
	}
	
	[self setWindowTitleCount:value];

	NSColor *windowColor = [self windowTitleCharCountColor];
	[self.attachedWindow setBackgroundColor:windowColor];
}

- (void)fileNameDidChangeToValue:(id)value
{
	if (value)
	{
		if (NSIsControllerMarker(value))
		{
			value = nil;
		}
		else
		{
			OBASSERT([value isKindOfClass:[NSString class]]);
			value = [NSNumber numberWithInt:[value length]];
		}
	}
	else
	{
		value = [NSNumber numberWithInt:0];
	}
	
	[self setFileNameCount:value];

	NSColor *windowColor = [self fileNameCharCountColor];
	[self.attachedWindow setBackgroundColor:windowColor];
}


- (void) resetDescriptionPlaceholder:(NSString *)metaDescriptionText;
{
	NSDictionary *infoForBinding;
	NSDictionary *bindingOptions;
	NSString *bindingKeyPath;
	id observedObject;
	
	// The Meta description field ... re-bind the null placeholder.
	
	infoForBinding	= [oMetaDescriptionField infoForBinding:NSValueBinding];
	bindingOptions	= [[[infoForBinding valueForKey:NSOptionsKey] retain] autorelease];
	bindingKeyPath	= [[[infoForBinding valueForKey:NSObservedKeyPathKey] retain] autorelease];
	observedObject	= [[[infoForBinding valueForKey:NSObservedObjectKey] retain] autorelease];
	
	if ([observedObject respondsToSelector:@selector(selectedObjects)] && [[observedObject selectedObjects] count] > 1)
	{
		NSMutableDictionary *newBindingOptions = [NSMutableDictionary dictionaryWithDictionary:bindingOptions];
		
		// Move the multiple values placeholder to the null value, so that we see that when the values are empty
		[newBindingOptions setObject:[bindingOptions objectForKey:NSMultipleValuesPlaceholderBindingOption] forKey:NSNullPlaceholderBindingOption];
		
		[oMetaDescriptionField unbind:NSValueBinding];
		[oMetaDescriptionField bind:NSValueBinding toObject:observedObject withKeyPath:bindingKeyPath options:newBindingOptions];
	}
}

- (BOOL) mediaIsEditableText:(SVMediaRecord *)aMedia
{
	NSString *UTI = [aMedia typeOfFile];
	BOOL result = ([UTI conformsToUTI:(NSString *)kUTTypePlainText]
				   || [UTI conformsToUTI:(NSString *)kUTTypeHTML] );
		// Let's try not allowing kUTTypeXML or KUTTypeHTML or other variants of kUTTypeText
	return result;
}
	

- (void) updateFieldsBasedOnSelectedSiteOutlineObjects:(NSArray *)selObjects;
{
	if (NSIsControllerMarker(selObjects))
	{
		NSLog(@"Controller marker:  %@", selObjects);
	}
	else
	{
		// Start with unknown, break and set to mixed if we find different types
		
		int combinedType = kUnknownSiteItemType;
		for (SVSiteItem *item in selObjects)
		{
			SVMediaRecord *media = nil;
			int type = kUnknownSiteItemType;
			if (nil != [item externalLinkRepresentation]) { type = kLinkSiteItemType; }
			else if (nil != (media =[item mediaRepresentation]))
			{
				type = kFileSiteItemType;
				// But now see if it's actually editable text
				if ([self mediaIsEditableText:media])
				{
					type = kTextSiteItemType;
				}
			}
			else if (nil != [item pageRepresentation]) type = kPageSiteItemType;
			
			if (kUnknownSiteItemType != combinedType && type != combinedType)
			{
				combinedType = kMixedSiteItemType;
				break;	// stop looking -- this is a combination of types
			}
			else
			{
				combinedType = type;	// keep looking, so far collecting a single type.
			}
		}
		self.whatKindOfItemsAreSelected = combinedType;
		
		[self layoutPageURLComponents];
	}
}

- (void) resetTitlePlaceholderToComboTitleText:(NSString *)comboTitleText
{
	NSDictionary *infoForBinding;
	NSDictionary *bindingOptions;
	NSString *bindingKeyPath;
	id observedObject;
	
	// The Window Title field ... re-bind the null placeholder.
	
	infoForBinding	= [oWindowTitleField infoForBinding:NSValueBinding];
	bindingOptions	= [[[infoForBinding valueForKey:NSOptionsKey] retain] autorelease];
	bindingKeyPath	= [[[infoForBinding valueForKey:NSObservedKeyPathKey] retain] autorelease];
	observedObject	= [[[infoForBinding valueForKey:NSObservedObjectKey] retain] autorelease];
	
	NSMutableDictionary *newBindingOptions = [NSMutableDictionary dictionaryWithDictionary:bindingOptions];
	
	if (NSMultipleValuesMarker == comboTitleText)
	{
		// Try copying over the multiple values string to the null placeholder...
		// I think that is so we see the multiple mark when the values are empty (unset)
		[newBindingOptions setObject:[bindingOptions objectForKey:NSMultipleValuesPlaceholderBindingOption] forKey:NSNullPlaceholderBindingOption];
	}
	else if (!NSIsControllerMarker(comboTitleText))
	{		
		if (![[bindingOptions objectForKey:NSMultipleValuesPlaceholderBindingOption] isEqualToString:comboTitleText])	// why this check?
		{
			// For some reason it seems like you need to set the Null placeholder even with multiple bindings!
			[newBindingOptions setObject:comboTitleText forKey:NSNullPlaceholderBindingOption];
		}
	}
	[oWindowTitleField unbind:NSValueBinding];
	[oWindowTitleField bind:NSValueBinding toObject:observedObject withKeyPath:bindingKeyPath options:newBindingOptions];
}

#pragma mark -
#pragma mark Count colors

#define META_DESCRIPTION_WARNING_ZONE 10
#define MAX_META_DESCRIPTION_LENGTH 156

- (NSColor *)metaDescriptionCharCountColor;
{
	int charCount = [[self metaDescriptionCount] intValue];
	NSColor *result = [NSColor colorWithCalibratedWhite:0.0 alpha:ATTACHED_WINDOW_TRANSP];
	int remaining = MAX_META_DESCRIPTION_LENGTH - charCount;
	
	if (remaining > META_DESCRIPTION_WARNING_ZONE )		// out of warning zone: a nice HUD color
	{
		;
	}
	else if (remaining >= 0 )							// get closer to black-red
	{
		float howRed = (float) remaining / META_DESCRIPTION_WARNING_ZONE;
		result = [[NSColor colorWithCalibratedRed:0.4 green:0.0 blue:0.0 alpha:1.0] blendedColorWithFraction:howRed ofColor:result];		// blend with default black
	}
	else		// overflow: pure red.
	{
		result = [NSColor redColor];
	}	
	return result;
}


#define MAX_WINDOW_TITLE_LENGTH 65
#define WINDOW_TITLE_WARNING_ZONE 8
- (NSColor *)windowTitleCharCountColor
{
	int charCount = [[self windowTitleCount] intValue];
	NSColor *result = [NSColor colorWithCalibratedWhite:0.0 alpha:ATTACHED_WINDOW_TRANSP];
	int remaining = MAX_WINDOW_TITLE_LENGTH - charCount;
	
	if (remaining > WINDOW_TITLE_WARNING_ZONE )		// out of warning zone: a nice light gray
	{
		;
	}
	else if (remaining >= 0 )							// get closer to black-red
	{
		float howRed = (float) remaining / WINDOW_TITLE_WARNING_ZONE;
		result = [[NSColor colorWithCalibratedRed:0.4 green:0.0 blue:0.0 alpha:1.0] blendedColorWithFraction:howRed ofColor:result];		// blend with default gray
	}
	else		// overflow: pure red.
	{
		result = [NSColor redColor];
	}	
	return result;
}
#define MAX_FILE_NAME_LENGTH 27
#define FILE_NAME_WARNING_ZONE 5
- (NSColor *)fileNameCharCountColor
{
	int charCount = [[self fileNameCount] intValue];
	NSColor *result = [NSColor colorWithCalibratedWhite:0.0 alpha:ATTACHED_WINDOW_TRANSP];
	int remaining = MAX_FILE_NAME_LENGTH - charCount;
	
	if (remaining > FILE_NAME_WARNING_ZONE )		// out of warning zone: a nice light gray
	{
		;
	}
	else if (remaining >= 0 )							// get closer to black-red
	{
		float howRed = (float) remaining / WINDOW_TITLE_WARNING_ZONE;
		result = [[NSColor colorWithCalibratedRed:0.4 green:0.0 blue:0.0 alpha:1.0] blendedColorWithFraction:howRed ofColor:result];		// blend with default gray
	}
	else		// overflow: pure red.  Not actually possible here (theoretically)
	{
		result = [NSColor redColor];
	}	
	return result;
}


+ (NSSet *)keyPathsForValuesAffectingWindowTitleCharCountColor
{
    return [NSSet setWithObject:@"windowTitleCount"];
}

+ (NSSet *)keyPathsForValuesAffectingFileNameCharCountColor
{
    return [NSSet setWithObject:@"fileNameCount"];
}

+ (NSSet *)keyPathsForValuesAffectingMetaDescriptionCharCountColor
{
    return [NSSet setWithObject:@"metaDescriptionCount"];
}


#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
//	NSLog(@"object = %@", object);
	
	[self layoutPageURLComponents];

	if (context == sMetaDescriptionObservationContext)
	{
		[self metaDescriptionDidChangeToValue:[object valueForKeyPath:keyPath]];
		[self resetDescriptionPlaceholder:[object valueForKeyPath:@"selection.metaDescription"]];
	}
	else if (context == sWindowTitleObservationContext)
	{
		[self windowTitleDidChangeToValue:[object valueForKeyPath:keyPath]];
	}
	else if (context == sFileNameObservationContext)
	{
		[self fileNameDidChangeToValue:[object valueForKeyPath:keyPath]];
	}
	else if (context == sBaseExampleURLStringObservationContext)
	{
		; // base URL changed, so re-layout
	}
	else if (context == sSelectedViewControllerObservationContext)
	{
		[self rebindWindowTitleAndMetaDescriptionFields];
	}
	else if (context == sTitleObservationContext)
	{
		[self resetTitlePlaceholderToComboTitleText:[object valueForKeyPath:@"selection.comboTitleText"]];	// go ahead and get the combo title
	}
	else if (context == sSelectedObjectsObservationContext)
	{
		[self updateFieldsBasedOnSelectedSiteOutlineObjects:[object selectedObjects]];
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

#pragma mark -
#pragma mark URL view layout

- (void) rebindWindowTitleAndMetaDescriptionFields;
{
	// Kind of hackish.  Re-bind the window title and meta description to the model object if it's a real page, or the controller if it's an external link.
	
	id selViewController = [[oDocWindowController webContentAreaController] selectedViewController];
	if ([selViewController isKindOfClass:[SVWebEditorViewController class]])
	{
		[oWindowTitleField unbind:NSValueBinding];
		[oWindowTitleField bind:NSValueBinding
					   toObject:oPagesController
					withKeyPath:@"selection.windowTitle"
						options:self.initialWindowTitleBindingOptions];
		
		[oMetaDescriptionField unbind:NSValueBinding];
		[oMetaDescriptionField bind:NSValueBinding
						   toObject:oPagesController
						withKeyPath:@"selection.metaDescription"
							options:self.initialMetaDescriptionBindingOptions];
		
		/*
		 NSObservedKeyPath = "selection.windowTitle";
		 NSObservedObject = <SVPagesController: 0x1c90cf0>[entity: Page, number of selected objects: 1];
		 NSOptions =     {
		 NSAllowsEditingMultipleValuesSelection = 1;
		 NSAlwaysPresentsApplicationModalAlerts = 0;
		 NSConditionallySetsEditable = 1;
		 NSConditionallySetsEnabled = 0;
		 NSConditionallySetsHidden = 0;
		 NSContinuouslyUpdatesValue = 0;
		 NSMultipleValuesPlaceholder = "Multiple pages selected. Titles should be unique.";
		 NSNoSelectionPlaceholder = "";
		 NSNotApplicablePlaceholder = "Not Applicable";
		 NSNullPlaceholder = "Home Page | Karelia Software";
		 NSRaisesForNotApplicableKeys = 0;
		 NSValidatesImmediately = 0;
		 NSValueTransformer = <null>;
		 NSValueTransformerName = <null>;
		 };
		 }
		 NSObservedKeyPath = "selection.metaDescription";
		 NSObservedObject = <SVPagesController: 0x1c90cf0>[entity: Page, number of selected objects: 1];
		 NSOptions =     {
		 NSAllowsEditingMultipleValuesSelection = 1;
		 NSAlwaysPresentsApplicationModalAlerts = 0;
		 NSConditionallySetsEditable = 1;
		 NSConditionallySetsEnabled = 0;
		 NSConditionallySetsHidden = 0;
		 NSContinuouslyUpdatesValue = 0;
		 NSMultipleValuesPlaceholder = "Multiple pages selected. Descriptions should be unique.";
		 NSNoSelectionPlaceholder = "";
		 NSNotApplicablePlaceholder = "Not Applicable";
		 NSNullPlaceholder = "Summary of this page as it will appear in Google listings.";
		 NSRaisesForNotApplicableKeys = 0;
		 NSValidatesImmediately = 0;
		 NSValueTransformer = <null>;
		 NSValueTransformerName = <null>;
		 };
		 */		 
	}
	else if ([selViewController isKindOfClass:[SVURLPreviewViewController class]])
	{
		[oWindowTitleField unbind:NSValueBinding];
		[oWindowTitleField bind:NSValueBinding
					   toObject:selViewController
					withKeyPath:@"title"
						options:nil];
		
		[oMetaDescriptionField unbind:NSValueBinding];
		[oMetaDescriptionField bind:NSValueBinding
						   toObject:selViewController
						withKeyPath:@"metaDescription"
							options:nil];
	}
}	

/*
 Algorithm 
 Calculate how much each of the variable fields oBaseURLField and oPageFileNameField *want* to be
 Don't truncate oPageFileNameField - this is limited by character count and we want to see the whole thing
 So we will truncate oBaseURLField as much as we need.
 
 We also need to call this when the observed page changes.
 
 */

- (void) layoutPageURLComponents;
{
#define IS_ROOT_STATE -99
	// Only visible for page types
	// TODO: deal with downloads, where we keep the base URL but have a special field for the whole filename
	
	NSInteger pageIsCollectionState = NSMixedState;
	if (kPageSiteItemType == self.whatKindOfItemsAreSelected)
	{
		id isCollectionMarker = [oPagesController valueForKeyPath:@"selection.isCollection"];
		if ([isCollectionMarker respondsToSelector:@selector(boolValue)])
		{
			pageIsCollectionState = [isCollectionMarker boolValue] ? NSOnState : NSOffState;
		}
	}
	// And also check if it's a root
	if (NSOnState == pageIsCollectionState)
	{
		id isRootMarker = [oPagesController valueForKeyPath:@"selection.isRoot"];
		if ([isRootMarker respondsToSelector:@selector(boolValue)] && [isRootMarker boolValue])
		{
			pageIsCollectionState =  IS_ROOT_STATE;		// special marker indicating root, and only root, is selected.
		}
	}
	// Prompts
	[oWindowTitlePrompt		setHidden:(kPageSiteItemType != self.whatKindOfItemsAreSelected) && (kLinkSiteItemType != self.whatKindOfItemsAreSelected)];
	[oMetaDescriptionPrompt	setHidden:(kPageSiteItemType != self.whatKindOfItemsAreSelected) && (kLinkSiteItemType != self.whatKindOfItemsAreSelected)];
	[oFilePrompt setHidden:(kFileSiteItemType != self.whatKindOfItemsAreSelected)];

	// Additional Lines
	[oWindowTitleField		setHidden:(kPageSiteItemType != self.whatKindOfItemsAreSelected)];
	[oMetaDescriptionField	setHidden:(kPageSiteItemType != self.whatKindOfItemsAreSelected)];
	[oWindowTitleField		setHidden:(kPageSiteItemType != self.whatKindOfItemsAreSelected) && (kLinkSiteItemType != self.whatKindOfItemsAreSelected)];
	[oMetaDescriptionField	setHidden:(kPageSiteItemType != self.whatKindOfItemsAreSelected) && (kLinkSiteItemType != self.whatKindOfItemsAreSelected)];
	[oWindowTitleField		setEditable:(kPageSiteItemType == self.whatKindOfItemsAreSelected)];
	[oMetaDescriptionField	setEditable:(kPageSiteItemType == self.whatKindOfItemsAreSelected)];
	[oChooseFileButton setHidden:(kFileSiteItemType != self.whatKindOfItemsAreSelected)];

	// First line, external URL field
	[oExternalURLField setHidden:(kLinkSiteItemType != self.whatKindOfItemsAreSelected)];

	// First line, complex pieces that make up the URL components
	BOOL hasLocalPath = (	kPageSiteItemType == self.whatKindOfItemsAreSelected
						||	kTextSiteItemType == self.whatKindOfItemsAreSelected
						||	kFileSiteItemType == self.whatKindOfItemsAreSelected);
	
	[oBaseURLField setHidden:!hasLocalPath];
	[oFileNameField setHidden:(!hasLocalPath
							   || (kPageSiteItemType == self.whatKindOfItemsAreSelected && IS_ROOT_STATE == pageIsCollectionState))];

	[oDotSeparator setHidden:(kPageSiteItemType != self.whatKindOfItemsAreSelected || NSOffState != pageIsCollectionState)];
	[oSlashSeparator setHidden:(kPageSiteItemType != self.whatKindOfItemsAreSelected || NSOnState != pageIsCollectionState)];
	[oIndexDotSeparator setHidden:(kPageSiteItemType != self.whatKindOfItemsAreSelected || NSOffState == pageIsCollectionState)];

	[oMultiplePagesField setHidden:(kPageSiteItemType != self.whatKindOfItemsAreSelected || NSMixedState != pageIsCollectionState)];
	
	[oExtensionPopup setHidden:(kPageSiteItemType != self.whatKindOfItemsAreSelected)];

	
	// Follow button only enabled when there is one item ?
	[oFollowButton setHidden: [[oPagesController selectedObjects] count] != 1];
	
	if (kLinkSiteItemType == self.whatKindOfItemsAreSelected)
	{
		int newLeft = [oBaseURLField frame].origin.x;		// starting point for left of next item
		const int rightMargin = 20;
		int availableForAll = [[self view] bounds].size.width - rightMargin - newLeft - [oFollowButton frame].size.width - 8;
		NSRect frame = [oExternalURLField frame];
		frame.origin.x = newLeft;
		
		NSAttributedString *text = [oExternalURLField attributedStringValue];
		int width = ceilf([text size].width)  + 2;
		if (width > availableForAll) width = availableForAll;	// make sure a really long URL will fit
		frame.size.width = width;
		
		[oExternalURLField setFrame:frame];

		// Move the follow button over
		frame = [oFollowButton frame];
		frame.origin.x = NSMaxX([oExternalURLField frame])+8;
		[oFollowButton setFrame:frame];
//		NSLog(@"set oFollowButton to %@", NSStringFromRect(frame));
	}
	else if (hasLocalPath)
	{
		NSArray *itemsToLayOut = nil;
		int *theExtraX = nil;
		int *theMarginsAfter = nil;
		
		NSArray *pageItemsToLayOut = [NSArray arrayWithObjects:oBaseURLField,oFileNameField,oDotSeparator,oExtensionPopup,oFollowButton,nil];
		int pageExtraX [] = {4,5,6,8,0};
		int pageMarginsAfter[] = {0,-1,0,8,0};
		
		NSArray *collectionItemsToLayOut = [NSArray arrayWithObjects:oBaseURLField,oFileNameField,oSlashSeparator, oIndexDotSeparator,oExtensionPopup,oFollowButton,nil];
		int collectionExtraX [] = {4,5,1,6,8,0};
		int collectionMarginsAfter[] = {0,-1,0,0,8,0};
		
		NSArray *markerItemsToLayOut = [NSArray arrayWithObjects:oBaseURLField,oMultiplePagesField,oDotSeparator,oExtensionPopup,nil];
		int markerExtraX [] = {4,4,6,8};
		int markerMarginsAfter[] = {0,0,0,8};
			
		NSArray *rootItemsToLayOut = [NSArray arrayWithObjects:oBaseURLField,oIndexDotSeparator,oExtensionPopup,oFollowButton,nil];
		int rootExtraX [] = {0,6,8,0};
		int rootMarginsAfter[] = {0,0,8,0};
		
		NSArray *mediaItemsToLayOut = [NSArray arrayWithObjects:oBaseURLField,oFileNameField,oFollowButton,nil];
		int mediaExtraX [] = {4,5,1};
		int mediaMarginsAfter[] = {0,-1,0};
				
		if (kPageSiteItemType == self.whatKindOfItemsAreSelected)
		{
			switch (pageIsCollectionState)
			{
				case IS_ROOT_STATE:
					itemsToLayOut = rootItemsToLayOut;
					theExtraX = rootExtraX;
					theMarginsAfter = rootMarginsAfter;
					break;
				case NSMixedState:
					itemsToLayOut = markerItemsToLayOut;
					theExtraX = markerExtraX;
					theMarginsAfter = markerMarginsAfter;
					break;
				case NSOnState:
					itemsToLayOut = collectionItemsToLayOut;
					theExtraX = collectionExtraX;
					theMarginsAfter = collectionMarginsAfter;
					break;
				case NSOffState:
					itemsToLayOut = pageItemsToLayOut;
					theExtraX = pageExtraX;
					theMarginsAfter = pageMarginsAfter;
					break;
			}
		}
		else
		{
			// kTextSiteItemType or kFileSiteItemType
			itemsToLayOut = mediaItemsToLayOut;
			theExtraX = mediaExtraX;
			theMarginsAfter = mediaMarginsAfter;
			
			// bindings: baseExampleURLString, fileName.  Are these coming through on media?
		}
			
		int widths[6] = { 0 }; // filled in below. Make sure we have enough items for array above
		int i = 0;
		// Collect up the widths that these items *want* to be
		for (NSView *fld in itemsToLayOut)
		{
			// Editable File Name
			NSRect frame = [fld frame];
			
			if ([fld isKindOfClass:[NSTextField class]])
			{
				NSAttributedString *text = [((NSTextField *)fld) attributedStringValue];
				int width = ceilf([text size].width);
				width += theExtraX[i];
				width += theMarginsAfter[i];
				frame.size.width = width;
			}
			widths[i++] = frame.size.width;
		}
		
		int newLeft = [oBaseURLField frame].origin.x;		// starting point for left of next item
		const int rightMargin = 20;
		int availableForAll = [[self view] bounds].size.width - rightMargin - newLeft;
		
		// Calculate a new width for base URL
		int availableForBaseURL = availableForAll -
			(theExtraX[0]
			 + widths[1]
			 + widths[2]
			 + widths[3]
			 + widths[4]
			 + widths[5]);
#define MINIMUM_BASE_URL 60
		if (availableForBaseURL < MINIMUM_BASE_URL)	// is file name field getting way long?
		{
			widths[0] = MINIMUM_BASE_URL;		// give base URL field a minimum size to show something there
			int fileNameFieldAdjustment = availableForBaseURL - MINIMUM_BASE_URL;
			widths[1] += fileNameFieldAdjustment;	// take away from the file name field
		}
		else if (widths[0] > availableForBaseURL)	// is base URL field allotment greater than what's available?
		{
			widths[0] = availableForBaseURL;	// truncate base URL
		}
		// Now set the new frames
		i = 0;
		for (NSView *fld2 in itemsToLayOut)
		{
			// Editable File Name
			NSRect frame = [fld2 frame];
			frame.origin.x = newLeft;
			frame.size.width = widths[i];
			[fld2 setFrame:frame];
			// NSLog(@"set %@ to %@", [fld2 class], NSStringFromRect(frame));

			newLeft = NSMaxX(frame);
			if (fld2 == oBaseURLField)	// special case -- move file name over to left to adjoin previous field
			{							// (which we left wide enough so it wouldn't get clipped)
				newLeft -= 4;
			}
			if (fld2 == oFileNameField)	// special case -- move file name over to left to adjoin previous field
			{							// (which we left wide enough so it wouldn't get clipped)
				newLeft -= 1;
			}
			newLeft += theMarginsAfter[i];
			i++;
		}
	}
	// Now that widths have been recalculated, update the width for the active field, for the shadow background
	[self updateWidthForActiveTextField:self.activeTextField];

}



- (void)updateWidthForActiveTextField:(NSTextField *)textField;
{
	if (!textField) return;	// we may have no active text field
	
	KSShadowedRectView *view = (KSShadowedRectView *)[textField superview];
	OBASSERT([view isKindOfClass:[KSShadowedRectView class]]);
	
	NSTextView *fieldEditor = (NSTextView *)[textField currentEditor];
	
	NSRect textRect = [[fieldEditor layoutManager]
					   usedRectForTextContainer:[fieldEditor textContainer]];
	
	NSRect fieldRect = [textField frame];
	float textWidth = textRect.size.width;
	float fieldWidth = fieldRect.size.width;
	int width = ceilf(MIN(textWidth, fieldWidth));
	width = MAX(width, 7);		// make sure it's at least 7 pixels wide
	// NSLog(@"'%@' widths: text = %.2f, field = %.2f => %d", [textField stringValue], textWidth, fieldWidth, width);
	fieldRect.size.width = width;
	[view setShadowRect:fieldRect];
	
}

- (void) backgroundFrameChanged:(NSNotification *)notification
{
	[self layoutPageURLComponents];
}

#pragma mark -
#pragma mark Text editing notifications

/*	Sent when the user is typing in the meta description box.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	// For some stupid reason, this is getting called twice, all within the text system.
	// So I set a flag so we don't do anything in the second invocation.
	if (!_alreadyHandlingControlTextDidChange)
	{
		_alreadyHandlingControlTextDidChange = YES;

		NSTextField *textField = (NSTextField *) [notification object];
		// This VERY important: Do NOT ask a cell for its -stringValue unless you actually need it. If the cell has a formatter, calling -stringValue will invoke that, and format the entered text, even though the user probably wasn't ready for it.
		
		if (textField == oWindowTitleField)
		{
			[self windowTitleDidChangeToValue:[textField stringValue]];
		}
		else if (textField == oMetaDescriptionField)
		{
			[self metaDescriptionDidChangeToValue:[textField stringValue]];
		}
		else if (textField == oFileNameField)
		{
			[self fileNameDidChangeToValue:[textField stringValue]];
		}

		[self layoutPageURLComponents];

		
		_alreadyHandlingControlTextDidChange = NO;
	}
}

// Special responders to the subclass of the text field

- (void)controlTextDidBecomeFirstResponder:(NSNotification *)notification;
{
	KSShadowedRectView *view = (KSShadowedRectView *)[[notification object] superview];
	NSTextField *field = [notification object];
	OBASSERT([view isKindOfClass:[KSShadowedRectView class]]);

	self.activeTextField = field;
	[self updateWidthForActiveTextField:field];

	// Can't think of a better way to do this...
	
	NSString *bindingName = nil;
	NSString *explanation = @"";
	int tagForHelp = kUnknownPageDetailsContext;
	if (field == oFileNameField)
	{
		tagForHelp = kFileNamePageDetailsContext;
		bindingName = @"fileNameCountString";
		explanation = NSLocalizedString(@"Maximum 27 characters",@"brief indication of maximum length of file name");
	}
	else if (field == oMetaDescriptionField)
	{	
		tagForHelp = kMetaDescriptionPageDetailsContext;
		bindingName = @"metaDescriptionCountString";
		explanation = NSLocalizedString(@"More than 156 characters will be truncated",@"brief indication of maximum length of text");
	}
	else if (field == oWindowTitleField)
	{
		tagForHelp = kWindowTitlePageDetailsContext;
		bindingName = @"windowTitleCountString";
		explanation = NSLocalizedString(@"More than 65 characters will be truncated",@"brief indication of maximum length of text");
	}
	

	if (bindingName)
	{
		[oAttachedWindowHelpButton setTag:tagForHelp];
		
		if (!self.attachedWindow)
		{
			// We are cheating here .. there is only ONE active text field, help button, etc. ... 
			// We fade out the window when we leave the field, but we immediately put these fields
			// into a new attached window.  I think nobody is going to notice that though.
			[oAttachedWindowTextField unbind:NSValueBinding];
			
			[oAttachedWindowTextField setStringValue:sCharacterDescriptionPluralCountFormat];
			const int widthExtra = 25;	// Fudge a little bit for longer numbers bigger than the width of the placeholder string
			float rightSide = ceilf([[oAttachedWindowTextField attributedStringValue] size].width) + widthExtra;

			[oAttachedWindowTextField bind:NSValueBinding toObject:self withKeyPath:bindingName options:nil];
            
			[oAttachedWindowExplanation setStringValue:explanation];
			
			int height = [oAttachedWindowView frame].size.height;	// also size of question mark
			const int buttonSize = 14;
			const int textHeight = 14;
			const int secondLineY = 15;
			int windowWidth = MAX(rightSide+8+height,
				ceilf([[oAttachedWindowExplanation attributedStringValue] size].width) + widthExtra );
			
			[oAttachedWindowView setFrame:NSMakeRect(0,0,windowWidth,height)];	// set view first, then subviews		
			[oAttachedWindowTextField setFrame:NSMakeRect(0,secondLineY,rightSide, textHeight)];
			[oAttachedWindowHelpButton setFrame:NSMakeRect(windowWidth-buttonSize,secondLineY,buttonSize,buttonSize)];
			[oAttachedWindowExplanation setFrame:NSMakeRect(0,0,windowWidth,textHeight)];
			NSPoint arrowTip = NSMakePoint([field frame].origin.x + 10, NSMidY([field frame]) );
			arrowTip = [view convertPoint:arrowTip toView:nil];
			
			self.attachedWindow = [[MAAttachedWindow alloc] initWithView:oAttachedWindowView 
													attachedToPoint:arrowTip 
														   inWindow:[view window] 
															 onSide:MAPositionLeft 
														 atDistance:10.0];
			self.attachedWindow.delegate = self;
			self.attachedWindow.alphaValue = 0.0;
			[self.attachedWindow setReleasedWhenClosed:YES];

			[self.attachedWindow setBorderColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.8]];
			[oAttachedWindowTextField setTextColor:[NSColor whiteColor]];
			[oAttachedWindowExplanation setTextColor:[NSColor whiteColor]];
			[[oAttachedWindowHelpButton image] setTemplate:YES];
			
			static NSImage *sTintedHelpButtonImage = nil;
			if (!sTintedHelpButtonImage)
			{
				sTintedHelpButtonImage = [[[oAttachedWindowHelpButton image] tintedImageWithColor:[NSColor lightGrayColor]] retain];
			}
			[oAttachedWindowHelpButton setAlternateImage:sTintedHelpButtonImage];

			[self.attachedWindow setBackgroundColor:[NSColor colorWithCalibratedWhite:0.0 alpha:ATTACHED_WINDOW_TRANSP]];
			[self.attachedWindow setViewMargin:6];
			[self.attachedWindow setCornerRadius:6];	// set after arrow base width?  before?
			[self.attachedWindow setBorderWidth:0];
			[self.attachedWindow setHasArrow:YES];
			[self.attachedWindow setDrawsRoundCornerBesideArrow:NO];
			[self.attachedWindow setArrowBaseWidth:15];
			[self.attachedWindow setArrowHeight:8];
			[self.attachedWindow setCornerRadius:6];	// set after arrow base width?  before?

			[[view window] addChildWindow:self.attachedWindow ordered:NSWindowAbove];

			// Set up the animation for this window so we will get delegate methods
			CAAnimation *anim = [CABasicAnimation animation];
			// [anim setDuration:3.0];
			[anim setValue:self.attachedWindow forKey:@"myOwnerWindow"];
			[anim setDelegate:self];
			[self.attachedWindow setAnimations:[NSDictionary dictionaryWithObject:anim forKey:@"alphaValue"]];

			[self.attachedWindow.animator setAlphaValue:1.0];	// animate open
		}
	}
}

- (void)controlTextDidResignFirstResponder:(NSNotification *)notification;
{
	KSShadowedRectView *view = (KSShadowedRectView *)[[notification object] superview];
	OBASSERT([view isKindOfClass:[KSShadowedRectView class]]);
	[view setShadowRect:NSZeroRect];
	self.activeTextField = nil;
	
	if (self.attachedWindow)
	{
		[self.attachedWindow.animator setAlphaValue:0.0];
		[[[self view] window] removeChildWindow:self.attachedWindow];
		self.attachedWindow = nil;
	}
}

- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)flag 
{
	NSWindow *animationWindow = [animation valueForKey:@"myOwnerWindow"];
	if(animationWindow.alphaValue <= 0.01)
	{
		[animationWindow orderOut:nil];
		[animationWindow close];
	}
}


// If you tab out of last text field to something else, we don't lose first responder?
- (void)controlTextDidEndEditing:(NSNotification *)notification;
{
	[self controlTextDidResignFirstResponder:notification];
}

#pragma mark -
#pragma mark Actions

// We will need to open up the appropriate help topic based on the tag

- (IBAction) pageDetailsHelp:(id)sender;
{
	NSLog(@"%s -- help variant = %d",__FUNCTION__, [sender tag]);
}

- (IBAction) preview:(id)sender;
{
	NSArray *selectedObjects = [oPagesController selectedObjects];
	id item = [selectedObjects lastObject];
	if (item)
	{
		[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[item URL]];
	}
}

- (IBAction) chooseFile:(id)sender;
{
	
	NSArray *selectedObjects = [oPagesController selectedObjects];
	id item = [selectedObjects lastObject];
	KTSite *site = [item site];

	NSOpenPanel *panel = [[site document] makeChooseDialog];
	
	int returnCode = [panel runModalForTypes:[panel allowedFileTypes]];
	
	if (returnCode == NSOKButton && [[panel URLs] count])
	{
		SVDownloadSiteItem *downloadPage = [[oPagesController selectedObjects] lastObject];
		NSManagedObjectContext *context = [downloadPage managedObjectContext];
		NSURL *url = [[panel URLs] lastObject];		// we have just one
		NSError *error = nil;
		SVMediaRecord *record = [SVMediaRecord mediaWithURL:url
												 entityName:@"FileMedia"
							 insertIntoManagedObjectContext:context				/// where to we get our MOC?
													  error:&error];
		if (error)
		{
			[[NSApplication sharedApplication] presentError:error];
		}
		else
		{
			// Success: delete old media, store new:
			[downloadPage replaceMedia:record forKeyPath:@"media"];
		}
	}
	 
}


@end
