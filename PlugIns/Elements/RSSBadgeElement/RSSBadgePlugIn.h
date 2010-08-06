//
//  RSSBadgePlugIn.h
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

#import <Cocoa/Cocoa.h>
#import "SandvoxPlugin.h"


typedef enum {
	RSSBadgeIconStyleNone = 0,
	RSSBadgeIconStyleStandardOrangeSmall = 1,
	RSSBadgeIconStyleStandardOrangeLarge = 2,
	RSSBadgeIconStyleStandardGraySmall = 3,
	RSSBadgeIconStyleStandardGrayLarge = 4,
	RSSBadgeIconStyleAppleRSS = 5,
	RSSBadgeIconStyleFlatXML = 6,
	RSSBadgeIconStyleFlatRSS = 7,
} RSSBadgeIconStyle;

typedef enum {
	RSSBadgeIconPositionLeft = 1,
	RSSBadgeIconPositionRight = 2,
} RSSBadgeIconPosition;


@interface RSSBadgePlugIn : SVPageletPlugIn
{
  @private
    id<SVPage> _collection;

    RSSBadgeIconStyle _iconStyle;
    RSSBadgeIconPosition _iconPosition;
	NSString *_label;
}


- (BOOL)useLargeIconLayout;
- (NSString *)feedIconResourcePath;

//FIXME: do we really want to retain this? what happens if you delete the page?
@property (nonatomic, retain) id<SVPage> collection;

@property (nonatomic, assign) RSSBadgeIconStyle iconStyle;
@property (nonatomic, assign) RSSBadgeIconPosition iconPosition;
@property (nonatomic, copy) NSString *label;

@end
