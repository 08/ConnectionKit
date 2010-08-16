//
//  RSSBadgeDelegate.m
//  RSS Badge
//
//  Copyright 2006-2009 Karelia Software. All rights reserved.
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

#import "CollectionArchivePlugIn.h"


@implementation CollectionArchivePlugIn

#pragma mark -
#pragma mark Init

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	if (isNewObject)
	{
		// Try and connect to our parent collection
		KTPage *parent = (KTPage *)[self page];
		if ([parent isCollection])
		{
			[[self propertiesStorage] setValue:parent forKey:@"collection"];
			
			NSString *title = [NSString stringWithFormat:@"%@ %@",
														 [parent titleText],
														 LocalizedStringInThisBundle(@"Archive", @"Portion of pagelet title")];
			//[(KTPagelet *)[self delegateOwner] setTitleHTML:title];
		}
	}
	
	[[[self propertiesStorage] valueForKey:@"collection"] setCollectionGenerateArchives:YES];
}

#pragma mark -
#pragma mark Settings

/*	Changing collection means disabling archives on the old collection if necessary
 */
- (void)plugin:(id)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue
{
	if ([key isEqualToString:@"collection"])
	{
		// Turn off the old collection's archives if not needed
		BOOL enableArchives = NO;
		NSArray *archivePagelets = [[plugin managedObjectContext] pageletsWithPluginIdentifier:[[self bundle] bundleIdentifier]];
		NSEnumerator *pageletsEnumerator = [archivePagelets objectEnumerator];
		id aPagelet;    // was KTPagelet
		while (aPagelet = [pageletsEnumerator nextObject])
		{
			if ([[aPagelet valueForKey:@"collection"] isEqual:(KTPage *)oldValue])
			{
				enableArchives = YES;
				break;
			}
		}
		[(KTPage *)oldValue setCollectionGenerateArchives:enableArchives];
		
		// Enable archives on the new page.
		[(KTPage *)value setCollectionGenerateArchives:YES];
	}
}

@end
