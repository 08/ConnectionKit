//
//  SVDesignChooserImageBrowserView.m
//  Sandvox
//
//  Created by Dan Wood on 12/8/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDesignChooserImageBrowserView.h"
#import "SVDesignChooserImageBrowserCell.h"
#import "SVDesignChooserViewController.h"
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
#else
#import "DumpedImageKit.h"
#endif


@interface NSObject (privateAPIOhNo)
- (NSRange) range;
- (BOOL) expanded;
@end


@implementation SVDesignChooserImageBrowserView


- (void) setSelectionIndexes:(NSIndexSet *) indexes byExtendingSelection:(BOOL) extendSelection;
{
	[super setSelectionIndexes:indexes byExtendingSelection:extendSelection];
}
// If the IKImageBrowserView asked for a custom cell class, then pass on the request to the library's delegate. 
// That way the application is given a chance to customize the look of the browser...

- (Class) _cellClass
{
	return [SVDesignChooserImageBrowserCell class];
}

- (void)_expandButtonClicked:(NSDictionary *)dict;
{
	[super _expandButtonClicked:dict];
	NSEvent *event = [dict objectForKey:@"event"];
	if ([event type] == NSLeftMouseUp)
	{
		NSDictionary *info = [dict objectForKey:@"info"];
		NSObject *IKImageBrowserGridGroup = [info objectForKey:@"group"];
		if ([IKImageBrowserGridGroup respondsToSelector:@selector(range)] && [IKImageBrowserGridGroup respondsToSelector:@selector(expanded)])
		{
			NSRange range = [IKImageBrowserGridGroup range];
			BOOL expanded = [IKImageBrowserGridGroup expanded];			
			[self.dataSource setContracted:!expanded forRange:range];
		}
	}
}

- (void) awakeFromNib
{
	_cellClass = [self _cellClass];
	
	if ([self respondsToSelector:@selector(setCellClass:)])
	{
		[self performSelector:@selector(setCellClass:) withObject:_cellClass];
	}
	
	[self setAllowsEmptySelection:NO];	// doesn't seem to stick when set in IB
	
	//	[self setValue:attributes forKey:IKImageBrowserCellsHighlightedTitleAttributesKey];	
	//	[self setCellSize:NSMakeSize(44.0,22.0)];
	if ([self respondsToSelector:@selector(setIntercellSpacing:)])
	{
		[self setIntercellSpacing:NSMakeSize(0.0,10.0)];	// try to get as close as possible.  don't need a subclass for just this, right?
	}
	[self setCellsStyleMask:IKCellsStyleShadowed|IKCellsStyleTitled|IKCellsStyleSubtitled];
	[self setConstrainsToOriginalSize:YES];	// Nothing seems to happen here
	[self setCellSize:NSMakeSize(120,100)];	// a bit wider to allow for 4 columns.  EMPIRICAL - not too small to shrink, not to big to allow > 100x65 sizes
}


// This method is for 10.6 only. Create and return a cell. Please note that we must not autorelease here!

- (IKImageBrowserCell*) newCellForRepresentedItem:(id)inCell
{
	return [[_cellClass alloc] init];
}

- (void)keyDown:(NSEvent *)theEvent
{
	if (53 == [theEvent keyCode])		// escape -- doesn't seeem to be a constant for this.
	{
		[NSApp sendAction:@selector(cancelSheet:) to:nil from:self];
	}
	else
	{
		[super keyDown:theEvent];
	}
}


@end
