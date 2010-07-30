//
//  KTPlaceholderController.m
//  Marvel
//
//  Created by Dan Wood on 10/16/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import "SVWelcomeController.h"

#import "NSColor+Karelia.h"
#import "NSObject+Karelia.h"
#import <QTKit/QTKit.h>
#import "KSLicensedAppDelegate.h"
#import "KSNetworkNotifier.h"
#import "KSYellowStickyWindow.h"
#import "Registration.h"
#import "NSDate+Karelia.h"
#import "NSString+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSArray+Karelia.h"
#import "CIImage+Karelia.h"
#import <QuartzCore/QuartzCore.h>
#import "KTDocument.h"
#import "KSRecentDocument.h"
#import "KSProgressPanel.h"
#import "BDAlias.h"
#import "KTDocumentController.h"
#import "SVApplicationController.h"
#import "NSError+Karelia.h"
#import "KTPublishingEngine.h"

@interface SVWelcomeController ()

- (void)loadRecentDocumentList;

@end



@implementation SVWelcomeController

@synthesize sticky = _sticky;
@synthesize networkAvailable = _networkAvailable;
@synthesize recentDocuments = _recentDocuments;

- (id)init
{
    self = [super initWithWindowNibName:@"Welcome"];
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[oRecentDocsController removeObserver:self forKeyPath:@"selection"];
	
	[super dealloc];
}

- (NSError *)makeErrorLookLikeErrorFromDoubleClickingDocument:(NSError *)anError;
{
    OBPRECONDITION(anError);
    
	NSDictionary *userInfo = [anError userInfo];
	NSString *path = [userInfo objectForKey:NSFilePathErrorKey];
	if (nil == path)
	{
		NSURL *url = [userInfo objectForKey:NSURLErrorKey];
		path = [url path];
	}
	NSString *prevTitle = [anError localizedDescription];
	NSString *desc = nil;
	if (path)
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		desc = [NSString stringWithFormat:NSLocalizedString(@"The document “%@” could not be opened. %@", @"brief description of error."), [fm displayNameAtPath:path], prevTitle];
	}
	else
	{
		desc = [NSString stringWithFormat:NSLocalizedString(@"The document could not be opened. %@", @"brief description of error."), prevTitle];
	}
	NSString *secondary = [anError localizedRecoverySuggestion]; 
	if (!secondary)
	{
		secondary = [anError localizedFailureReason];
	}
	if (!secondary)	// Note:  above returns nil!
	{
		secondary = [[anError userInfo] objectForKey:@"reason"];
		// I'm not sure why but emperically the "reason" key has been set.

	}
								 
	NSError *result = [NSError errorWithDomain:[anError domain] code:[anError code]
						  localizedDescription:desc
			 localizedRecoverySuggestion:secondary		// we want to show the reason on the alert
						 underlyingError:anError];
	
	return result;
}

