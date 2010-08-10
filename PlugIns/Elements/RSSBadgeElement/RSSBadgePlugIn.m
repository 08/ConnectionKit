//
//  RSSBadgePlugIn.m
//  RSSBadgeElement
//
//  Copyright 2006-2010 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "RSSBadgePlugIn.h"


// LocalizedStringInThisBundle(@"Please use the Inspector to connect this pagelet to a suitable collection in your site.", "RSSBadge")
// LocalizedStringInThisBundle(@"To subscribe to this feed, drag or copy/paste this link to an RSS reader application.", @"RSS Badge")
// LocalizedStringInThisBundle(@"The chosen collection has no RSS feed. Please use the Inspector to set it to generate an RSS feed.", @"RSS Badge")


@implementation RSSBadgePlugIn


#pragma mark -
#pragma mark SVPlugin

+ (NSArray *)plugInKeys
{ 
    NSArray *plugInKeys = [NSArray arrayWithObjects:
            @"iconPosition", 
            @"iconStyle", 
            @"label", 
            nil];
    
    return [[super plugInKeys] arrayByAddingObjectsFromArray:plugInKeys];
}


#pragma mark -
#pragma mark Initialization

- (void)didAddToPage:(id <SVPage>)page;
{
    [super didAddToPage:page];
    
    if ( !self.label )
    {
        // Use an appropriately localized label
        //
        // Make the string we want get generated, but we are forcing the string to be in target language.
        //
        NSBundle *theBundle = [NSBundle bundleForClass:[self class]];
        NSString *language = [page language];   OBASSERT(language);
        NSString *theString = [theBundle localizedStringForString:@"Subscribe to RSS feed" 
                                                         language:language
                                                         fallback:LocalizedStringInThisBundle(@"Subscribe to RSS feed", 
                                                                                              @"Prompt to subscribe to the given collection via RSS")];
        self.label = theString;
    }
    
    // Try and connect to our parent collection
    id<SVPage> parent = page;
    if (!self.indexedCollection && [parent feedURL])
    {
        self.indexedCollection = parent;
    }
}


#pragma mark -
#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    [super writeHTML:context];
    
    // add dependencies
    [context addDependencyForKeyPath:@"iconStyle" ofObject:self];
    [context addDependencyForKeyPath:@"iconPosition" ofObject:self];
    [context addDependencyForKeyPath:@"label" ofObject:self];

    // add resources
    NSString *path = [self feedIconResourcePath];
	if (path && ![path isEqualToString:@""]) 
    {
        NSURL *feedIconURL = [NSURL fileURLWithPath:path];
        [context addResourceWithURL:feedIconURL];
    }
}

- (BOOL)useLargeIconLayout
{
	// Use the large icon layout if the large orange or grey feed icon has been chosen
	RSSBadgeIconStyle iconStyle = self.iconStyle;
	BOOL result = (iconStyle == RSSBadgeIconStyleStandardOrangeLarge 
                   || iconStyle == RSSBadgeIconStyleStandardGrayLarge);
	return result;
}


#pragma mark -
#pragma mark Resources

- (NSString *)feedIconResourcePath
{
	// The path to the RSS feed icon
	NSString *iconName = nil;
	
	switch ( self.iconStyle )
	{
		case RSSBadgeIconStyleStandardOrangeSmall:
			iconName = @"orange_small.png";
			break;
		case RSSBadgeIconStyleStandardOrangeLarge:
			iconName = @"orange_large.png";
			break;
		case RSSBadgeIconStyleStandardGraySmall:
			iconName = @"gray_small.png";
			break;
		case RSSBadgeIconStyleStandardGrayLarge:
			iconName = @"gray_large.png";
			break;
		case RSSBadgeIconStyleAppleRSS:
			iconName = @"rss_blue.png";
			break;
		case RSSBadgeIconStyleFlatXML:
			iconName = @"xml.gif";
			break;
		case RSSBadgeIconStyleFlatRSS:
			iconName = @"rss.gif";
			break;
        case RSSBadgeIconStyleNone:
        default:
            break;
	}
	
	NSString *path = [[self bundle] pathForImageResource:iconName];
	return path;
}


#pragma mark -
#pragma mark Properties

@synthesize iconStyle = _iconStyle;
@synthesize iconPosition = _iconPosition;
@synthesize label = _label;

@end
