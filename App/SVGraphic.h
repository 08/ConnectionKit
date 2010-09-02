//
//  SVGraphic.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"
#import "SVPageletPlugIn.h"
#import <iMedia/iMedia.h>

#import "NSManagedObject+KTExtensions.h"    // for serialization


typedef enum {
    SVGraphicPlacementInline,
    SVGraphicPlacementCallout,
    SVGraphicPlacementSidebar,
} SVGraphicPlacement;

typedef enum {  // Note that "left" or "right" refers to the side of the graphic *text* will be placed
    SVGraphicWrapNone,
    SVGraphicWrapLeftSplit,
    SVGraphicWrapCenterSplit,
    SVGraphicWrapRightSplit,
    SVGraphicWrapLeft,
    SVGraphicWrapCenter,
    SVGraphicWrapRight,
} SVGraphicWrap;


#define SVContentObjectWrapNone [NSNumber numberWithInteger:SVGraphicWrapNone]
#define SVContentObjectWrapFloatLeft [NSNumber numberWithInteger:SVGraphicWrapLeft]
#define SVContentObjectWrapFloatRight [NSNumber numberWithInteger:SVGraphicWrapRight]
#define SVContentObjectWrapBlockLeft [NSNumber numberWithInteger:SVGraphicWrapLeftSplit]
#define SVContentObjectWrapBlockCenter [NSNumber numberWithInteger:SVGraphicWrapCenterSplit]
#define SVContentObjectWrapBlockRight [NSNumber numberWithInteger:SVGraphicWrapRightSplit]
//typedef NSNumber SVContentObjectWrap;
#define SVContentObjectWrap NSNumber


#pragma mark -


extern NSString *kSVGraphicPboardType;


//  Have decided to use the term "graphic" in the same way that Pages does through its scripting API (and probably in its class hierarchy). That is, a graphic is anything on the page that can be selected and isn't text. e.g. pagelets, images, plug-ins.

//  I'm declaring a protocol for graphics first to keep things nice and pure. (Also, it means I can make some things @optional so that Core Data will still generate accessors when the superclass chooses not to implement the method)

@protocol SVGraphic
- (NSString *)elementID;
@optional
@end


#pragma mark -


@class KTPage, SVTitleBox;
@class SVTextAttachment, SVHTMLContext, SVTemplate;
@class SVAuxiliaryPageletText;
@protocol SVPage, SVMedia;


@interface SVGraphic : KSExtensibleManagedObject <SVGraphic, SVPageletPlugInContainer, IMBImageItem>

#pragma mark Initialization
- (void)willInsertIntoPage:(KTPage *)page; // calls -didAddToPage:
- (void)didAddToPage:(id <SVPage>)page;


#pragma mark Placement
@property(nonatomic, readonly) NSNumber *placement; // SVGraphicPlacement
- (BOOL)isPlacementEditable;    // yes for sidebar & article embedded graphics


#pragma mark Pagelet

- (BOOL)displayInline;
- (BOOL)isPagelet;      // whether to generate <div class="pagelet"> etc. HTML. KVO-compliant


- (BOOL)canDisplayInline;   // NO for most graphics. Images and Raw HTML return YES
- (BOOL)mustBePagelet;  // convenience for -canDisplayInline

- (BOOL)isCallout;  // whether to generate enclosing <div class="callout"> etc.
- (NSString *)calloutWrapClassName; // nil if not a callout


#pragma mark Title
@property(nonatomic, retain) SVTitleBox *titleBox;
- (void)setTitle:(NSString *)title;   // creates Title object if needed
+ (NSString *)placeholderTitleText;


#pragma mark Intro & Caption

- (void)createDefaultIntroAndCaption;

@property (nonatomic, retain) SVAuxiliaryPageletText *introduction;
- (BOOL)canHaveIntroduction;

@property (nonatomic, retain) SVAuxiliaryPageletText *caption;
- (BOOL)canHaveCaption;


#pragma mark Layout/Styling
@property(nonatomic, copy) NSNumber *showBackground;
@property(nonatomic, getter=isBordered) BOOL bordered;
@property(nonatomic, copy) NSNumber *showBorder;


#pragma mark Placement

/*  There is generally no need to directly adjust a graphic's wrap setting. In particular, one hazard is that you could cause a block-level object appear inline. i.e. invalid HTML. Instead, use the higher-level DOM Controller API to modify wrap/placement of the selection.
 */

@property(nonatomic, retain) SVTextAttachment *textAttachment;


#pragma mark Metrics

@property(nonatomic, copy) NSNumber *width;
@property(nonatomic, copy) NSNumber *height;

@property(nonatomic, copy) NSNumber *contentWidth;

- (NSNumber *)containerWidth;


#pragma mark Sidebar

// Checks that a given set of pagelets have unique sort keys
+ (BOOL)validateSortKeyForPagelets:(NSSet **)pagelets error:(NSError **)error;

// Shouldn't really have any need to set this yourself. Use an SVSidebarPageletsController instead please.
@property(nonatomic, copy) NSNumber *sortKey;

@property(nonatomic, readonly) NSSet *sidebars;


#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context;  // Subclasses MUST override

@property(nonatomic, retain, readonly) NSString *elementID;
- (void)buildClassName:(SVHTMLContext *)context;
- (NSString *)inlineGraphicClassName;

+ (SVTemplate *)template;
   

#pragma mark Thumbnail
@property(nonatomic, readonly) id <SVMedia> thumbnail; // MUST be KVO-compliant
- (CGFloat)thumbnailAspectRatio;


#pragma mark Inspector
// To get yourself in the plug-in Inspector, need to:
//  1.  Implement -plugInIdentifier to return a unique value like a plug-in would
//  2.  Override +makeInspectorViewController to create and return a controller
+ (SVInspectorViewController *)makeInspectorViewController;
@property(nonatomic, retain, readonly) SVPlugIn *plugIn;


#pragma mark Serialization

- (void)writeToPasteboard:(NSPasteboard *)pboard;   // like other Cocoa methods of same sig.

+ (NSArray *)graphicsFromPasteboard:(NSPasteboard *)pasteboard
     insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

+ (id)graphicWithSerializedProperties:(id)properties
       insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

@end


