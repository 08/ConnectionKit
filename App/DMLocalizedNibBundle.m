//  DMLocalizedNibBundle.m
//
//  Created by William Jon Shipley on 2/13/05.
//  Copyright © 2005-2009 Golden % Braeburn, LLC. All rights reserved except as below:
//  This code is provided as-is, with no warranties or anything. You may use it in your projects as you wish, but you must leave this comment block (credits and copyright) intact. That's the only restriction -- Golden % Braeburn otherwise grants you a fully-paid, worldwide, transferrable license to use this code as you see fit, including but not limited to making derivative works.
//
//
// Modified by Dan Wood of Karelia Software
//
// Some of this is inspired and modified by GTMUILocalizer from Google Toolbox http://google-toolbox-for-mac.googlecode.com
// (BSD license)

// KNOWN LIMITATIONS
//
// NOTE: NSToolbar localization support is limited to only working on the
// default items in the toolbar. We cannot localize items that are on of the
// customization palette but not in the default items because there is not an
// API for NSToolbar to get all possible items. You are responsible for
// localizing all non-default toolbar items by hand.
//
// Due to technical limitations, accessibility description cannot be localized.
// See http://lists.apple.com/archives/Accessibility-dev/2009/Dec/msg00004.html
// and http://openradar.appspot.com/7496255 for more information.


#define DEBUG_THIS_USER @"dwood"

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "Debug.h"

#import "NSString+Karelia.h"

// ===========================================================================
// Based on GTMUILocalizerAndTweaker.m

#pragma mark Resizing Support

// Constant for a forced string wrap in button cells (Opt-Return in IB inserts
// this into the string).
NSString * const kForcedWrapString = @"\xA";
// Radio and Checkboxes (NSButtonCell) appears to use two different layout
// algorithms for sizeToFit calls and drawing calls when there is a forced word
// wrap in the title.  The result is a sizeToFit can tell you it all fits N
// lines in the given rect, but at draw time, it draws as >N lines and never
// gets as wide, resulting in a clipped control.  This fudge factor is what is
// added to try and avoid these by giving the size calls just enough slop to
// handle the differences.
// radar://7831901 different wrapping between sizeToFit and drawing
static const CGFloat kWrapperStringSlop = 0.9;

static CGFloat ResizeToFit(NSView *view, NSUInteger level);

static void OffsetView(NSView *view, NSPoint offset)
{
	NSRect newFrame = [view frame];
	newFrame.origin.x += offset.x;
	newFrame.origin.y += offset.y;
	[view setFrame:newFrame];
}

@interface NSView (desc)
- (NSString *)description;
@end
@implementation NSView (desc)
- (NSString *)description;
{
	NSMutableString *desc = [NSMutableString string];
	NSUInteger mask = [self autoresizingMask];
	BOOL stretchyLeft = 0 != (mask & NSViewMinXMargin);
	BOOL stretchyView = 0 != (mask & NSViewWidthSizable);
	BOOL stretchyRight = 0 != (mask & NSViewMaxXMargin);
	
	NSString *leftMargin	= stretchyLeft	? @"···"	: @"———";
	NSString *leftWidth		= stretchyView	? @"<ɕɕ"	: @"<··";
	NSString *rightWidth	= stretchyView	? @"ɕɕ>"	: @"··>";
	NSString *rightMargin	= stretchyRight	? @"···"	: @"———";
	
	[desc appendString:leftMargin];
	[desc appendString:leftWidth];
	[desc appendString:[super description]];
	if ([self isKindOfClass:[NSTextField class]])
	{
		NSTextField *field = (NSTextField *)self;
		NSString *stringValue = [field stringValue];
		if ([field isEditable] || [field isBezeled] || [field isBordered])
		{
			[desc appendFormat:@"#%@           #",stringValue];
		}
		else if ([[stringValue condenseWhiteSpace] isEqualToString:@""])
		{
			[desc appendFormat:@"\"%@\"",stringValue];
		}
		else
		{
			[desc appendString:stringValue];
		}
	}
	else if ([self isKindOfClass:[NSPopUpButton class]])
	{
		NSPopUpButton *pop = (NSPopUpButton *)self;
		NSString *selTitle = [pop titleOfSelectedItem];
		if (!selTitle || [selTitle isEqualToString:@""])
		{
			selTitle = [pop itemTitleAtIndex:0];
		}
		if (selTitle && ![selTitle isEqualToString:@""])
		{
			[desc appendFormat:@"{%@}", selTitle];
		}
	}
	else if ([self isKindOfClass:[NSButton class]])
	{
		NSButton *button = (NSButton *)self;
		NSString *title = [button title];
		
		if (title && ![title isEqualToString:@""])
		{
			[desc appendFormat:@"{%@}", title];
		}
	}
	
	[desc appendFormat:@" %.0f+%.0f ", [self frame].origin.x, [self frame].size.width];
	[desc appendString:rightWidth];
	[desc appendString:rightMargin];
	return desc;
}
@end


static NSString *DescViewsInRow(NSArray *sortedRowViews)
{
	NSMutableString *rowDesc = [NSMutableString string];
	for (NSView *rowView in sortedRowViews)
	{
		NSString *desc = [rowView description];
		[rowDesc appendString:desc];
		[rowDesc appendString:@" "];
	}
	return rowDesc;
}

static void LogRows(NSDictionary *rows)
{
	NSArray *sortedRanges = [[rows allKeys] sortedArrayUsingSelector:@selector(compareRangeLocation:)];
	int i = 0;
	for (NSValue *rowValue in [sortedRanges reverseObjectEnumerator])
	{
		NSRange rowRange = [rowValue rangeValue];
		NSArray *subviewsOnThisRow = [rows objectForKey:rowValue];
		NSString *desc = DescViewsInRow(subviewsOnThisRow);
		LogIt(@"%2d. [%3d-%-3d] %@", i++, rowRange.location, NSMaxRange(rowRange), desc);
	}	
}

