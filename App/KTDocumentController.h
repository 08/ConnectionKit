//
//  KTDocumentController.h
//  Marvel
//
//  Created by Terrence Talbot on 9/20/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KTDocument;


@interface KTDocumentController : NSDocumentController
{
	// New docs
	IBOutlet NSView			*oNewDocAccessoryView;
	IBOutlet NSPopUpButton	*oNewDocHomePageTypePopup;
	
    @private
	NSMutableArray *myDocumentsAwaitingBackup;
    
    KTDocument *myLastSavedDocumentWeakRef;
}

- (IBAction)showDocumentPlaceholderWindow:(id)sender;

@end
