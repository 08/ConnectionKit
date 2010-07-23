//
//  SVBannerPickerController.h
//  Sandvox
//
//  Created by Mike on 23/07/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KSInspectorViewController;


@interface SVBannerPickerController : NSObject
{
    IBOutlet KSInspectorViewController  *oInspectorViewController;
    IBOutlet NSPopUpButton              *oPopUpButton;
    
  @private
    NSNumber    *_bannerType;
}

@property(nonatomic, copy) NSNumber *bannerType;    // bindable
- (IBAction)bannerTypeChosen:(NSPopUpButton *)sender;

- (IBAction)chooseBanner:(id)sender;
- (BOOL)chooseBanner;

@end
