//
//  SVDesignChooserWindowController.m
//  Sandvox
//
//  Created by Terrence Talbot on 8/28/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDesignChooserWindowController.h"
#import "SVDesignChooserViewController.h"

#import "Debug.h"
#import "KSPlugInWrapper.h"
#import "KT.h"
#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "SVSiteOutlineViewController.h"

#import "NSArray+Karelia.h"

#import "MGScopeBar.h"

@interface SVDesignChooserWindowController ()
- (NSString *)scopeBar:(MGScopeBar *)theScopeBar AXDescriptionForItem:(NSString *)identifier inGroup:(NSInteger)groupNumber;
@end


@implementation SVDesignChooserWindowController

#pragma mark Properties

- (KTDesign *)design
{
    [self window];    // make sure nib is loaded
    return oViewController.selectedDesign;
}
- (void)setDesign:(KTDesign *)design
{
    [self window];    // make sure nib is loaded
    oViewController.selectedDesign = design;
}

@synthesize selectorWhenChosen = _selectorWhenChosen;
@synthesize targetWhenChosen = _targetWhenChosen;
@synthesize allDesigns = _allDesigns;
@synthesize genre = _genre;
@synthesize color = _color;
@synthesize width = _width;

// IF I CHANGE THIS ORDER, CHANGE THE ORDER IN THE METHOD "matchString"
enum { kColorGroup, kWidthGroup, kGenreGroup };	// I would prefer to have the genre *first* but it's one that works best when collapsed, and MGScopeBar prefers collapsing items on the right.  It would be a huge rewrite to change that....

+ (NSSet *)keyPathsForValuesAffectingMatchString
{
    // As far as I can see, this should make .inspectedObjects KVO-compliant, but it seems something about NSArrayController stops it from working
    return [NSSet setWithObjects:@"genre", @"color", @"width", @"oViewController.designs", nil];
}

+ (NSSet *)keyPathsForValuesAffectingMatchColor
{
    // As far as I can see, this should make .inspectedObjects KVO-compliant, but it seems something about NSArrayController stops it from working
    return [NSSet setWithObjects:@"genre", @"color", @"width", @"oViewController.designs", nil];
}

- (NSColor *)matchColor;
{
	return ([oViewController.designs count]) ? [NSColor grayColor] : [NSColor redColor];
}

- (NSString *)matchString;
{
	NSString *result = @"";
	if (self.genre || self.color || self.width)
	{
		NSMutableArray *matches = [NSMutableArray array];
		
		// THIS ORDER SHOULD MATCH THE ORDER OF THE ENUMS
		if (self.color) [matches addObject:[self scopeBar:oScopeBar AXDescriptionForItem:self.color inGroup:kColorGroup]];
		if (self.width) [matches addObject:[self scopeBar:oScopeBar AXDescriptionForItem:self.width inGroup:kWidthGroup]];
		if (self.genre) [matches addObject:[self scopeBar:oScopeBar titleOfItem:self.genre inGroup:kGenreGroup]];

		NSMutableString *matchesString = [NSMutableString string];
		for (int i = 0 ; i < [matches count] ; i++)
		{
			NSString *match = [matches objectAtIndex:i];
			if (i == [matches count] -1)
			{
				[matchesString appendFormat:NSLocalizedString(@"“%@”", @"a search string in quotes, either by itself or last in a list of strings joined by 'and'"), match];
			}
			else
			{
				[matchesString appendFormat:NSLocalizedString(@"“%@” and ", @"a search string in quotes followed by 'and' (with a space afterwards)"), match];
			}
		}
		if ([oViewController.designs count])
		{
			result = [NSString stringWithFormat:NSLocalizedString(@"Showing matches for %@", @"Warning that string/strings yielded no matching designs"), matchesString];
		}
		else
		{
			result = [NSString stringWithFormat:NSLocalizedString(@"No matches for %@", @"Warning that string/strings yielded no matching designs"), matchesString];
		}
		
	}
	else
	{
		result = NSLocalizedString(@"Showing all matches", @"");
	}
	return result;
}

#pragma mark -

- (void)awakeFromNib
{
	NSArray *designs = [KSPlugInWrapper sortedPluginsWithFileExtension:kKTDesignExtension];

	// Get all designs; we'll be filtering...
	self.allDesigns = [KTDesign consolidateDesignsIntoFamilies:designs];
	oViewController.designs = self.allDesigns;
}

- (void)beginSheetModalForWindow:(NSWindow *)window delegate:(id)aTarget didEndSelector:(SEL)aSelector;
{
	self.selectorWhenChosen = aSelector;
	self.targetWhenChosen = aTarget;
		
    [NSApp beginSheet:[self window]
       modalForWindow:window
        modalDelegate:self
       didEndSelector:@selector(designChooserDidEndSheet:returnCode:contextInfo:)
          contextInfo:nil];

    [oScopeBar setDelegate:self];
    [oScopeBar reloadData];

	// restore from prevous run
	[oScopeBar setSelected:YES forItem:self.genre inGroup:kGenreGroup];
	[oScopeBar setSelected:YES forItem:self.color inGroup:kColorGroup];
	[oScopeBar setSelected:YES forItem:self.width inGroup:kWidthGroup];
	
    [oViewController setupTrackingRects];
}