static NSRange CalcYRange(NSView *view)
{
	NSRect frame = [view frame];
	// NSLog(@"%@ -> %@", subview, NSStringFromRect(frame));
	NSRange yRange = NSMakeRange(frame.origin.y, frame.size.height);
	// Fudge just a little bit ... chop off the bottom and top 2 pixels, so that things seem less likely to intersect
	if (frame.size.height > 4)
	{
		yRange = NSMakeRange(frame.origin.y + 2, frame.size.height - 4);
	}
	return yRange;
}

static NSDictionary *GroupSubviewsIntoRows(NSView *view)
{
	NSArray *subviews = [view subviews];
	// Dictionary, where keys are NSRange/NSValues (each representing a "row" of pixels in alignment) with value being NSMutableArray (left to right?) of subviews
	NSMutableDictionary *rows = [NSMutableDictionary dictionary];
	
	for (NSView *subview in subviews)
	{
		NSRange yRange = CalcYRange(subview);
		
		// Now see if this range intersects one of our index sets
		BOOL found = NO;
		for (NSValue *rowValue in [rows allKeys])
		{
			NSRange rowRange = [rowValue rangeValue];
			if (NSIntersectionRange(rowRange, yRange).length)
			{
				// Add this subview to the list for this row
				NSMutableArray *viewArray = [rows objectForKey:rowValue];
				[viewArray addObject:subview];
				
				// Extend the row range if needed, and modify dictionary if it changed
				NSRange newRowRange = NSUnionRange(rowRange, yRange);
				if (!NSEqualRanges(newRowRange, rowRange))
				{
					[rows setObject:viewArray forKey:[NSValue valueWithRange:newRowRange]];
					[rows removeObjectForKey:rowValue];
				}
				found = YES;
				break;  // found, so no need to keep looking
			}
		}
		if (!found)	// not found, make a new row entry
		{
			[rows setObject:[NSMutableArray arrayWithObject:subview] forKey:[NSValue valueWithRange:yRange]];
		}
	}
	
	// Now before returning the dictionary, go through each row, and look for views that overlap more than one other view.
	// They are special cases that we want to make into their own row ... for background images, horizontal lines crossing through groups, etc.
	NSMutableDictionary *adjustedRows = [NSMutableDictionary dictionary];
	
	for (NSValue *rowValue in [rows allKeys])	// Go through each row
	{
		NSArray *viewArray =  [rows objectForKey:rowValue];
		
		NSMutableArray *remainingArray = [[viewArray mutableCopy] autorelease];	// what doesn't get taken out
		
		for (NSView *viewInRow in viewArray)		// Go through each view on the row
		{
			NSRect rowViewFrame = [viewInRow frame];
			NSRange rowViewXRange = NSMakeRange(rowViewFrame.origin.x, rowViewFrame.size.width);
			NSUInteger numberOfIntersections = 0;
			for (NSView *compareView in remainingArray)
			{
				// Go through the OTHER views on the row. Might as well not go through already-removed ones.
				if (compareView != viewInRow)			// Of course don't compare to yourself.
				{
					NSRect compareViewFrame = [compareView frame];
					NSRange compareViewXRange = NSMakeRange(compareViewFrame.origin.x, compareViewFrame.size.width);
					
					if (NSIntersectionRange(rowViewXRange, compareViewXRange).length)
					{
						numberOfIntersections++;
						// I suppose we could break when we reach two intersections but these rows aren't going to have a lot of elements
					}
				}
			}
			if (numberOfIntersections >= 2)	// This view intersects with 2 or more views, so make it on a row by itself.
			{
				NSRange yRange = CalcYRange(viewInRow);
				[adjustedRows setObject:[NSMutableArray arrayWithObject:viewInRow] forKey:[NSValue valueWithRange:yRange]];
				[remainingArray removeObject:viewInRow];
			}
		}
		
		// Now, before we set the rows key, sort the views by X location.
		NSArray *sortedRowViews = [remainingArray sortedArrayUsingSelector:@selector(compareViewFrameOriginX:)];

		[adjustedRows setObject:sortedRowViews forKey:rowValue];
	}
	
	return [NSDictionary dictionaryWithDictionary:adjustedRows];
}

const NSUInteger kGroupMarginRegular = 24;
const NSUInteger kGroupMarginSmall = 16;

static NSUInteger GuessControlSizeGroupingMargin(NSView *view)
{
	NSUInteger result = NSNotFound;					// keep it at NSNotFound unless we really can test.
	if ([view respondsToSelector:@selector(cell)])
	{
		NSCell *cell = [((NSControl *)view) cell];
		NSControlSize controlSize = [cell controlSize];
		switch (controlSize)
		{
			case NSRegularControlSize: result = kGroupMarginRegular; break;	// Twice the normal button spacing for that size
			case NSSmallControlSize: result = kGroupMarginSmall; break;	// according to Interface Builder guides.
			case NSMiniControlSize: result = kGroupMarginSmall; break;		// are these in the HIG?
		}
	}
	return result;
}

#pragma mark Resizing Logic


static void ResizeRowsByDelta(NSArray *rowViews, CGFloat delta)
{
	for (NSView *view in rowViews)
	{
		// Apply the struts and springs to each item
		NSUInteger mask = [view autoresizingMask];
		BOOL stretchyLeft = 0 != (mask & NSViewMinXMargin);
		BOOL stretchyView = 0 != (mask & NSViewWidthSizable);
		BOOL stretchyRight = 0 != (mask & NSViewMaxXMargin);
		
		NSRect newFrame = [view frame];
		if (stretchyView)
		{
			if (stretchyLeft)
			{
				newFrame.size.width += delta/2.0;
				newFrame.origin.x += delta/2.0;
			}
			else if (stretchyRight)
			{
				newFrame.size.width += delta/2.0;
			}
			else
			{
				newFrame.size.width += delta;		// the width gets half of it
			}
		}
		else if (stretchyLeft && stretchyRight)
		{
			newFrame.origin.x += delta/2.0;
		}
		else if (stretchyLeft && !stretchyRight)
		{
			newFrame.origin.x += delta;
		}
		[view setFrame:newFrame];
	}
}

/*
 Assumes we are looping through these from left to right, and that there aren't any wacky things like
 right-anchored views to the left of left-anchored views.

 Left-anchored views increase width, and move over the left edge only as much as needed to to keep relative position constant.
 Views anchored neither left nor right are going be roughly centered, so take any change in width on the left and right sides equally.
 Right-anchored views keep a constant right margin and increase width on the left side.
 HOWEVER (for the center and right views), we want to make sure that the margin between views does not dip below MIN(20,currentDistance)
	(or 10? Is ther some heuristic to apply, e.g. text size, current margins, etc.?
 
 */