- (BOOL) reopenPreviouslyOpenedDocumentsUsingProgressPanel:(KSProgressPanel *)progressPanel
{
	BOOL result = NO;		// set to yes if we want welcome window to be shown
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSFileManager *fm = [NSFileManager defaultManager];
	
	[progressPanel setMessageText:NSLocalizedString(@"Searching for previously opened documents...",
													"Message while checking documents.")];
	
	// figure out if we should create or open document(s)
	BOOL openLastOpened = ([defaults boolForKey:@"AutoOpenLastOpenedOnLaunch"] &&
						   !(GetCurrentEventKeyModifiers() & optionKey));   // Case 39352
	
	NSArray *lastOpenedPaths = [defaults arrayForKey:@"KSOpenDocuments"];
	
	NSMutableArray *filesFound = [NSMutableArray array];
	NSMutableArray *filesNotFound = [NSMutableArray array];
	NSMutableArray *filesInTrash = [NSMutableArray array];
	NSMutableArray *errorsToPresent = [NSMutableArray array];
	BOOL atLeastOneDocumentOpened = NO;
	
	// figure out what documents, if any, we can and can't find
	if ( openLastOpened && (nil != lastOpenedPaths) && ([lastOpenedPaths count] > 0) )
	{
		id aliasData;
		for ( aliasData in lastOpenedPaths )
		{
			BDAlias *alias = [BDAlias aliasWithData:aliasData];
			NSString *path = [alias fullPath];
			if (nil == path)
			{
				NSString *lastKnownPath = [alias lastKnownPath];
				[filesNotFound addObject:lastKnownPath];
				LOG((@"Can't find '%@'", [lastKnownPath stringByAbbreviatingWithTildeInPath]));
			}
			
			// is it in the Trash? ([[NSWorkspace sharedWorkspace] userTrashDirectory])
			else if ( NSNotFound != [path rangeOfString:@".Trash"].location )
			{
				// path contains localized .Trash, let's skip it
				[filesInTrash addObject:alias];
				LOG((@"Not opening '%@'; it is in the trash", [path stringByAbbreviatingWithTildeInPath]));
			}
			else
			{
				[filesFound addObject:alias];
			}
		}
	}
	// run through the possibilities
	if ( openLastOpened 
		&& ([lastOpenedPaths count] > 0) 
		&& ([[[KTDocumentController sharedDocumentController] documents] count] == 0) )
	{
		// open whatever used to be open
		if ( [filesFound count] > 0 )
		{
			BDAlias *alias;
			for ( alias in filesFound )
			{
				NSString *path = [alias fullPath];
				
				// check to make sure path is valid
				if ( ![[NSFileManager defaultManager] fileExistsAtPath:path] )
				{
					[filesNotFound addObject:path];
					continue;
				}				
				
				NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Opening %@...", "Alert Message"), [fm displayNameAtPath:[path stringByDeletingPathExtension]]];
				[progressPanel setMessageText:message];
				[progressPanel setIcon:[NSImage imageNamed:@"document"]];
				
				NSURL *fileURL = [NSURL fileURLWithPath:path];
				
				NSError *error = nil;
				if ([[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:fileURL display:YES error:&error])
				{
					atLeastOneDocumentOpened = YES;
				}
				else
				{
					error = [self makeErrorLookLikeErrorFromDoubleClickingDocument:error];
					[errorsToPresent addObject:error];		// show the error later
				}                  
			}
		}
		
		// Now show the errors we need to present
		for (NSError *error in errorsToPresent)
		{
			if (atLeastOneDocumentOpened)
			{
				[[NSDocumentController sharedDocumentController] presentError:error];		// show error as a standalone alert since we won't be showing welcome
			}
			else
			{
				// Make sure window is showing
				[self showWindow:self];
				[[NSDocumentController sharedDocumentController] presentError:error modalForWindow:[self window] delegate:nil didPresentSelector:nil contextInfo:nil];
			}
		}
		
		// put up an alert showing any files not found (files in Trash are ignored)
		if ( [filesNotFound count] > 0 )
		{
			NSString *missingFiles = [NSString string];
			unsigned int i;
			for ( i = 0; i < [filesNotFound count]; i++ )
			{
				NSString *toAdd = [[filesNotFound objectAtIndex:i] lastPathComponent];
				toAdd = [fm displayNameAtPath:toAdd];
				
				missingFiles = [missingFiles stringByAppendingString:toAdd];
				if ( i < ([filesNotFound count]-1) )
				{
					missingFiles = [missingFiles stringByAppendingString:@", "];
				}
				else if ( i == ([filesNotFound count]-1) && i > 0 )	// no period if only one item
				{
					missingFiles = [missingFiles stringByAppendingString:@"."];
				}
			}
			
			[progressPanel performClose:self];	// hide this FIRST

			// Make sure window is showing
			[self showWindow:self];

			NSAlert *alert = [[NSAlert alloc] init];
			[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK Button")];
			[alert setMessageText:NSLocalizedString(@"Unable to locate previously opened files.", @"alert: Unable to locate previously opened files.")];
			[alert setInformativeText:missingFiles];
			[alert setAlertStyle:NSWarningAlertStyle];
			
			if (atLeastOneDocumentOpened)
			{
				[alert runModal];		// show error as a standalone alert since we won't be showing welcome
			}
			else
			{
				[alert beginSheetModalForWindow:[self window] 
								  modalDelegate:nil 
								 didEndSelector:nil
									contextInfo:nil];
			}
			[alert release];	// will be dealloced when alert is dismissed
		}
	}
	else
	{
		result = YES;		// we can show the welcome window; no recent docs opened.
	}
	return result;
}

- (void)showWindowAndBringToFront:(BOOL)forceBringToFront initial:(BOOL)firstTimeSoReopenSavedDocuments;
{
	BOOL showIfDefaultSet = YES;
	
	if (firstTimeSoReopenSavedDocuments)
	{
		showIfDefaultSet = [self reopenPreviouslyOpenedDocumentsUsingProgressPanel:nil];//[[NSApp delegate] progressPanel]];
	}
	
	// Show it if we either force it to be shown, or it's allowed be shown if defaults set
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	if (forceBringToFront || (showIfDefaultSet && [defaults boolForKey:@"ShowWelcomeWindow"] && ![[self window] isVisible]) )
	{
		[self showWindow:self];
		
		// Convenience -- focus on first item in list
		NSArray *recentDocs = [oRecentDocsController content];
		if ([recentDocs count])
		{
			[[self window] makeFirstResponder:oRecentDocumentsTable];
			[oRecentDocsController setSelectionIndexes:[NSIndexSet indexSetWithIndex:0]];
		}

		
	}
}


- (void) updateLicenseStatus:(NSNotification *)aNotification
{
	if (nil != gRegistrationString )
	{
		[self.sticky.animator setAlphaValue:0.0];	// animate to hidden
	}
	else
	{
		NSString *stickyHeadline = nil;
		NSString *stickyDetails = nil;
		NSString *stickyButtonTitle = nil;
		
		switch(gRegistrationFailureCode)
		// enum { kKSLicenseOK, kKSCouldNotReadLicenseFile, kKSEmptyRegistration, kKSBlacklisted, kKSLicenseExpired, kKSNoLongerValid, kKSLicenseCheckFailed };
		{
			case kKSLicenseCheckFailed:	// license entered but it's not valid
				
				stickyHeadline = NSLocalizedString(@"Invalid Registration Key", @"title of reminder note - please make sure this will fit on welcome window when unlicensed");
				stickyDetails = [NSString stringWithFormat:NSLocalizedString(@"Sandvox is free for publishing small websites, up to %d pages. For more complex sites, you need to enter a valid license.", @"explanation of license status - please make sure this will fit on welcome window when unlicensed")];
				stickyButtonTitle = NSLocalizedString(@"Enter License Key", @"Button title to enter a license Code");
				
				break;
			case kKSLicenseExpired:		// Trial license expired
			
				stickyHeadline = NSLocalizedString(@"Trial License Expired", @"title of reminder note - please make sure this will fit on welcome window when unlicensed");
				stickyDetails = [NSString stringWithFormat:NSLocalizedString(@"The registration key you entered has expired.", @"explanation of license status - please make sure this will fit on welcome window when unlicensed"), kMaxNumberOfFreePublishedPages];
				stickyButtonTitle = NSLocalizedString(@"Buy a License", @"Button title to purchase a license");
				
				break;
			case kKSNoLongerValid:		// License from a previous version of Sandvox
				
				stickyHeadline = NSLocalizedString(@"Upgrade to Sandvox 2", @"title of reminder note - please make sure this will fit on welcome window when unlicensed");
				stickyDetails = [NSString stringWithFormat:NSLocalizedString(@"Your registration key for Sandvox 1 is not valid for version 2. Functionality will be limited.", @"explanation of license status - please make sure this will fit on welcome window when unlicensed"), kMaxNumberOfFreePublishedPages];
				stickyButtonTitle = NSLocalizedString(@"Upgrade your License", @"Button title to purchase a license");
				
				break;
			default:					// Unlicensed, treat as free/demo
				stickyHeadline = NSLocalizedString(@"This is the free edition of Sandvox", @"title of reminder note - please make sure this will fit on welcome window when unlicensed");
				stickyDetails = [NSString stringWithFormat:NSLocalizedString(@"Sandvox is free for publishing small websites, up to %d pages. For more complex sites, you will want to buy a license.", @"explanation of license status - please make sure this will fit on welcome window when unlicensed"), kMaxNumberOfFreePublishedPages];
				stickyButtonTitle = NSLocalizedString(@"Buy a License", @"Button title to purchase a license");
				
				break;
		}

		
		
		NSColor *blueColor = [NSColor colorWithCalibratedRed:0.000 green:0.295 blue:0.528 alpha:1.000];
		
		NSDictionary *attr1 = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Marker Felt" size:20.0], NSFontAttributeName, nil];
		NSDictionary *attr2 = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Chalkboard" size:12.0], NSFontAttributeName, nil];
		
		NSMutableAttributedString *attrStickyText = [[[NSMutableAttributedString alloc] initWithString:
													  stickyHeadline attributes:attr1] autorelease];	
		[attrStickyText appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n" attributes:attr1] autorelease]];
		[attrStickyText appendAttributedString:[[[NSAttributedString alloc] initWithString:stickyDetails attributes:attr2] autorelease]];
		[attrStickyText addAttribute:NSForegroundColorAttributeName value:blueColor range:NSMakeRange(0, [attrStickyText length])];
		[attrStickyText setAlignment:NSCenterTextAlignment range:NSMakeRange(0, [attrStickyText length])];
		
		[[oStickyTextView textStorage] setAttributedString:attrStickyText];
		
		[oStickyButton setTitle:stickyButtonTitle];

		
		
		[self.sticky.animator setAlphaValue:1.0];	// animate open
	}
}

- (void) updateNetworkStatus:(NSNotification *)aNotification
{
	self.networkAvailable = [KSNetworkNotifier isNetworkAvailable];
}

- (IBAction)showWindow:(id)sender;
{
	NSRect contentViewRect = [[self window] contentRectForFrameRect:[[self window] frame]];
	NSRect separatorFrame = [oRecentBox frame];

	[self loadRecentDocumentList];
	NSArray *recentDocs = [oRecentDocsController content];
	
	NSSize size = NSZeroSize;
	
	if ([recentDocs count])
	{
		size = NSMakeSize(NSMaxX(separatorFrame), NSHeight(contentViewRect));
	}
	else
	{
		size = NSMakeSize(NSMinX(separatorFrame)-1, NSHeight(contentViewRect));
	}
	
	// Resize the window ... however, turn off autoresizing so that it doesn't reposition stuff.
	NSView *contentView = [[self window] contentView];
	BOOL autoresizesSubviews = [contentView autoresizesSubviews];
	if (autoresizesSubviews) {
		[contentView setAutoresizesSubviews:NO];
	}

	[oRecentBox removeFromSuperview];		// take out this whole box so we can't tab there, etc.
	[[self window] setContentSize:size];

	if (autoresizesSubviews) {
		[contentView setAutoresizesSubviews:autoresizesSubviews];
	}
	
	[[self window] center];
	[super showWindow:sender];
}

- (void) setupStickyWindow
{
	if (!_sticky)
	{
		_sticky = [[KSYellowStickyWindow alloc]
				   initWithContentRect:NSMakeRect(0,0,kStickyViewWidth,kStickyViewHeight)
				   styleMask:NSBorderlessWindowMask
				   backing:NSBackingStoreBuffered
				   defer:YES];
		
		[oStickyRotatedView setFrameCenterRotation:8.0];
				
		[_sticky setContentView:oStickyView];
		[_sticky setAlphaValue:0.0];		// initially ZERO ALPHA!

		NSRect separatorFrame = [oRecentBox frame];
		NSPoint convertedWindowOrigin;
		if ([[oRecentDocsController content] count])
		{
			convertedWindowOrigin = NSMakePoint(NSMaxX(separatorFrame)-80,300);
		}
		else
		{
			convertedWindowOrigin = NSMakePoint(NSMinX(separatorFrame)-80,400);
		}		
		[_sticky setFrameTopLeftPoint:[[self window] convertBaseToScreen:convertedWindowOrigin]];
		
		[[self window] addChildWindow:_sticky ordered:NSWindowAbove];
	}
}

- (void)loadRecentDocumentList;
{
	NSArray *urls = [[NSDocumentController sharedDocumentController] recentDocumentURLs];
#if 0
	// TESTING HARNESS ... I HAVE A BUNCH OF DOCUMENTS IN THERE.
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *dir = [@"~/Desktop" stringByExpandingTildeInPath];
	NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil];
	NSMutableArray *localURLs = [NSMutableArray array];
	for (NSString *filename in files)
	{
		if (![filename hasPrefix:@"."])
		{
			NSString *path = [dir stringByAppendingPathComponent:filename];
			NSURL *url = [NSURL fileURLWithPath:path];
			[localURLs addObject:url];
		}
	}
	urls = [NSArray arrayWithArray:localURLs];
#endif
	
#if 0
	// Test for having ZERO recent documents.
	urls = [NSArray array];
#endif
	
	// Set up our storage for speeding up display of these recent documents.  Otherwise it's very sluggish.
	NSMutableArray *recentDocuments = [NSMutableArray array];
	NSSet *urlSet = [NSSet setWithArray:urls];
	
	for (NSURL *url in urls)
	{
		KSRecentDocument *recentDoc = [[[KSRecentDocument alloc] initWithURL:url allURLs:urlSet] autorelease];
		[recentDocuments addObject:recentDoc];
		(void) [recentDoc previewImage];	// get the preview started loading
	}
	self.recentDocuments = [NSArray arrayWithArray:recentDocuments];
	
	[oRecentDocsController setSelectionIndexes:[NSIndexSet indexSet]];
	
}

- (void)windowDidLoad
{
    [super windowDidLoad];

	// ASAP, load the recent document list, to kick off loading previews
	[self loadRecentDocumentList];

	[oRecentDocumentsTable setDoubleAction:@selector(openSelectedRecentDocument:)];
	[oRecentDocumentsTable setTarget:self];
	[oRecentDocumentsTable setIntercellSpacing:NSMakeSize(0,3.0)];	// get the columns closer together

	[oRecentDocsController addObserver:self
		   forKeyPath:@"selection"
			  options:NSKeyValueObservingOptionNew
			  context:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateLicenseStatus:)
												 name:kKSLicenseStatusChangeNotification
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNetworkStatus:) name:kKSNetworkIsAvailableNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNetworkStatus:) name:kKSNetworkIsNotAvailableNotification object:nil];
		
	
	[self updateLicenseStatus:nil];
	[self updateNetworkStatus:nil];

	[[self window] setLevel:NSNormalWindowLevel];
	[[self window] setExcludedFromWindowsMenu:YES];

	[[self window] setContentBorderThickness:50.0 forEdge:NSMinYEdge];	// have to do in code until 10.6

}