- (IBAction)chooseDesign:(id)sender		// Design was chosen.  Now call back to notify of change.
{
    // get the selected design
	KTDesign *selectedDesign = [oViewController selectedDesign];
	if (selectedDesign)
	{
		if (self.targetWhenChosen && [self.targetWhenChosen respondsToSelector:self.selectorWhenChosen])
		{
			[self.targetWhenChosen performSelector:self.selectorWhenChosen withObject:selectedDesign];
		}
	}
    
    // close up shop, we're done
    [NSApp endSheet:[self window]];    
}

- (void)terminate:(id)sender
{
    // in 10.6 we could use setPreventsApplicationTerminationWhenModal:NO instead
    [self cancelSheet:sender];
    [NSApp terminate:sender];
}

- (IBAction)cancelSheet:(id)sender
{
    [NSApp endSheet:[self window]];
}

- (void)designChooserDidEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    OBASSERT(sheet == [self window]);
    [sheet orderOut:self];
}

@synthesize viewController = oViewController;

#pragma mark -
#pragma mark MGScopeBarDelegate


- (NSInteger)numberOfGroupsInScopeBar:(MGScopeBar *)theScopeBar
{
    return 3;
}

- (NSArray *)scopeBar:(MGScopeBar *)theScopeBar itemIdentifiersForGroup:(NSInteger)groupNumber
{
	NSArray *result = nil;
	switch(groupNumber)
	{
		case kGenreGroup:
			result = [KTDesign genreValues];
#ifdef DEBUG
//			result = [result arrayByAddingObject:@"NULL"];
#endif
			break;
		case kColorGroup:
			result = [KTDesign colorValues];
#ifdef DEBUG
//			result = [result arrayByAddingObject:@"NULL"];
#endif
			break;
		case kWidthGroup:
			result = [KTDesign widthValues];
#ifdef DEBUG
//			result = [result arrayByAddingObject:@"NULL"];
#endif
			break;
	}
	return result;
}

- (NSString *)scopeBar:(MGScopeBar *)theScopeBar labelForGroup:(NSInteger)groupNumber
{
//	NSString *result = nil;
//	switch(groupNumber)
//	{
//		case kGenreGroup:
//			result = NSLocalizedString(@"Genre");
//			break;
//		case kColorGroup:
//			result = NSLocalizedString(@"Background");
//			break;
//	}
	return @"";
}

// EXTRA METHOD NOT IN PROTOCOL, FOR MODIFIED MGSCOPEBAR, FOR POPUP VERSION OF GROUP
- (NSString *)scopeBar:(MGScopeBar *)theScopeBar unselectedPopupTitleForGroup:(NSInteger)groupNumber
{
	NSString *result = nil;
	switch(groupNumber)
	{
		case kGenreGroup:
			result = NSLocalizedString(@"Genre","");
			break;
		case kColorGroup:
			result = NSLocalizedString(@"Color","");
			break;
		case kWidthGroup:
			result = NSLocalizedString(@"Width","");
			break;
	}
	return result;
}


- (MGScopeBarGroupSelectionMode)scopeBar:(MGScopeBar *)theScopeBar selectionModeForGroup:(NSInteger)groupNumber
{
    return MGMultipleSelectionMode;		// we will handle selection to be radio-like
}