static CGFloat ResizeRowViews(NSArray *rowViews, NSUInteger level)
{
	CGFloat accumulatingDelta = 0;
	CGFloat previousDelta = 0;
	CGFloat runningMaxX = 0;
	CGFloat previousOriginalMaxX = NSNotFound;
	CGFloat previousOriginalMinX = NSNotFound;
	NSUInteger controlGroupingMargin = NSNotFound;	// try to give this a real value based on control size of first item that can be found
	
	NSString *desc = DescViewsInRow(rowViews);
	LogIt(@"%@ROW %@", [@"                                                            " substringToIndex:2*level], desc);
	
	
	// Size our rowViews
	
	NSPoint subviewOffset = NSZeroPoint;
	for (NSView *subview in rowViews)
	{
		LogIt(@"%@ROWVIEW%@", [@"                                                            " substringToIndex:2*level+1], [subview description]);
		// Try to figure out minimum spacing for groups of controls that are aligned differently
		if (NSNotFound == controlGroupingMargin)
		{
			controlGroupingMargin = GuessControlSizeGroupingMargin(subview);
		}
		
//		if ([subview isKindOfClass:[NSTextField class]] && [[subview stringValue] hasPrefix:@"[SCALE"])
//		{
//			NSLog(@"Break here");
//		}
		if ([subview isKindOfClass:[NSButton class]] && [[subview title] hasPrefix:@"Prefer links"])
		{
			NSLog(@"Break here");
		}
//		if ([subview isKindOfClass:[NSBox class]] && [subview frame].origin.y == 62.0)
//		{
//			NSLog(@"Break here - this is the separator line");
//		}
//		if ([subview isMemberOfClass:[NSView class]] && [subview frame].size.width == 59.0)
//		{
//			NSLog(@"Break here - this is the left box");
//		}
		
		// Hmm, what to do about a right-aligned text item that is anchored to the left?
		
		
		NSRect originalRect = [subview frame];				// bounds before resizing
		
//		if (previousOriginalMinX != NSNotFound && NSMinX(originalRect) < previousOriginalMaxX)
//		{
//			NSLog(@"minX of this is less than maxX of previous; must be overlapping");
//		}
		
		CGFloat sizeDelta = ResizeToFit(subview, level+1);	// How much it got increased (to the right)

		NSUInteger mask = [subview autoresizingMask];
		BOOL anchorLeft = 0 == (mask & NSViewMinXMargin);
		BOOL anchorRight = 0 == (mask & NSViewMaxXMargin);
		CGFloat moveLeft = 0;
		if (!anchorLeft)
		{
			if (!anchorRight)	// not anchored right, so stretchy left and right.  
			{
				moveLeft = floorf(sizeDelta/2.0);
			}
			else	// Anchored right. Try to keep right side constant, meaning we move to the left
					// (or if sizeDelta < 1 then we are actually moving the left edge to the right
			{
				moveLeft = sizeDelta;
			}
		}
		
		CGFloat originalMargin = (NSNotFound != previousOriginalMaxX)
			? NSMinX(originalRect) - previousOriginalMaxX
			: 0;
		if (originalMargin >= 0)
		{
			// move things over an increment delta if we are not overlapping view to the left.
	
			CGFloat acceptableMargin = MIN(originalMargin, (NSNotFound == controlGroupingMargin) ? kGroupMarginRegular : controlGroupingMargin);
			
			moveLeft = MIN(moveLeft, acceptableMargin);	// move left as much as you can, but maybe only "acceptableMargin" pixels
			
			
			subviewOffset.x = accumulatingDelta-moveLeft;	// we'll be moving it over by the so-far delta
			OffsetView(subview, subviewOffset);				// slide left edge over to running delta.
			
			runningMaxX = NSMaxX([subview frame]);
			
			previousDelta = accumulatingDelta;
			accumulatingDelta += sizeDelta - moveLeft;	// take away however many pixels we moved left			
		}
		else
		{
			// Overlapping views, so don't increase delta.  However we probably want to move over to match
			// whatever the delta was on the previous view, so use that.
			subviewOffset.x = previousDelta;
			OffsetView(subview, subviewOffset);			
		}
		
		previousOriginalMaxX = NSMaxX(originalRect);
		previousOriginalMinX = NSMinX(originalRect);
	}
	
	return accumulatingDelta;
}


