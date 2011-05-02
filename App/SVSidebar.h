//
//  SVSidebar.h
//  Sandvox
//
//  Created by Mike on 29/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"

#import "SVGraphicContainer.h"


@class KTPage;
@class SVGraphic, SVHTMLContext;


@interface SVSidebar : NSManagedObject <SVGraphicContainer>

@property (nonatomic, retain) KTPage *page;

@property(nonatomic, retain) NSSet *pagelets;   // for sorting, use SVSidebarPageletsController
- (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error;


#pragma mark HTML
- (void)writePageletsHTML:(SVHTMLContext *)context;

@end


@interface SVSidebar (CoreDataGeneratedAccessors)
- (void)addPageletsObject:(SVGraphic *)value;
- (void)removePageletsObject:(SVGraphic *)value;
- (void)addPagelets:(NSSet *)value;
- (void)removePagelets:(NSSet *)value;

@end

