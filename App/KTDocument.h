//
//  KTDocument.h
//  Sandvox
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


extern NSString *kKTDocumentDidChangeNotification;
extern NSString *kKTDocumentWillCloseNotification;


extern NSString *kKTDocumentWillSaveNotification;


@class KTSite;
@class KTDocWindowController, SVDocumentSavePanelAccessoryViewController;
@class KTElementPlugInWrapper;
@protocol SVDocumentFileWrapper;


@interface KTDocument : NSDocument
{
  @private
	
	// Standard document behaviour additions
    NSThread    *_thread;
	
    
    // KT
    NSManagedObjectContext	*_managedObjectContext;
	NSPersistentStore       *_store;
    KTSite                  *_site;                   // accessor in category method
	
	//KTMediaManager				*_mediaManager;
		
	
	
	// UI
	BOOL	myDisplaySmallPageIcons;			// accessor in category method
//	short	mySiteOutlineSize;
	BOOL	myDisplayCodeInjectionWarnings;		// accessor in category method
    
    
    // Saving
    unsigned                                    mySaveOperationCount;
    SVDocumentSavePanelAccessoryViewController  *_accessoryViewController;
    
    NSMutableDictionary *_filenameReservations;
    NSString            *_deletedMediaDirectoryName;
    
    WebView             *_quickLookThumbnailWebView;
    NSWindow            *_quickLookThumbnailWebViewWindow;
    NSLock              *_quickLookThumbnailLock;
	
    // Publishing
	NSURL *_lastExportDirectory;

}

@property (retain) NSURL *lastExportDirectory;


#pragma mark Managing the Persistence Objects
+ (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url
                                           ofType:(NSString *)fileType
                               modelConfiguration:(NSString *)configuration
                                     storeOptions:(NSDictionary *)storeOptions
                                            error:(NSError **)error;

- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType;

@property(nonatomic, retain) NSPersistentStore *persistentStore;


#pragma mark Reading
- (void)didReadContentsForURL:(NSURL *)URL;


#pragma mark Media

@property(nonatomic, copy, readonly) NSDictionary *documentFileWrappers;    // case-sensitive dictionary
- (BOOL)isFilenameAvailable:(NSString *)filename;
- (NSString *)keyForDocumentFileWrapper:(id <SVDocumentFileWrapper>)wrapper;

- (NSString *)addDocumentFileWrapper:(id <SVDocumentFileWrapper>)wrapper; // returns the filename reserved
- (void)setDocumentFileWrapper:(id <SVDocumentFileWrapper>)wrapper forKey:(NSString *)key;
- (void)unreserveFilename:(NSString *)filename;

- (void)designDidChange;

- (NSSet *)missingMedia;


#pragma mark Actions
- (IBAction)setupHost:(id)sender;


#pragma mark UI
- (NSOpenPanel *)makeChooseDialog;


#pragma mark Editing

- (void)addScreenshotsToAttachments:(NSMutableArray *)attachments attachmentOwner:(NSString *)attachmentOwner;
- (BOOL)mayAddScreenshotsToAttachments;

- (void)editSourceObject:(NSObject *)aSourceObject keyPath:(NSString *)aKeyPath  isRawHTML:(BOOL)isRawHTML;

@end


#pragma mark -


@interface KTDocument (Properties)

//- (KTMediaManager *)mediaManager;

- (NSThread *)thread;
- (void)setThread:(NSThread *)thread;

// support

// these are really for properties stored in defaults
- (id)wrappedInheritedValueForKey:(NSString *)aKey;
//- (void)setWrappedInheritedValue:(id)aValue forKey:(NSString *)aKey;

@property(nonatomic, retain) KTSite *site;

// Display properties

- (BOOL)displaySmallPageIcons;
- (void)setDisplaySmallPageIcons:(BOOL)value;

@end


#pragma mark -


@interface KTDocument (Saving)

- (BOOL)isSaving;


@end


#pragma mark -


// Default implementation does nothing, so implement in subclasses to take action, such as passing the message on to other controllers
@interface NSWindowController (KTDocumentAdditions)
- (void)persistUIProperties;
@end

@interface NSDocument (DatastoreAdditions)
+ (NSURL *)datastoreURLForDocumentURL:(NSURL *)inURL type:(NSString *)documentUTI;
+ (NSURL *)documentURLForDatastoreURL:(NSURL *)datastoreURL;

+ (NSURL *)quickLookURLForDocumentURL:(NSURL *)inURL;
@end

