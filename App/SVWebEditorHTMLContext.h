//
//  SVWebEditorHTMLContext.h
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"

#import "SVGraphicDOMController.h"


@class SVWebEditorViewController, SVContentDOMController, SVSidebarDOMController;
@class SVContentObject, SVRichText, SVSidebar, SVSidebarPageletsController;
@class SVMediaRecord;


@interface SVWebEditorHTMLContext : SVHTMLContext
{
  @private
    SVContentDOMController  *_rootController;
    SVDOMController         *_currentDOMController;  // weak ref
    NSIndexPath             *_DOMControllerPoints;
        
    NSMutableSet    *_media;
    
    SVSidebarDOMController      *_sidebarDOMController;
    SVSidebarPageletsController *_sidebarPageletsController;
}

#pragma mark Root
@property(nonatomic, retain, readonly) SVContentDOMController *rootDOMController;
- (void)addDOMController:(SVDOMController *)controller; // adds to the current controller


#pragma mark Media
- (NSSet *)media;


#pragma mark Sidebar
@property(nonatomic, retain) SVSidebarPageletsController *sidebarPageletsController;


@end


#pragma mark -


@interface SVHTMLContext (SVEditing)

#pragma mark Sidebar

- (void)startSidebar:(SVSidebar *)sidebar; // call -endElement after writing contents

// The context may provide its own controller for sidebar pagelets (pre-sorted etc.) If so, please use it.
- (SVSidebarPageletsController *)cachedSidebarPageletsController;


#pragma mark Current Item
- (SVDOMController *)currentDOMController;


@end


#pragma mark -


@interface SVDOMController (SVWebEditorHTMLContext)
- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
@end

