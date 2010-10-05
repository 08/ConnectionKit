//
//  SVGraphicFactory.h
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Like NSFontManager, but for pagelets. (In the sense of the contents of "Insert > Pagelet >" menu)


#import <Cocoa/Cocoa.h>
#import "SVGraphic.h"

#import "SVPlugIn.h"


/*  NSPasteboardReadingOptions specify how data is read from the pasteboard.  You can specify only one option from this list.  If you do not specify an option, the default NSPasteboardReadingAsData is used.  The first three options specify how and if pasteboard data should be pre-processed by the pasteboard before being passed to -initWithPasteboardPropertyList:ofType.  The fourth option, NSPasteboardReadingAsKeyedArchive, should be used when the data on the pasteboard is a keyed archive of this class.  Using this option, a keyed unarchiver will be used and -initWithCoder: will be called to initialize the new instance. 
 */
enum {
    SVPlugInPasteboardReadingAsData 		= 0,	  // Reads data from the pasteboard as-is and returns it as an NSData
    SVPlugInPasteboardReadingAsString 	= 1 << 0, // Reads data from the pasteboard and converts it to an NSString
    SVPlugInPasteboardReadingAsPropertyList 	= 1 << 1, // Reads data from the pasteboard and un-serializes it as a property list
                                                          //SVPlugInPasteboardReadingAsKeyedArchive 	= 1 << 2, // Reads data from the pasteboard and uses initWithCoder: to create the object
    SVPlugInPasteboardReadingAsWebLocation = 1 << 31,
};
typedef NSUInteger SVPlugInPasteboardReadingOptions;


@class KSWebLocation;


@interface SVGraphicFactory : NSObject

#pragma mark Registration
+ (NSArray *)registeredFactories;
+ (void)registerFactory:(SVGraphicFactory *)factory;


#pragma mark Shared Objects
+ (SVGraphicFactory *)textBoxFactory;
+ (NSArray *)mediaFactories;
+ (SVGraphicFactory *)mediaPlaceholderFactory;
+ (SVGraphicFactory *)videoFactory;
+ (SVGraphicFactory *)audioFactory;
+ (SVGraphicFactory *)flashFactory;
+ (NSArray *)indexFactories;
+ (NSArray *)badgeFactories;
+ (NSArray *)embeddedFactories;
+ (NSArray *)socialFactories;
+ (NSArray *)moreGraphicFactories;
+ (SVGraphicFactory *)rawHTMLFactory;


#pragma mark General

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;

- (NSString *)name;
- (NSImage *)icon;
- (NSUInteger)priority; // 0-9, where 9 is Pro status

- (BOOL)isIndex;

// Plug-ins
@property(nonatomic, retain, readonly) NSString *identifier;
@property(nonatomic, retain, readonly) Class plugInClass;


#pragma mark Pasteboard

- (NSUInteger)priorityForAwakingFromWebLocation:(KSWebLocation *)locations;

- (SVGraphic *)graphicWithPasteboardContents:(id)contents
                                      ofType:(NSString *)type
              insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

// Convenience for extracting data from pboard
+ (id)contentsOfPasteboard:(NSPasteboard *)pasteboard forType:(NSString *)type forFactory:(SVGraphicFactory *)aFactory;


#pragma mark Menus

+ (void)insertItemsWithGraphicFactories:(NSArray *)factories
                                 inMenu:(NSMenu *)menu
                                atIndex:(NSUInteger)index;

- (NSMenuItem *)makeMenuItem;
+ (NSMenuItem *)menuItemWithGraphicFactories:(NSArray *)factories title:(NSString *)title;

// Convenience method that uses the factory if non-nil. Otherwise, fall back to text box
+ (SVGraphic *)graphicWithActionSender:(id <NSValidatedUserInterfaceItem>)sender
        insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

+ (SVGraphicFactory *)factoryWithIdentifier:(NSString *)identifier;


#pragma mark Pasteboard

+ (NSArray *)graphicsFromPasteboard:(NSPasteboard *)pasteboard
    insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

+ (NSArray *)graphicPasteboardTypes;


@end