static CGFloat ResizeAnySubviews(NSView *view, NSUInteger level)
{
	CGFloat maxWidth = 0.0;
	CGFloat delta = 0.0;

	if ([[view subviews] count])
	{
		// TabView:  Just pass this down to the tabviews to handle, and get our largest width.
		
		if ([view isKindOfClass:[NSTabView class]])
		{
			NSArray *tabViewItems = [(NSTabView *)view tabViewItems];
			LogIt(@"%@TABVIEWS %@", [@"                                                            " substringToIndex:2*level], [[tabViewItems description] condenseWhiteSpace]);
			for (NSTabViewItem *item in tabViewItems)		// resize tabviews instead of subviews
			{
				(void) ResizeToFit([item view], level+1);
				CGFloat width = NSWidth([[item view] frame]);
				
				maxWidth = MAX(width,maxWidth);		// pay attention to the largest width we had to resize things
			}
			
			// after resizing subviews, I should go through again and actually set the new dimensions?
			for (NSTabViewItem *item in tabViewItems)		// resize tabviews instead of subviews
			{
				NSRect newFrame = [[item view] frame];
				newFrame.size.width = maxWidth;		// autoresizesSubviews should handle the details
				[[item view] setFrame:newFrame];
			}
			
			// Now the tricky part is to set this enclosing view properly
			// From what I can tell, the tabview is always 20 pixels larger than its contained views.
			NSRect originalFrame = [view frame];
			NSRect newFrame = originalFrame;
			newFrame.size.width = maxWidth + 20;
			[view setFrame:newFrame];
			delta = NSWidth(newFrame) - NSWidth(originalFrame);
		}
		else	// standard subviews, group into rows and find widest row.
		{
			NSDictionary *rows = GroupSubviewsIntoRows(view);
			// LogRows(rows);
			NSMutableDictionary *deltasForRows = [NSMutableDictionary dictionary];
		
			NSArray *sortedRanges = [[rows allKeys] sortedArrayUsingSelector:@selector(compareRangeLocation:)];
			for (NSValue *rowValue in [sortedRanges reverseObjectEnumerator])
			{
				NSArray *subviewsOnThisRow = [rows objectForKey:rowValue];
				
				CGFloat rowDelta = ResizeRowViews(subviewsOnThisRow, level+1);
				delta = MAX(rowDelta, delta);	// save the max delta so we know how much to catch the others up to.
				
				[deltasForRows setObject:[NSNumber numberWithFloat:rowDelta] forKey:rowValue];
								
				LogIt(@"Delta for this row: %.2f", delta);
//				if (delta == 103.0)
//				{
//					NSLog(@"103");
//				}
			}
			
			// After resizing rows, I should go through again and set the new dimensions to match the widest row
			for (NSValue *rowValue in [sortedRanges reverseObjectEnumerator])
			{
				NSArray *subviewsOnThisRow = [rows objectForKey:rowValue];
				CGFloat rowDelta = [[deltasForRows objectForKey:rowValue] floatValue];
				CGFloat neededDelta = delta - rowDelta;
				
				ResizeRowsByDelta(subviewsOnThisRow, neededDelta);
			}
			
			// Now we have the largest that the subviews had to resize; it's time to apply that to this view now but not its subviews.
			if (delta)
			{
				LogIt(@"%@%@ Largest Delta for this whole view: %.2f", [@"                                                            " substringToIndex:2*level], view, delta);
				
				// Adjust our size (turn off auto resize, because we just fixed up all the
				// objects within us).
				BOOL autoresizesSubviews = [view autoresizesSubviews];
				if (autoresizesSubviews) {
					[view setAutoresizesSubviews:NO];
				}
				NSRect selfFrame = [view frame];
				selfFrame.size.width += delta;
				[view setFrame:selfFrame];
				if (autoresizesSubviews) {
					[view setAutoresizesSubviews:autoresizesSubviews];
				}
			}
			
		}
	}
	return delta;
}

// Resizes a view to be the size it "wants" to be. Returns how much changed.
// Does not try to do any reposititioning -- not its job.  It increases the width, caller needs to decide if it should be moved left.
// Note that a springy view is not allowed to shrink, at present.

static CGFloat ResizeToFit(NSView *view, NSUInteger level)
{
	// logging newline comes at the end
	Log(@"%@RESIZE %@", [@"                                                            " substringToIndex:2*level], [[view description] condenseWhiteSpace]);
	CGFloat delta = 0.0;
	
	if ([[view subviews] count])		// Subviews: Get the subviews resized; that's the width this view wants to be.
	{
		LogIt(@"");		// newline
		delta = ResizeAnySubviews(view, level+1);
	}
	else	// A primitive view without subviews; size according to its contents
	{
		NSRect oldFrame = [view frame];		// keep track of original frame so we know how much it resized
		NSRect fitFrame = oldFrame;			// only set differently when sizeToFit is called, so we know it was already called
		NSRect newFrame = oldFrame;			// what we will be setting the frame to (if not already done)

	//	// Try to turn on some stuff that will help me see the new bounds
	//	if ([view respondsToSelector:@selector(setBordered:)]) {
	//		[((NSTextField *)view) setBordered:YES];
	//	}
	//	if ([view respondsToSelector:@selector(setDrawsBackground:)]) {
	//		[((NSTextField *)view) setDrawsBackground:YES];
	//	}
	//	
	//	
		if ([view isKindOfClass:[NSTextField class]] &&
			[(NSTextField *)view isEditable]) {
			// Don't try to sizeToFit because edit fields really don't want to be sized
			// to what is in them as they are for users to enter things so honor their
			// current size.
		} else if ([view isKindOfClass:[NSPathControl class]]) {
			// Don't try to sizeToFit because NSPathControls usually need to be able
			// to display any path, so they shouldn't tight down to whatever they
			// happen to be listing at the moment.
		} else if ([view isKindOfClass:[NSImageView class]]) {
			// Definitely don't mess with size of an imageView
		} else if ([view isKindOfClass:[NSBox class]]) {
			// I don't think it's a good idea to let NSBox figure out its sizeToFit.
		} else if ([view isKindOfClass:[NSPopUpButton class]]) {
			// Popup buttons: Let's assume that we don't want to resize them.  Maybe later I can loop through strings
			// to get a minimum width, though some popups are designed to already be less than longest string.
			// But one thing is clear: I don't want to shrink one that is stretchy, since it's probably
			// intended to fill a space.
		} else {
			// Generically fire a sizeToFit if it has one.  e.g. NSTableColumn, NSProgressIndicator, (NSBox), NSMenuView, NSControl, NSTableView, NSText
			if ([view respondsToSelector:@selector(sizeToFit)]) {
				
				[view performSelector:@selector(sizeToFit)];
				fitFrame = [view frame];
				newFrame = fitFrame;
				
				if ([view isKindOfClass:[NSMatrix class]]) {
					NSMatrix *matrix = (NSMatrix *)view;
					// See note on kWrapperStringSlop for why this is done.
					for (NSCell *cell in [matrix cells]) {
						if ([[cell title] rangeOfString:kForcedWrapString].location !=
							NSNotFound) {
							newFrame.size.width += kWrapperStringSlop;
							break;
						}
					}
				}
				
			}
			
			// AFTER calling sizeToFit, we might override this sizing that just happened
			
			if ([view isKindOfClass:[NSButton class]]) {
				NSButton *button = (NSButton *)view;
							
				// -[NSButton sizeToFit] gives much worse results than IB's Size to Fit
				// option for standard push buttons.
				if (([button bezelStyle] == NSRoundedBezelStyle) &&
					([[button cell] controlSize] == NSRegularControlSize)) {
					// This is the amount of padding IB adds over a sizeToFit, empirically
					// determined.
					const CGFloat kExtraPaddingAmount = 12.0;
					// Width is tricky, new buttons in IB are 96 wide, Carbon seems to have
					// defaulted to 70, Cocoa seems to like 82.  But we go with 96 since
					// that's what IB is doing these days.
					const CGFloat kMinButtonWidth = (CGFloat)96.0;
					newFrame.size.width = NSWidth(newFrame) + kExtraPaddingAmount;
					if (NSWidth(newFrame) < kMinButtonWidth) {
						newFrame.size.width = kMinButtonWidth;
					}
				} else {
					// See note on kWrapperStringSlop for why this is done.
					NSString *title = [button title];
					if ([title rangeOfString:kForcedWrapString].location != NSNotFound) {
						newFrame.size.width += kWrapperStringSlop;
					}
				}
			}
		}
		
		// Now after we've tried all of this resizing, let's see if it's gotten narrower AND we wanted
		// a stretchy view.  If a view is stretchy, it means we didn't really intend on shrinking it.
		NSUInteger mask = [view autoresizingMask];
		BOOL stretchyView = 0 != (mask & NSViewWidthSizable);	// If stretchy view, DO NOT SHRINK.
		if (stretchyView && (NSWidth(newFrame) < NSWidth(oldFrame)))
		{
			newFrame = oldFrame;		// go back to the old frame; reject the size change.
			
			// However there may be the case where we had to grow a neighbor and we want to shrink the springy view slightly.... Hmm...
		}
		
		if (!NSEqualRects(fitFrame, newFrame)) {
			[view setFrame:newFrame];
		}
		
		// Return how much we changed size.
		delta = NSWidth(newFrame) - NSWidth(oldFrame);
		if (!delta) LogIt(@" (no change)"); else LogIt(@" ... to %+.0f (∂ %.0f)", NSWidth(newFrame), delta);
	}
	return delta;
}


