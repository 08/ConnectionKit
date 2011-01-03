//
//  KTExportSavePanelController.h
//  Marvel
//
//  Created by Mike on 15/12/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "KSViewController.h"


@interface KTExportSavePanelController : NSViewController
{
    IBOutlet NSTextField    *oSiteURLField;
    
  @private
    NSURL   *_documentURL;
}

- (id)initWithSiteURL:(NSURL *)URL documentURL:(NSURL *)docURL;
- (NSURL *)siteURL;

@end
