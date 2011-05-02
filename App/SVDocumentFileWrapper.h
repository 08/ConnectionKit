//
//  SVDocumentFileWrapper.h
//  Sandvox
//
//  Created by Mike on 16/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol SVDocumentFileWrapper <NSObject>

- (NSURL *)fileURL;
- (void)forceUpdateFromURL:(NSURL *)URL;
- (NSString *)preferredFilename;
- (NSString *)filename;

- (BOOL)shouldRemoveFromDocument;   // will be moved or deleted depending on undo manager
- (BOOL)isDeletedFromDocument;
@end