@interface NSValue (comparison)

- (NSComparisonResult)compareRangeLocation:(NSValue *)otherRangeValue;

@end

@implementation NSValue (comparison)

- (NSComparisonResult)compareRangeLocation:(NSValue *)otherRangeValue;
{
	NSUInteger location = [self rangeValue].location;
	NSUInteger otherLocation = [otherRangeValue rangeValue].location;
	
	if (location == otherLocation) return NSOrderedSame;
    else if (location > otherLocation) return NSOrderedDescending;
    else return NSOrderedAscending;
}

@end

@interface NSView (comparison)

- (NSComparisonResult)compareViewFrameOriginX:(NSView *)otherView;

@end

@implementation NSView (comparison)

- (NSComparisonResult)compareViewFrameOriginX:(NSView *)otherView;
{
	CGFloat originX = [self frame].origin.x;
	CGFloat otherOriginX = [otherView frame].origin.x;
	
	if (originX == otherOriginX) return NSOrderedSame;
    else if (originX > otherOriginX) return NSOrderedDescending;
    else return NSOrderedAscending;
}

@end




@interface NSBundle (DMLocalizedNibBundle)
+ (BOOL)deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone;
@end


// Try to swizzle in -[NSViewController loadView]

@interface NSViewController (DMLocalizedNibBundle)
- (void)deliciousLocalizingLoadView;
@end






@interface NSBundle ()
+ (BOOL)_deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone bundle:(NSBundle *)aBundle;

+ (NSString *)	 _localizedStringForString:(NSString *)string bundle:(NSBundle *)bundle table:(NSString *)table;
+ (void)				  _localizeStringsInObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
// localize particular attributes in objects
+ (void)					_localizeTitleOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
+ (void)		   _localizeAlternateTitleOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
+ (void)			  _localizeStringValueOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
+ (void)		_localizePlaceholderStringOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
+ (void)				  _localizeToolTipOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
+ (void)				    _localizeLabelOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
+ (void)			 _localizePaletteLabelOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;


@end

@implementation NSViewController (DMLocalizedNibBundle)

+ (void)load;
{
    NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
    if (
		
		([NSUserName() isEqualToString:DEBUG_THIS_USER]) &&
		
		self == [NSViewController class]) {
		NSLog(@"Switching in NSViewController Localizer!");
        method_exchangeImplementations(class_getInstanceMethod(self, @selector(loadView)), class_getInstanceMethod(self, @selector(deliciousLocalizingLoadView)));
    }
    [autoreleasePool release];
}


- (void)deliciousLocalizingLoadView
{
	NSString		*nibName	= [self nibName];
	NSBundle		*nibBundle	= [self nibBundle];		
	if(!nibBundle) nibBundle = [NSBundle mainBundle];
	NSString		*nibPath	= [nibBundle pathForResource:nibName ofType:@"nib"];
	NSDictionary	*context	= [NSDictionary dictionaryWithObjectsAndKeys:self, NSNibOwner, nil];
	
	// NSLog(@"loadView %@ going to localize %@ with top objects: %@", [[nibBundle bundlePath] lastPathComponent], [nibPath lastPathComponent], [[context description] condenseWhiteSpace]);
	BOOL loaded = [NSBundle _deliciousLocalizingLoadNibFile:nibPath externalNameTable:context withZone:nil bundle:nibBundle];	// call through to support method
	if (!loaded)
	{
		[NSBundle deliciousLocalizingLoadNibFile:nibPath externalNameTable:context withZone:nil];	// use old-fashioned way
	}
}

@end


@implementation NSBundle (DMLocalizedNibBundle)

+ (void)load;
{
    NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
    if (
		
		([NSUserName() isEqualToString:DEBUG_THIS_USER]) &&
		
		self == [NSBundle class]) {
		NSLog(@"Switching in NSBundle localizer. W00T!");
        method_exchangeImplementations(class_getClassMethod(self, @selector(loadNibFile:externalNameTable:withZone:)), class_getClassMethod(self, @selector(deliciousLocalizingLoadNibFile:externalNameTable:withZone:)));
    }
    [autoreleasePool release];
}

