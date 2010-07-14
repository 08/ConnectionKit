//
//  SVWebEditorLoadingPlaceholderViewController.h
//  Sandvox
//
//  Created by Mike on 04/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <BWToolkitFramework/BWToolkitFramework.h>


@interface SVLoadingPlaceholderViewController : BWViewController
{
    IBOutlet NSImageView    *oBackgroundImageView;
    
  @private
    NSProgressIndicator *_progressIndicator;
    NSTextField         *_label;
}

- (id)init;

@property(nonatomic, retain) IBOutlet NSProgressIndicator *progressIndicator;
@property(nonatomic, retain) IBOutlet NSTextField *label;   // can use to set custom text

@end
