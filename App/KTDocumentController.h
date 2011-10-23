//
//  KTDocumentController.h
//  Marvel
//
//  Created by Terrence Talbot on 9/20/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "KSDocumentController.h"


@class KTDocument, SVDesignPickerController;


@interface KTDocumentController : KSDocumentController
{
	// New docs
	IBOutlet NSView			*oNewDocAccessoryView;
	IBOutlet NSPopUpButton	*oNewDocHomePageTypePopup;
  @private
    SVDesignPickerController *_designChooser;
}

// Returns an array of *errors* for docs that failed to open
- (NSArray *)reopenPreviouslyOpenedDocuments;

- (void)showDocumentPlaceholderWindowInitial:(BOOL)firstTimeSoReopenSavedDocuments;

@end