// Attach sticky here becuase it seems we can only really make this child window appear when the window
// is already appearing, and I don't see a notification for window-did-show.  We don't want to orderFront
// the sticky window because that's weird if our welcome window is not in front.
- (void)windowDidBecomeKey:(NSNotification *)notification
{
	[self setupStickyWindow];
	[self updateLicenseStatus:nil];
}

- (IBAction)newDocument:(id)sender
{
	[[self window] orderOut:self];
	
    NSError *error;
    if (![[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:&error])
    {
        [[NSDocumentController sharedDocumentController] presentError:error
                                                       modalForWindow:[self window]
                                                             delegate:nil
                                                   didPresentSelector:nil
                                                          contextInfo:NULL];
    }
}

- (IBAction)openDocument:(id)sender
{
	[[self window] orderOut:self];
	[[NSDocumentController sharedDocumentController] openDocument:self];
}

- (IBAction)openSelectedRecentDocument:(id)sender;
{
	NSArray *recentDocuments = [oRecentDocsController selectedObjects];
	for (KSRecentDocument *recentDoc in recentDocuments)
	{
		NSURL *fileURL = [recentDoc URL];
		
		NSError *error = nil;
		if (![[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:fileURL
																					display:YES
																					  error:&error])
		{
			if (error)
			{
				error = [self makeErrorLookLikeErrorFromDoubleClickingDocument:error];
			}
			[[NSDocumentController sharedDocumentController] presentError:error
														   modalForWindow:[self window]
																 delegate:nil
													   didPresentSelector:nil
															  contextInfo:NULL];
		}
	}
}

- (IBAction) openLicensing:(id)sender
{
	[[NSApp delegate] performSelector:@selector(showRegistrationWindow:) withObject:sender afterDelay:0.0];
}

- (IBAction) openScreencast:(id)sender;
{
	[[NSApp delegate] openScreencast:nil];
}

- (IBAction) showHelp:(id)sender
{
	[[NSApp delegate] showHelpPage:@"Discover"];	// HELPSTRING
}

- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation
{
	KSRecentDocument *doc = [[oRecentDocsController arrangedObjects] objectAtIndex:row];
	NSString *displayPath = [[NSFileManager defaultManager] displayPathAtPath:[[doc URL] path]];

	return displayPath;
}


- (void)observeValueForKeyPath:(NSString *)aKeyPath
                      ofObject:(id)anObject
                        change:(NSDictionary *)aChange
                       context:(void *)aContext
{
	if ([aKeyPath isEqualToString:@"selection"])
	{
		// NSLog(@"%@", [anObject selectedObjects]);
		if ([[anObject selectedObjects] count] > 1)
		{
			[oOpenSelectedButton setTitle:NSLocalizedString(@"Open Selected Items", "Button title - plural recent documents to open")];
		}
		else
		{
			[oOpenSelectedButton setTitle:NSLocalizedString(@"Open Selected Item", "Button title - single recent document to open")];

		}
	}
}


@end