// Method that gets swapped
+ (BOOL)deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone;
{
	BOOL result = NO;
	// Don't allow this to localize any file that is not in the app bundle!
	if ([fileName hasPrefix:[[NSBundle mainBundle] bundlePath]])
	{
		// NSLog(@"loadNibFile going to localize %@ with top objects: %@", [fileName lastPathComponent], [[context description] condenseWhiteSpace]);
		result = [self _deliciousLocalizingLoadNibFile:fileName externalNameTable:context withZone:zone bundle:[NSBundle mainBundle]];
	}
	else
	{
		NSLog(@"%s is NOT LOCALIZING non-app loadNibFile:%@",__FUNCTION__, fileName);
	}
	if (!result)
	{
		// try original version
		result = [self deliciousLocalizingLoadNibFile:fileName externalNameTable:context withZone:zone];
	}
	return result;
}





#pragma mark Private API


/*
 
 Aspects of a nib still to do:
	NSTableView
	AXDescription and AXRole
	
 Others?
 
 Next up: stretching items....
 
 
 */


// Internal method, which gets an extra parameter for bundle
+ (BOOL)_deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone bundle:(NSBundle *)aBundle;
{
	//NSLog(@"%s %@",__FUNCTION__, fileName);
	
	// Note: What about loading not from the main bundle? Can I try to load from where the nib file came from?
	
    NSString *localizedStringsTableName = [[fileName lastPathComponent] stringByDeletingPathExtension];
    NSString *localizedStringsTablePath = [[NSBundle mainBundle] pathForResource:localizedStringsTableName ofType:@"strings"];
    if (
		
		([NSUserName() isEqualToString:@"dwood"]) || 
		
		localizedStringsTablePath
		&& ![[[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent] isEqualToString:@"English.lproj"]
		&& ![[[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent] isEqualToString:@"en.lproj"]
		)
	{
        NSNib *nib = [[NSNib alloc] initWithContentsOfURL:[NSURL fileURLWithPath:fileName]];
        NSMutableArray *topLevelObjectsArray = [context objectForKey:NSNibTopLevelObjects];
        if (!topLevelObjectsArray) {
            topLevelObjectsArray = [NSMutableArray array];
            context = [NSMutableDictionary dictionaryWithDictionary:context];
            [(NSMutableDictionary *)context setObject:topLevelObjectsArray forKey:NSNibTopLevelObjects];
        }
		
		// Note: This will call awakeFromNib so you want to make sure not to load a new nib *from*
		// awakeFromNib that inserts something into the view hiearchy, or you may have double-
		// localization happening.
        BOOL success = [nib instantiateNibWithExternalNameTable:context];
		
        [self _localizeStringsInObject:topLevelObjectsArray bundle:aBundle table:localizedStringsTableName level:0];
		
		for (id topLevelObject in topLevelObjectsArray)
		{
			if ([topLevelObject isKindOfClass:[NSView class]])
			{
				NSView *view = (NSView *)topLevelObject;
				
				// if ([fileName hasSuffix:@"PageInspector.nib"])		// THE ONLY ONE TO RESIZE, FOR NOW, JUST SO IT'S EASIER TO DEBUG.
				{
					CGFloat delta = ResizeToFit(view, 0);
					if (delta) NSLog(@"############## Warning: Delta from resizing top-level %@ view: %f", [fileName lastPathComponent], delta);
				}
			}
			else if ([topLevelObject isKindOfClass:[NSWindow class]])
			{
				NSWindow *window = (NSWindow *)topLevelObject;
				
				// Here, I think, I probably want to do some sort of call to the NSWindow delegate to ask
				// what width it would like to be for various languages, so I can make the inspector window wider for French/German.
				// That would keep it generic here.
				
				// HACK for now to make the inspector window wider.
				if ([fileName hasSuffix:@"KSInspector.nib"])
				{
					NSView *contentView = [window contentView];
					NSRect windowFrame = [contentView convertRect:[window frame]
														 fromView:nil];
//					windowFrame.size.width += 200;
//					windowFrame = [contentView convertRect:windowFrame toView:nil];
//					[window setFrame:windowFrame display:YES];	
					
					// TODO: should we update min size?
				}
				
				// Regular windows want 20 pixels right margin; utility windows 10 pixels.  I think from the HIG.
				// CGFloat desiredMargins = ([window styleMask] & NSUtilityWindowMask) ? 10 : 20;

				CGFloat delta = ResizeToFit([window contentView], 0);
				NSLog(@"Delta from resizing window-level view: %f.  Maybe I should be resizing the whole window?", delta);
					
				
			}
		}
        
        [nib release];
        return success;
        
    } else {
		
        if (nil == localizedStringsTablePath)
		{
			NSLog(@"Not running through localizer because localizedStringsTablePath == nil");
		}
		else
		{
			NSLog(@"Not running through localizer because containing dir is not English: %@", [[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent]);
		}
		
		return NO;		// not successful
    }
}

+ (void)_localizeAccessibility:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
{
	// Hack -- don't localize accessibility properties of cells, since the AXHelp of a cell is copied from the tooltip of its enclosing button.
	if ([object isKindOfClass:[NSCell class]]) return;
	
	NSArray *supportedAttrs = [object accessibilityAttributeNames];
	if ([supportedAttrs containsObject:NSAccessibilityHelpAttribute]) {
		NSString *accessibilityHelp
		= [object accessibilityAttributeValue:NSAccessibilityHelpAttribute];
		if (accessibilityHelp) {
			
			NSString *toolTip = nil;		// get the tooltip and make sure it's not the same; Help seems to come from tooltip if undefined!
			if ([object respondsToSelector:@selector(toolTip)]) toolTip = [object toolTip];
			if (![accessibilityHelp isEqualToString:toolTip])
			{
				NSString *localizedAccessibilityHelp
				= [self _localizedStringForString:accessibilityHelp bundle:bundle table:table];
				if (localizedAccessibilityHelp) {
					
					if ([object accessibilityIsAttributeSettable:NSAccessibilityHelpAttribute])
					{
						NSLog(@"ACCESSIBILITY: %@ %@", localizedAccessibilityHelp, localizedAccessibilityHelp);
						[object accessibilitySetValue:localizedAccessibilityHelp
										 forAttribute:NSAccessibilityHelpAttribute];
					}
					else
					{
						NSLog(@"DISALLOWED ACCESSIBILITY: %@ %@", localizedAccessibilityHelp, localizedAccessibilityHelp);
						
					}
				}
			}
		}
	}
}


//
// NOT SURE:
// Should we localize NSWindowController's window and NSViewController's view? Probably not; they would be top-level objects in nib.
// Or NSApplication's main menu? Probably same thing.


+ (void)_localizeStringsInObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level;
{
	if (!object) return;
	// if ([object isKindOfClass:[NSArray class]] && 0 == [object count]) return;		// SHORT CIRCUIT SO WE DON'T SEE LOGGING
	// LogIt(@"%@%@", [@"                                                            " substringToIndex:2*level], [[object description] condenseWhiteSpace]);
	level++;	// recursion will incrememnt
	// NSArray ... this is not directly in the nib, but for when we recurse.
	
    if ([object isKindOfClass:[NSArray class]]) {
        NSArray *array = object;
        
        for (id nibItem in array)
            [self _localizeStringsInObject:nibItem bundle:bundle table:table level:level];
	
	// NSCell & subclasses
		
    } else if ([object isKindOfClass:[NSCell class]]) {
        NSCell *cell = object;
        
        if ([cell isKindOfClass:[NSActionCell class]]) {
            NSActionCell *actionCell = (NSActionCell *)cell;
            
            if ([actionCell isKindOfClass:[NSButtonCell class]]) {
                NSButtonCell *buttonCell = (NSButtonCell *)actionCell;
                if ([buttonCell imagePosition] != NSImageOnly) {
                    [self _localizeTitleOfObject:buttonCell bundle:bundle table:table level:level];
                    [self _localizeStringValueOfObject:buttonCell bundle:bundle table:table level:level];
                    [self _localizeAlternateTitleOfObject:buttonCell bundle:bundle table:table level:level];
                }
                
            } else if ([actionCell isKindOfClass:[NSTextFieldCell class]]) {
                NSTextFieldCell *textFieldCell = (NSTextFieldCell *)actionCell;
                // Following line is redundant with other code, localizes twice.
                // [self _localizeTitleOfObject:textFieldCell bundle:bundle table:table level:level];
                [self _localizeStringValueOfObject:textFieldCell bundle:bundle table:table level:level];
                [self _localizePlaceholderStringOfObject:textFieldCell bundle:bundle table:table level:level];
                
            } else if ([actionCell type] == NSTextCellType) {
                [self _localizeTitleOfObject:actionCell bundle:bundle table:table level:level];
                [self _localizeStringValueOfObject:actionCell bundle:bundle table:table level:level];
            }
        }
        
	// NSToolbar
		
    } else if ([object isKindOfClass:[NSToolbar class]]) {
        NSToolbar *toolbar = object;
		NSArray *items = [toolbar items];
		for (NSToolbarItem *item in items)
		{
			[self _localizeLabelOfObject:item bundle:bundle table:table level:level];
			[self _localizePaletteLabelOfObject:item bundle:bundle table:table level:level];
			[self _localizeToolTipOfObject:item bundle:bundle table:table level:level];
		}
		
	// NSMenu
		
    } else if ([object isKindOfClass:[NSMenu class]]) {
        NSMenu *menu = object;
				
        [self _localizeTitleOfObject:menu bundle:bundle table:table level:level];
        
        [self _localizeStringsInObject:[menu itemArray] bundle:bundle table:table level:level];
        
	// NSMenuItem
		
    } else if ([object isKindOfClass:[NSMenuItem class]]) {
        NSMenuItem *menuItem = object;

		[self _localizeTitleOfObject:menuItem bundle:bundle table:table level:level];
        
        [self _localizeStringsInObject:[menuItem submenu] bundle:bundle table:table level:level];
        
	// NSView + subclasses
				
    } else if ([object isKindOfClass:[NSView class]]) {
        NSView *view = object;        
		[self _localizeAccessibility:view bundle:bundle table:table level:level];
		// Do tooltip AFTER AX since AX might just get value from tooltip. 
        [self _localizeToolTipOfObject:view bundle:bundle table:table level:level];

		// Contextual menu?  Anything else besides a popup button
		// I am NOT going to localize this, because it seems to be automatically generated, and there
		// tends to be multiple copies instantiated.  Since it's not instantiated in the nib (except perhaps
		// as a top-level object) I don't want to localize it.
		// Note: If I do, I have to be sure to not also localize a NSPopUpButton's menu, which uses the menu accessor.
		//[self _localizeStringsInObject:[view menu] bundle:bundle table:table level:level];
		
		// NSTableView
		
		if ([object isKindOfClass:[NSTableView class]]) {
			NSTableView *tableView = (NSTableView *)object;
			NSArray *columns = [tableView tableColumns];
			for (NSTableColumn *column in columns)
			{
				[self _localizeStringValueOfObject:[column headerCell] bundle:bundle table:table level:level];
			}

		// NSBox
		
		} else if ([view isKindOfClass:[NSBox class]]) {
            NSBox *box = (NSBox *)view;
            [self _localizeTitleOfObject:box bundle:bundle table:table level:level];
           
		// NSTabView
			
        } else if ([view isKindOfClass:[NSTabView class]]) {
            NSTabView *tabView = (NSTabView *)view;
			NSArray *tabViewItems = [tabView tabViewItems];
		
			for (NSTabViewItem *item in tabViewItems)
			{
				[self _localizeLabelOfObject:item bundle:bundle table:table level:level];
				
				NSView *viewToLocalize = [item view];
				if (![[view subviews] containsObject:viewToLocalize])	// don't localize one that is current subview
				{
					[self _localizeStringsInObject:viewToLocalize bundle:bundle table:table level:level];
				}
			}
		
		// NSControl + subclasses
			
        } else if ([view isKindOfClass:[NSControl class]]) {
            NSControl *control = (NSControl *)view;
            
			[self _localizeAccessibility:[control cell] bundle:bundle table:table level:level];

			
			// NSButton
			
            if ([view isKindOfClass:[NSButton class]]) {
                NSButton *button = (NSButton *)control;
                
                if ([button isKindOfClass:[NSPopUpButton class]]) {
					// Note: Be careful not to localize this *and* the menu for an NSView. 
                    NSPopUpButton *popUpButton = (NSPopUpButton *)button;
                    NSMenu *menu = [popUpButton menu];
                    
                    [self _localizeStringsInObject:[menu itemArray] bundle:bundle table:table level:level];
                } else
                    [self _localizeStringsInObject:[button cell] bundle:bundle table:table level:level];
                
			
			// NSMatrix
				
            } else if ([view isKindOfClass:[NSMatrix class]]) {
                NSMatrix *matrix = (NSMatrix *)control;
                
                NSArray *cells = [matrix cells];
                [self _localizeStringsInObject:cells bundle:bundle table:table level:level];
                
                for (NSCell *cell in cells) {
                    
                    NSString *localizedCellToolTip = [self _localizedStringForString:[matrix toolTipForCell:cell] bundle:bundle table:table];
                    if (localizedCellToolTip)
                        [matrix setToolTip:localizedCellToolTip forCell:cell];
                }
              
			// NSSegmentedControl
				
            } else if ([view isKindOfClass:[NSSegmentedControl class]]) {
                NSSegmentedControl *segmentedControl = (NSSegmentedControl *)control;
                
                NSUInteger segmentIndex, segmentCount = [segmentedControl segmentCount];
                for (segmentIndex = 0; segmentIndex < segmentCount; segmentIndex++) {
                    NSString *localizedSegmentLabel = [self _localizedStringForString:[segmentedControl labelForSegment:segmentIndex] bundle:bundle table:table];
                    if (localizedSegmentLabel)
                        [segmentedControl setLabel:localizedSegmentLabel forSegment:segmentIndex];
                    
                    [self _localizeStringsInObject:[segmentedControl menuForSegment:segmentIndex] bundle:bundle table:table level:level];
                }
             
			// OTHER ... e.g. NSTextField NSSlider NSScroller NSImageView 
				
            } else
			{
                [self _localizeStringsInObject:[control cell] bundle:bundle table:table level:level];
			}
			
        }
        
		// Then localize this view's subviews
		
        [self _localizeStringsInObject:[view subviews] bundle:bundle table:table level:level];
			       
	// NSWindow
		
    } else if ([object isKindOfClass:[NSWindow class]]) {
        NSWindow *window = object;
        [self _localizeTitleOfObject:window bundle:bundle table:table level:level];
        
        [self _localizeStringsInObject:[window contentView] bundle:bundle table:table level:level];
		[self _localizeStringsInObject:[window toolbar] bundle:bundle table:table level:level];

    }
	
	// Finally, bindings.  Basically lifted from the Google Toolkit.
	NSArray *exposedBindings = [object exposedBindings];
	if (exposedBindings) {
		NSString *optionsToLocalize[] = {
			NSDisplayNameBindingOption,
			NSDisplayPatternBindingOption,
			NSMultipleValuesPlaceholderBindingOption,
			NSNoSelectionPlaceholderBindingOption,
			NSNotApplicablePlaceholderBindingOption,
			NSNullPlaceholderBindingOption,
		};
		for (NSString *exposedBinding in exposedBindings)
		{
			NSDictionary *bindingInfo = [object infoForBinding:exposedBinding];
			if (bindingInfo) {
				id observedObject = [bindingInfo objectForKey:NSObservedObjectKey];
				NSString *path = [bindingInfo objectForKey:NSObservedKeyPathKey];
				NSDictionary *options = [bindingInfo objectForKey:NSOptionsKey];
				if (observedObject && path && options) {
					NSMutableDictionary *newOptions 
					= [NSMutableDictionary dictionaryWithDictionary:options];
					BOOL valueChanged = NO;
					for (size_t i = 0; 
						 i < sizeof(optionsToLocalize) / sizeof(optionsToLocalize[0]);
						 ++i) {
						NSString *key = optionsToLocalize[i];
						NSString *value = [newOptions objectForKey:key];
						if ([value isKindOfClass:[NSString class]]) {
							NSString *localizedValue = [self _localizedStringForString:value bundle:bundle table:table];
							if (localizedValue) {
								valueChanged = YES;
								[newOptions setObject:localizedValue forKey:key];
							}
						}
					}
					if (valueChanged) {
						// Only unbind and rebind if there is a change.
						[object unbind:exposedBinding];
						[object bind:exposedBinding 
							toObject:observedObject 
						 withKeyPath:path 
							 options:newOptions];
					}
				}
			}
		}
	}
	
	
}



+ (NSString *)_localizedStringForString:(NSString *)string bundle:(NSBundle *)bundle table:(NSString *)table;
{
    if (![string length])
        return nil;
    
	if ([string hasPrefix:@"["])
	{
		NSLog(@"??? Double-translation of %@", string);
	}
    static NSString *defaultValue = @"I AM THE DEFAULT VALUE";
    NSString *localizedString = [bundle localizedStringForKey:string value:defaultValue table:table];
    if (![localizedString isEqualToString:defaultValue]) {
        return [NSString stringWithFormat:@"[_%@_]", localizedString];
    } else { 
#ifdef DEBUG
 //       NSLog(@"        Can't find translation for string %@", string);
       //return [NSString stringWithFormat:@"[%@]", [string uppercaseString]];
       // return string;
		// Simulate all strings being 40% longer
		float len = [string length];
		float extra = ceilf(0.40 * len);
		extra = MIN(extra, 100);		// don't pad more than 100 chars
		NSString *insert = [@"____________________________________________________________________________________________________" substringToIndex:(int)extra];
		int halflen = len/2;
		return [NSString stringWithFormat:@"%@%@%@",
				[string substringToIndex:halflen],
				insert,
				[string substringFromIndex:halflen]];
#else
        return string;
#endif
    }
}


#define DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(blahName, capitalizedBlahName) \
+ (void)_localize ##capitalizedBlahName ##OfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table level:(NSUInteger)level; \
{ \
NSString *localizedBlah = [self _localizedStringForString:[object blahName] bundle:bundle table:table]; \
if (localizedBlah) \
[object set ##capitalizedBlahName:localizedBlah]; \
}

DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(title, Title)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(alternateTitle, AlternateTitle)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(stringValue, StringValue)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(placeholderString, PlaceholderString)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(toolTip, ToolTip)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(label, Label)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(paletteLabel, PaletteLabel)

@end