- (NSString *)scopeBar:(MGScopeBar *)theScopeBar 
           titleOfItem:(NSString *)identifier 
               inGroup:(NSInteger)groupNumber
{
	if ([identifier hasPrefix:@"NULL"])
	{
		return [NSString stringWithUnichar:0x2205];
	}
	if (kWidthGroup == groupNumber || kColorGroup == groupNumber) return @"";

	// We are ignoring the scope bar and group number parameter; it's not used.
	
	static NSDictionary *sDesignScopeBarTitles = nil;
	if (!sDesignScopeBarTitles)
	{
		sDesignScopeBarTitles = [[NSDictionary alloc] initWithObjectsAndKeys:
NSLocalizedString(@"Minimal", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"minimal",
		NSLocalizedString(@"Glossy", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"glossy",
		NSLocalizedString(@"Subtle", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"subtle",
		NSLocalizedString(@"Bold", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"bold",
		NSLocalizedString(@"Artistic", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"artistic",
		NSLocalizedString(@"Specialty", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"specialty",
				 
								 nil];
	}
	NSString *result = nil;
	if (nil != identifier)		// look up only if it's not nil.
	{
		result = [sDesignScopeBarTitles objectForKey:identifier];
		if (!result)
		{
			result = [identifier uppercaseString];	// uppercase to help identify that it's not really localized
		}
	}
	return result;
}

- (NSImage *)scopeBar:(MGScopeBar *)theScopeBar imageForItem:(NSString *)identifier inGroup:(NSInteger)groupNumber;
{
	static NSDictionary *sDesignScopeBarImages = nil;
	if (!sDesignScopeBarImages)
	{
		sDesignScopeBarImages = [[NSDictionary alloc] initWithObjectsAndKeys:
								 [NSImage imageNamed:@"standard-design"], @"standard",
								 [NSImage imageNamed:@"wide-design"], @"wide",
								 [NSImage imageNamed:@"flexible-design"], @"flexible",
								 [NSImage imageNamed:@"dark-design"], @"dark",
								 [NSImage imageNamed:@"bright-design"], @"bright",
								 [NSImage imageNamed:@"colorful-design"], @"colorful",
								 nil];
	}
	return [sDesignScopeBarImages objectForKey:identifier];
}

- (NSString *)scopeBar:(MGScopeBar *)theScopeBar AXDescriptionForItem:(NSString *)identifier inGroup:(NSInteger)groupNumber; // default is no toolTip.
{
	if ([identifier hasPrefix:@"NULL"])
	{
		return [NSString stringWithUnichar:0x2205];
	}
	static NSDictionary *sDesignScopeBarTooltips = nil;
	if (!sDesignScopeBarTooltips)
	{
		sDesignScopeBarTooltips = [[NSDictionary alloc] initWithObjectsAndKeys:
								   NSLocalizedString(@"Standard width", @"type of design"), @"standard",
								   NSLocalizedString(@"Wide width", @"type of design"), @"wide",
								   NSLocalizedString(@"Flexible width", @"type of design"), @"flexible",
								   NSLocalizedString(@"Bright", @"type of design"), @"bright",
								   NSLocalizedString(@"Dark", @"type of design"), @"dark",
								   NSLocalizedString(@"Colorful", @"type of design"), @"colorful",
								   nil];
	}
	NSString *result = [sDesignScopeBarTooltips objectForKey:identifier];
	if (!result) result = [identifier uppercaseString];	// uppercase to help identify that it's not really localized
	return result;
}
// Respond to clicks by acting sort of like a radio button, but allowing for none to be clicked.
// thus we de-select any old item in the group if we are setting a new one.
// Then, based on which ones are selected, build up our filter predicate.

- (void)scopeBar:(MGScopeBar *)theScopeBar selectedStateChanged:(BOOL)selected forItem:(NSString *)identifier inGroup:(NSInteger)groupNumber;
{
	switch (groupNumber)
	{
		case kGenreGroup:
		{
			if (selected && self.genre && (self.genre != identifier))
			{
				// turn off previous selection in this group
				[theScopeBar setSelected:NO forItem:self.genre inGroup:kGenreGroup];
			}
			self.genre = selected ? identifier : nil;
			break;
		}	
		case kColorGroup:
		{
			if (selected && self.color && (self.color != identifier))
			{
				// turn off previous selection in this group
				[theScopeBar setSelected:NO forItem:self.color inGroup:kColorGroup];
			}
			self.color = selected ? identifier : nil;
			break;
		}
		case kWidthGroup:
		{
			if (selected && self.width && (self.width != identifier))
			{
				// turn off previous selection in this group
				[theScopeBar setSelected:NO forItem:self.width inGroup:kWidthGroup];
			}
			self.width = selected ? identifier : nil;
			break;
		}
	}

	if (self.genre || self.color || self.width)
	{
		NSMutableArray *preds = [NSMutableArray array];
		if (self.color)
		{
			if (![@"NULL" isEqualToString:self.color])
			{
				[preds addObject:[NSPredicate predicateWithFormat:@"color == %@", [self.color lowercaseString]]];
			}
			else
			{
				[preds addObject:[NSPredicate predicateWithFormat:@"color == NULL"]];
			}
			
		}
		if (self.genre)
		{
			if (![@"NULL" isEqualToString:self.genre])
			{
				[preds addObject:[NSPredicate predicateWithFormat:@"genre == %@", [self.genre lowercaseString]]];
			}
			else
			{
				[preds addObject:[NSPredicate predicateWithFormat:@"genre == NULL"]];
			}
		}
		if (self.width)
		{
			if (![@"NULL" isEqualToString:self.width])
			{
				[preds addObject:[NSPredicate predicateWithFormat:@"width == %@", [self.width lowercaseString]]];
			}
			else
			{
				[preds addObject:[NSPredicate predicateWithFormat:@"width == NULL"]];
			}
		}
		
		oViewController.designs = [self.allDesigns filteredArrayUsingPredicate:
								   [NSCompoundPredicate andPredicateWithSubpredicates:preds]
								   ];
	}
	else	// no filter -- all
	{
		oViewController.designs = self.allDesigns;
	}
}



@end
