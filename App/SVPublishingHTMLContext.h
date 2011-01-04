//
//  SVPublishingHTMLContext.h
//  Sandvox
//
//  Created by Mike on 08/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"


@class SVMediaRequest;
@protocol SVPublisher;

@interface SVPublishingHTMLContext : SVHTMLContext
{
  @private
    id <SVPublisher>    _publisher;
    NSString            *_path;
}

- (id)initWithUploadPath:(NSString *)path
               publisher:(id <SVPublisher>)publisher;

- (NSURL *)addMediaWithRequest:(SVMediaRequest *)request;

@end
