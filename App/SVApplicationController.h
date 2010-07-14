//
//  KTAppDelegate.h
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

#import "Registration.h"
#import <Cocoa/Cocoa.h>
#import "KSLicensedAppDelegate.h"
#import "KSPluginInstallerController.h"


extern BOOL gWantToCatchSystemExceptions;


extern NSString *kSVLiveDataFeedsKey;
extern NSString *kLiveEditableAndSelectableLinksDefaultsKey;

extern NSString *kSVPrefersPNGImageFormatKey;
extern NSString *kSVPreferredImageCompressionFactorKey;


enum { KTNoBackupOnOpening = 0, KTBackupOnOpening, KTSnapshotOnOpening }; // tags for IB


@class KTDocument, KSProgressPanel;

@interface SVApplicationController : KSLicensedAppDelegate
{
    // IBOutlets
    IBOutlet NSMenuItem     *oToggleInfoMenuItem; // DOESN'T APPEAR TO BE HOOKED UP, OR NEEDED.
    IBOutlet NSMenuItem     *oToggleMediaMenuItem; // DOESN'T APPEAR TO BE HOOKED UP, OR NEEDED.
	
	// Pro menu items
	IBOutlet NSMenuItem		*oPasteAsMarkupMenuItem;
	IBOutlet NSMenuItem		*oEditRawHTMLMenuItem;
	IBOutlet NSMenuItem		*oInsertRawHTMLMenuItem;
	IBOutlet NSMenuItem		*oInsertHTMLTextMenuItem;
	IBOutlet NSMenuItem		*oFindSeparator;
	IBOutlet NSMenuItem		*oFindSubmenu;
	
	IBOutlet NSMenuItem		*oCodeInjectionMenuItem;
	IBOutlet NSMenuItem		*oCodeInjectionLevelMenuItem;
	IBOutlet NSMenuItem		*oCodeInjectionSeparator;
	
	
	IBOutlet NSMenuItem		*oAdvancedMenu;		// the main submenu

	// below are outlets of items on that menu
	
	IBOutlet NSMenuItem		*oStandardViewMenuItem;
	IBOutlet NSMenuItem		*oStandardViewWithoutStylesMenuItem;
	IBOutlet NSMenuItem		*oSourceViewMenuItem;
	IBOutlet NSMenuItem		*oDOMViewMenuItem;
	IBOutlet NSMenuItem		*oRSSViewMenuItem;
	IBOutlet NSMenuItem		*oConfigureGoogleMenuItem;
	
	IBOutlet NSMenuItem		*oValidateSourceViewMenuItem;
	
	// Separators AFTER these pro menus that we can hide/show
	IBOutlet NSMenuItem		*oAfterValidateSourceViewMenuItem;
	IBOutlet NSMenuItem		*oAfterEditRawHTMLMenuItem;
	IBOutlet NSMenuItem		*oAfterConfigureGoogleMenuItem;
	
	IBOutlet NSMenuItem		*oInsertExternalLinkMenuItem;
	IBOutlet NSMenuItem		*oInsertBlankPageMenuItem;
	
    // we have pages and collections (summary pages)
    IBOutlet NSMenu			*oAddPageMenu;
    IBOutlet NSMenu			*oNewPageMenu;
    
    IBOutlet NSMenu			*oBadgesMenu;
	IBOutlet NSMenu         *oIndexesMenu;
    IBOutlet NSMenu         *oSocialMediaMenu;
    IBOutlet NSMenu         *oMoreGraphicsMenu;
    
	IBOutlet NSTableView	*oDebugTable;
	IBOutlet NSPanel		*oDebugMediaPanel;
	
    // ivars	
    BOOL _applicationIsLaunching;
	BOOL _appIsTerminating;
	BOOL _appIsExpired;
	BOOL _checkedExpiration;
			
	NSPoint _cascadePoint;
	
	KSProgressPanel *_progressPanel;
}

- (NSArray *) additionalPluginDictionaryForInstallerController:(KSPluginInstallerController *)controller;

- (IBAction) openScreencast:(id)sender;

+ (void) registerDefaults;
+ (BOOL) coreImageAccelerated;
+ (BOOL) fastEnoughProcessor;
- (BOOL) appIsExpired;

- (IBAction)orderFrontPreferencesPanel:(id)sender;
- (IBAction)saveWindowSize:(id)sender;

- (IBAction)showAvailableComponents:(id)sender;
- (IBAction)showAcknowledgments:(id)sender;
- (IBAction)showReleaseNotes:(id)sender;
- (IBAction)showTranscriptWindow:(id)sender;
- (IBAction)showAvailableDesigns:(id)sender;
- (IBAction) showWelcomeWindow:(id)sender;

- (IBAction)showProductPage:(id)sender;

- (IBAction)toggleMediaBrowserShown:(id)sender;

- (IBAction)reloadDebugTable:(id)sender;

- (IBAction)showPluginWindow:(id)sender;

@property (retain) KSProgressPanel *progressPanel;

@end
