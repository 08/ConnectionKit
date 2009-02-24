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

#import "KTDocumentControllerChain.h"


extern NSString *KTDocumentDidChangeNotification;
extern NSString *KTDocumentWillCloseNotification;


extern NSString *KTDocumentWillSaveNotification;


@class KTSite, KTMediaManager, KTLocalPublishingEngine;
@class KTDocWindowController, KTHTMLInspectorController;
@class KTAbstractElement, KTPage, KTElementPlugin;


@interface KTDocument : NSDocument //<KTDocumentControllerChain>
{
@private
	
	// Standard document behaviour additions
    BOOL        _closing;
    NSThread    *_thread;
	
    
    // KT
    NSManagedObjectContext	*_managedObjectContext;
	KTSite                  *_site;                   // accessor in category method
	
	KTMediaManager				*myMediaManager;
		
	KTDocWindowController		*_mainWindowController;
	KTHTMLInspectorController	*myHTMLInspectorController;
	
	
	// UI
	BOOL	myShowDesigns;						// accessor in category method
	BOOL	myDisplaySiteOutline;				// accessor in category method
	BOOL	myDisplaySmallPageIcons;			// accessor in category method
	BOOL	myDisplayStatusBar;					// accessor in category method
	BOOL	myDisplayEditingControls;			// accessor in category method
//	short	mySiteOutlineSize;
	BOOL	myDisplayCodeInjectionWarnings;		// accessor in category method
    
    
    // Saving
    unsigned            mySaveOperationCount;
    NSSaveOperationType myLastSavePanelSaveOperation;
    
    WebView             *_quickLookThumbnailWebView;
    NSLock              *_quickLookThumbnailLock;
}


// Init
- (id)initWithType:(NSString *)type rootPlugin:(KTElementPlugin *)plugin error:(NSError **)error;


// Managing the Persistence Objects
+ (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url
                                           ofType:(NSString *)fileType
                               modelConfiguration:(NSString *)configuration
                                     storeOptions:(NSDictionary *)storeOptions
                                            error:(NSError **)error;

- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType;


// Document URLs etc.
+ (NSURL *)datastoreURLForDocumentURL:(NSURL *)inURL type:(NSString *)documentUTI;
+ (NSURL *)siteURLForDocumentURL:(NSURL *)inURL;
+ (NSURL *)quickLookURLForDocumentURL:(NSURL *)inURL;
- (NSString *)siteDirectoryPath;


- (IBAction)setupHost:(id)sender;

// Controller chain
- (KTDocWindowController *)mainWindowController;

- (BOOL)isClosing;

- (IBAction)editRawHTMLInSelectedBlock:(id)sender;

// Editing

- (void)addScreenshotsToAttachments:(NSMutableArray *)attachments attachmentOwner:(NSString *)attachmentOwner;
- (BOOL)mayAddScreenshotsToAttachments;

- (void)editSourceObject:(NSObject *)aSourceObject keyPath:(NSString *)aKeyPath  isRawHTML:(BOOL)isRawHTML;

@end


@interface KTDocument (Properties)

- (KTMediaManager *)mediaManager;

- (NSThread *)thread;
- (void)setThread:(NSThread *)thread;

// support

// these are really for properties stored in defaults
- (id)wrappedInheritedValueForKey:(NSString *)aKey;
//- (void)setWrappedInheritedValue:(id)aValue forKey:(NSString *)aKey;

- (KTSite *)site;

- (KTHTMLInspectorController *)HTMLInspectorController;
- (KTHTMLInspectorController *)HTMLInspectorControllerWithoutLoading;
- (void)setHTMLInspectorController:(KTHTMLInspectorController *)aController;

- (BOOL)showDesigns;
- (void)setShowDesigns:(BOOL)value;

// Display properties
- (BOOL)displayEditingControls;
- (void)setDisplayEditingControls:(BOOL)value;

- (BOOL)displaySiteOutline;
- (void)setDisplaySiteOutline:(BOOL)value;

- (BOOL)displayStatusBar;
- (void)setDisplayStatusBar:(BOOL)value;

- (BOOL)displaySmallPageIcons;
- (void)setDisplaySmallPageIcons:(BOOL)value;

@end


@interface KTDocument (Saving)

- (BOOL)isSaving;

@end

