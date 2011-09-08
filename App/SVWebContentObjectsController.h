//
//  SVWebContentObjectsController.h
//  Sandvox
//
//  Created by Mike on 06/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

//  Controller for all the selectable objects you see in the Web Editor. Customises NSArrayController to have the correct object removal behaviour.


#import "KSArrayController.h"


@class KTPage, SVGraphic, SVSidebarPageletsController;


@interface SVWebContentObjectsController : KSArrayController
{
  @private
    KTPage                      *_page;
    SVSidebarPageletsController *_sidebarPageletsController;
}

// More specialised than -newObject
- (BOOL)sidebarPageletAppearsOnAncestorPage:(SVGraphic *)pagelet;

// Provides extra contextual information on top of -managedObjectContext
@property(nonatomic, retain) KTPage *page;


- (BOOL)setSelectedObjects:(NSArray *)objects insertIfNeeded:(BOOL)insertIfNeeded;


#pragma mark  SPI
@property(nonatomic, retain, readonly) SVSidebarPageletsController *sidebarPageletsController;

@end