//
//  SVPageInspector.h
//  Sandvox
//
//  Created by Mike on 06/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"

#import "KTPage.h"


@class KTPlaceholderBindingTextField, SVSidebarPageletsController;


@interface SVPageInspector : KSInspectorViewController
{
    IBOutlet KTPlaceholderBindingTextField  *oMenuTitleField;
    
    IBOutlet NSPopUpButton  *oThumbnailPicker;
    
    IBOutlet NSButton *showTimestampCheckbox;
    
    IBOutlet SVSidebarPageletsController    *oSidebarPageletsController;
    IBOutlet NSTableView                    *oSidebarPageletsTable;
}

- (IBAction)selectTimestampType:(NSPopUpButton *)sender;

- (IBAction)chooseCustomThumbnail:(NSButton *)sender;
- (IBAction)pickThumbnailFromPage:(NSPopUpButton *)sender;
- (void)updatePickFromPageThumbnail;

- (IBAction)toggledArchives:(NSButton *)sender;

@end
