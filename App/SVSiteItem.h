//
//  SVSiteItem.h
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Everything you see in the Site Outline should be a subclass of SVSiteItem. It:
//  -   Holds a reference to the parent page.
//  -   Returns NSNotApplicableMarker instead of throwing an exception for unknown keys


#import "KSExtensibleManagedObject.h"
#import "SVPageProtocol.h"
#import "SVPublisher.h"

#import <iMedia/IMBImageItem.h>


@class KTSite, KTMaster, KTPage, KTCodeInjection, SVExternalLink, SVMediaRecord, SVHTMLContext;
@protocol SVWebContentViewController, SVMedia;


@interface SVSiteItem : KSExtensibleManagedObject <SVPage, SVPublishedObject>

#pragma mark Identifier
@property(nonatomic, copy, readonly) NSString *uniqueID;
+ (KTPage *)siteItemForPreviewPath:(NSString *)path inManagedObjectContext:(NSManagedObjectContext *)context;


#pragma mark Title
@property(nonatomic, copy) NSString *title; // implemented as @dynamic


#pragma mark Dates
@property(nonatomic, copy) NSDate *creationDate;
@property(nonatomic, copy) NSDate *modificationDate;


#pragma mark Navigation

@property(nonatomic, copy) NSNumber *includeInSiteMenu; // setting in GUI
- (BOOL)shouldIncludeInSiteMenu;    // takes into account draft status etc.

@property(nonatomic, copy, readonly) NSString *menuTitle;   // derived from .customMenuTitle or .title
@property(nonatomic, copy) NSString *customMenuTitle;

@property(nonatomic, copy) NSNumber *includeInSiteMap;    // BOOL, mandatory
@property(nonatomic, retain) NSNumber *openInNewWindow; // BOOL, mandatory


#pragma mark Drafts and Indexes

@property(nonatomic, copy) NSNumber *isDraft;
- (BOOL)isDraftOrHasDraftAncestor;
- (void)setPageOrParentDraft:(BOOL)inDraft;
- (BOOL)excludedFromSiteMap;

@property(nonatomic, copy) NSNumber *isPublishableInDemo;    // BOOL, mandatory

@property(nonatomic, copy) NSNumber *includeInIndex;


#pragma mark URL

@property(nonatomic, copy, readonly) NSURL *URL;    // nil by default, for subclasses to override
@property(nonatomic, copy, readonly) NSString *fileName;    // nil by default, for subclasses to override

- (NSString *)previewPath;


#pragma mark Editing
- (KTPage *)pageRepresentation; // default returns nil. KTPage returns self so Web Editor View Controller can handle
- (SVExternalLink *)externalLinkRepresentation;	// default returns nil. used to determine if it's an external link, for page details.
- (id <SVMedia>)mediaRepresentation;

- (BOOL) canPreview;

#pragma mark Publishing
@property(nonatomic, copy) NSDate *datePublished;
- (void)recursivelyInvalidateURL:(BOOL)recursive;


#pragma mark Site
@property(nonatomic, retain) KTSite *site;
- (void)setSite:(KTSite *)site recursively:(BOOL)recursive;
@property(nonatomic, retain) KTMaster *master;


#pragma mark Tree

@property(nonatomic, copy, readonly) NSSet *childItems;
- (NSArray *)sortedChildren;

//  .parentPage is marked as optional in the xcdatamodel file so subentities can choose their own rules. SVSiteItem programmatically makes .parentPage required. Override -validateParentPage:error: in a subclass to turn this off again.
@property(nonatomic, retain) KTPage *parentPage;
- (BOOL)validateParentPage:(KTPage **)page error:(NSError **)outError;

- (KTPage *)rootPage;   // searches up the tree till it finds a page with no parent

- (BOOL)isDescendantOfCollection:(KTPage *)collection;
- (BOOL)isDescendantOfItem:(SVSiteItem *)aPotentialAncestor;

// Don't bother setting this manually, get KTPage or controller to do it
@property(nonatomic) short childIndex;


#pragma mark Contents
- (void)publish:(id <SVPublisher>)publishingEngine recursively:(BOOL)recursive;
// writes to the current HTML context. Ignore things like site title
- (void)writeContent:(SVHTMLContext *)context recursively:(BOOL)recursive;


#pragma mark Thumbnail
@property(nonatomic, readonly) id <IMBImageItem> thumbnail;
@property(nonatomic, copy) NSNumber *thumbnailType; // 0 for automatic, 1 for custom, 2 to Pick from Page
@property(nonatomic, retain) SVMediaRecord *customThumbnail;


#pragma mark UI

@property(nonatomic, readonly) BOOL isCollection;

- (KTCodeInjection *)codeInjection;

- (NSString *)baseExampleURLString;

- (BOOL)isRoot;
@end




