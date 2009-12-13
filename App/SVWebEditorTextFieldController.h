//
//  SVWebEditorTextFieldController.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Like NSTextField before it, SVWebEditorTextFieldController takes SVWebEditorTextController and applies it to small chunks of text in the DOM. You can even use NSValueBinding just like a text field. Also, SVWebEditorTextFieldController is designed to be a selectable web editor item, much like how Keynote operates.


#import "SVWebEditorTextController.h"


@interface SVWebEditorTextFieldController : SVWebEditorTextController
{
  @private
    NSString    *_placeholder;
    
    // Bindings
    NSString        *_uneditedValue;
    BOOL            _isCommittingEditing;
    
    // Undo
    NSManagedObjectContext  *_moc;
}

@property(nonatomic, copy) NSString *placeholderString;

@property(nonatomic, retain) NSManagedObjectContext *managedObjectContext;

@end
