//
//  WebViewEditingHelperClasses.m
//  Marvel
//
//  Created by Mike on 23/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "WebViewEditingHelperClasses.h"

#import "Debug.h"
#import "NSString+Karelia.h"


@implementation StrikeThroughOn

- (NSDictionary *)convertAttributes:(NSDictionary *)attributes
{
	NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:attributes];
	[newDict setObject:[NSNumber numberWithInt:1] forKey:NSStrikethroughStyleAttributeName];
	return newDict;
}

@end

@implementation StrikeThroughOff

- (NSDictionary *)convertAttributes:(NSDictionary *)attributes
{
	NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:attributes];
	[newDict removeObjectForKey:NSStrikethroughStyleAttributeName];
	return newDict;
}

@end

@implementation TypewriterOn

- (NSDictionary *)convertAttributes:(NSDictionary *)attributes
{
	NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:attributes];
	[newDict setObject:[NSFont userFixedPitchFontOfSize:-1] forKey:NSFontAttributeName];
	return newDict;
}

@end

@implementation TypewriterOff

- (NSDictionary *)convertAttributes:(NSDictionary *)attributes
{
	NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:attributes];
	[newDict setObject:[NSFont userFontOfSize:-1] forKey:NSFontAttributeName];
	// HACK -- just turn into a non-typewriter font.	Should get fixed automatically by the font stripper?
	return newDict;
}

@end

@implementation EditableNodeFilter

+ (EditableNodeFilter *)sharedFilter
{
	static EditableNodeFilter *sSharedEditableNodeFilter;
	
	if (!sSharedEditableNodeFilter)
		sSharedEditableNodeFilter = [[EditableNodeFilter alloc] init];
	return sSharedEditableNodeFilter;
}

- (short)acceptNode:(DOMNode *)node
{
	short result = DOM_FILTER_SKIP;

	DOMHTMLElement *element = ((DOMHTMLElement *)node);
	if( [[element idName] hasPrefix:@"k-"])
	{
		NSString *classes = [element className];
		if ( (	(NSNotFound != [classes rangeOfString:@"kBlock"].location)
				||	(NSNotFound != [classes rangeOfString:@"kLine"].location) )
			 && (NSNotFound == [classes rangeOfString:@"kHtml"].location)	// no direct editing of raw HTML
			 && (NSNotFound == [classes rangeOfString:@"kAnchor"].location)	// anchor means it's a <a> so go there to edit it
			 
			 
			 /*
			  if ([self hasChildren]
				  &&
				  KTSummarizeAutomatic != (summaryType = [[self valueForKey:@"collectionSummaryType"] intValue]))
			  */
			 
			 )
		{
			result = DOM_FILTER_ACCEPT;
		}
	OFF((@"? acceptNode:%@ --> %d", [[element outerHTML] condenseWhiteSpace], result));
	}
//#ifdef DEBUG
//	if (result == DOM_FILTER_ACCEPT)
//	{
//		NSLog(@"Accepted %@", [[node outerHTML] condenseWhiteSpace]);
//	}
//#endif
	return result;
}

@end

