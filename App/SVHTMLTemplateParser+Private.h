//
//  SVHTMLTemplateParser+Private.h
//  Marvel
//
//  Created by Mike on 19/02/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVHTMLTemplateParser.h"


@interface SVHTMLTemplateParser ()

- (NSString *)resourceFilePath:(NSURL *)resourceFile relativeToPage:(KTPage *)page;

// Delegate
- (void)didParseTextBlock:(SVHTMLTextBlock *)textBlock;
- (void)didEncounterMediaFile:(id <SVMedia>)mediaFile upload:(KTMediaFileUpload *)upload;
- (void)didEncounterResourceFile:(NSURL *)resourceURL;

@end
