//
//  SVURLPreviewViewController.h
//  Sandvox
//
//  Created by Mike on 15/01/2010.
//  Copyright 2010-11 Karelia Software. All rights reserved.
//

#import "KSWebViewController.h"


@class SVSiteItem;


@interface SVURLPreviewViewController : KSWebViewController
{
  @private
    SVSiteItem  *_siteItem;
	
	NSString *_metaDescription;
}

@property (copy) NSString *metaDescription;

@property(nonatomic, retain) SVSiteItem *siteItem;
- (NSURL *)URLToLoad;

@end
