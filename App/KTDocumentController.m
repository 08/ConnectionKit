//
//  KTDocumentController.m
//  Marvel
//
//  Created by Terrence Talbot on 9/20/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "KTDocumentController.h"

#import "KT.h"
#import "SVDesignPickerController.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTSite.h"
#import "KTElementPlugInWrapper.h"
#import "SVInspector.h"
#import "KTMaster.h"
#import "SVMigrationDocument.h"
#import "SVMigrationManager.h"
#import "KTPage+Internal.h"
#import "SVWelcomeController.h"
#import "KTPluginInstaller.h"

#import "NSArray+Karelia.h"
#import "NSError+Karelia.h"
#import "NSHelpManager+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSWindowController+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSApplication.h"
#import "KSProgressPanel.h"
#import "KSRegistrationController.h"
#import "SVApplicationController.h"

#import "BDAlias.h"
#import "KSURLUtilities.h"

#import "Debug.h"

#import "Registration.h"


@implementation KTDocumentController

#pragma mark -
#pragma mark Document placeholder window

- (void)showDocumentPlaceholderWindowInitial:(BOOL)firstTimeSoReopenSavedDocuments;
{
    if (gLicenseViolation)		// license violation dialog should open, not the new/open
    {
        [[KSRegistrationController sharedController] showWindow:@"license"];		// string is just a tag for the source of this
    }
    else
    {
		// Open recent documents, maybe show welcome window.
		[[SVWelcomeController sharedController] showWindowAndBringToFront:NO initial:firstTimeSoReopenSavedDocuments];
    }
	
	// Running Lion? If so, document re-opening is done asynchrously
	if ([NSDocumentController respondsToSelector:@selector(restoreWindowWithIdentifier:state:completionHandler:)])
	{
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1ull * NSEC_PER_SEC),dispatch_get_current_queue(), ^{
			if (0 == [[[NSDocumentController sharedDocumentController] documents] count])
			{
				[[SVWelcomeController sharedController] showWindowAndBringToFront:NO initial:NO];
			}
		});
	}
}

#pragma mark -
#pragma mark Creating New Documents

- (IBAction)newDocument:(id)sender
{
    // Display design chooser
    if (_designChooser)
    {
        [[_designChooser window] makeKeyAndOrderFront:self];
    }
    else
    {
        _designChooser = [[SVDesignPickerController alloc] init];
        
        NSArray *designs = [[_designChooser designsController] arrangedObjects];
        [_designChooser setDesign:[designs firstObjectKS]];
        
        SVWelcomeController *welcomeWindow = [SVWelcomeController sharedController];
        if ([[welcomeWindow window] isVisible])
        {
            [_designChooser beginDesignChooserForWindow:[welcomeWindow window]
                                               delegate:self
                                         didEndSelector:@selector(designChooserDidEnd:returnCode:)];
        }
        else
        {
            [_designChooser beginWithDelegate:self
                               didEndSelector:@selector(designChooserDidEnd:returnCode:)];
        }
    }
}

- (void)designChooserDidEnd:(SVDesignPickerController *)designChooser returnCode:(NSInteger)returnCode;
{
    OBPRECONDITION(designChooser == _designChooser);
    
    
    [_designChooser autorelease]; _designChooser = nil;
    if (returnCode == NSAlertAlternateReturn) return;
    
    
    // Create doc
    KTDesign *design = [designChooser design];
    KTDocument *doc = [self openUntitledDocumentAndDisplay:NO error:NULL];
    [[[[doc site] rootPage] master] setDesign:design];
    [doc designDidChange];
    
    
    // Present the doc as if new
    [[doc managedObjectContext] processPendingChanges];
    [[doc undoManager] removeAllActions];
    
    [doc makeWindowControllers];
    [doc showWindows];
}

- (id)makeUntitledDocumentOfType:(NSString *)typeName error:(NSError **)outError
{
    // Do nothing if the license is invalid
	if (gLicenseViolation) {
		NSBeep();
		if (outError)
		{
			*outError = nil;	// otherwise we crash
		}
		return nil;
	}
	
    return [super makeUntitledDocumentOfType:typeName error:outError];
}
    
- (BOOL)alertShowHelp:(NSAlert *)alert
{
	NSString *helpString = @"Document";		// HELPSTRING
	return [NSHelpManager gotoHelpAnchor:helpString];
}

- (NSError *)willPresentError:(NSError *)error
{
	NSError *result = [super willPresentError:error];
	return result;
}

#pragma mark -
#pragma mark Other

- (Class)documentClassForType:(NSString *)documentTypeName
{
    if ([kSVDocumentType_1_0 isEqualToString:documentTypeName])
    {
        return nil;//[KTDataMigrationDocument class];
    }
    else if ([documentTypeName isEqualToString:kSVDocumentTypeName_1_5])
    {
        return [SVMigrationDocument class];
    }
    else
    {
        return [super documentClassForType:documentTypeName];
    }
}

/*  We're overriding this method so that 1.2.x documents are differentiated from the newer ones
 */
- (NSString *)typeForContentsOfURL:(NSURL *)inAbsoluteURL error:(NSError **)outError
{
    // Consult plist first
    NSString *result = [super typeForContentsOfURL:inAbsoluteURL error:outError];
    
    if ([result isEqualToString:kSVDocumentTypeName_1_5] && [inAbsoluteURL isFileURL])
    {
        BOOL fileIsDirectory = YES;
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[inAbsoluteURL path] isDirectory:&fileIsDirectory];
                           
        if (fileExists)
        {
            if ([[KSWORKSPACE ks_typeOfFileAtURL:inAbsoluteURL] conformsToUTI:kSVDocumentType_1_0] &&
                !fileIsDirectory)
            {
                result = kSVDocumentType_1_0;
            }
        }
    }
    
    return result;
}

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL display:(BOOL)displayDocument error:(NSError **)outError
{
	NSString *requestedPath = [absoluteURL path];
	// General error description to use if there are problems
	NSError *subError = nil;
	
    NSString *type = [self typeForContentsOfURL:absoluteURL error:outError];	// Should we ignore this error?
	
	// are we opening a KTDocument?
	if ([type isEqualToString:kSVDocumentTypeName] ||
        [type isEqualToString:kSVDocumentTypeName_1_5] ||
        [type isEqualToString:kSVDocumentType_1_0])
	{
        // Make sure the doc exists. Normally NSDocument would do this for us, but we need to read metadata first
        
        
        
		// check compatibility with KTModelVersion
		NSDictionary *metadata = nil;
		@try
		{
			NSURL *sourceStoreURL = [KTDocument datastoreURLForDocumentURL:absoluteURL
                                                                    type:type];
            
			metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:nil
                                                                                  URL:sourceStoreURL
                                                                                error:&subError];
            
            // Might be a 2.0 beta doc that had new format, but old extension
            if (!metadata && [type isEqualToString:kSVDocumentTypeName_1_5])
            {
                sourceStoreURL = [KTDocument datastoreURLForDocumentURL:absoluteURL
                                                                   type:kSVDocumentTypeName];
                
                metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:nil
                                                                                      URL:sourceStoreURL
                                                                                    error:&subError];
            }
		}
		@catch (NSException *exception)
		{
			// TJT got an NSInternalInconsistencyException, saying that the metadata XML was malformed
			// so we'll just catch that and treat it as if metadata was unreadable
			metadata = nil;
		}
		
		
		NSString *modelVersion = [metadata valueForKey:kKTMetadataModelVersionKey];
        if (![modelVersion length])
		{
            // If failed to read in metadata, assume it's a regular document and try to open it. The document itself will probably then report a failure because the doc is corrupt in some way. #118559
            if (metadata)   
            {
                NSLog(@"error: ***Can't open %@ : no model version!", requestedPath);
                
                NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
                            
                NSString *secondary = NSLocalizedString(@"This document appears to have an unknown document model.\n\nPlease contact Karelia Software by sending feedback from the 'Sandvox' menu.",
                                                     "error reason: document model version is unknown");
                [userInfo setObject:NSLocalizedString(@"Document model error.", @"brief description of error") forKey:NSLocalizedDescriptionKey];
                [userInfo setObject:secondary forKey:NSLocalizedRecoverySuggestionErrorKey];
                [userInfo setObject:requestedPath forKey:NSFilePathErrorKey];
                
                if (outError)
                {
                    *outError = [NSError errorWithDomain:NSCocoaErrorDomain 
                                                    code:NSPersistentStoreInvalidTypeError 
                                                userInfo:userInfo];	
                }
                return nil;
            }
		}
        
        
        
        // Migrate?
        if (![type isEqualToString:kSVDocumentTypeName])
        {
            NSDocument *doc = [super openDocumentWithContentsOfURL:absoluteURL
                                                           display:NO
                                                             error:outError];
            [doc saveDocumentAs:self];
            return doc;
        }
    }
    
    
    
    // by now, absoluteURL should be a good file, open it
	id document = [super openDocumentWithContentsOfURL:absoluteURL
											   display:displayDocument
												 error:&subError];
	if (!document && subError && outError)
	{
		NSString *reasonOfSubError = [subError localizedFailureReason];
		if (!reasonOfSubError)	// Note:  above returns nil!
		{
			reasonOfSubError = [[subError userInfo] objectForKey:@"reason"];
			// I'm not sure why but emperically the "reason" key has been set.
		}
		if (!reasonOfSubError)
		{
			reasonOfSubError = [NSString stringWithFormat:NSLocalizedString(@"Error type: %@, code %d", @"information for an error"), [subError domain], [subError code]];
		}

		NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
		[errorInfo setValue:NSLocalizedString(@"There is a problem with the document.", @"brief description of error.") forKey:NSLocalizedDescriptionKey];
		[errorInfo setValue:reasonOfSubError forKey:NSLocalizedRecoverySuggestionErrorKey];
		[errorInfo setValue:subError forKey:NSUnderlyingErrorKey];
		[errorInfo setObject:requestedPath forKey:NSFilePathErrorKey];

		if (outError)
		{
			*outError = [NSError errorWithDomain:[subError domain] 
											code:[subError code] 
										userInfo:errorInfo];
		}
	}
	
	if ([document isKindOfClass:[KTPluginInstaller class]])
	{
		/// once we've created this "document" we don't want it hanging around
		[document performSelector:@selector(close)
					   withObject:nil 
					   afterDelay:0.0];
	}
	
	return document;
}

#pragma mark -
#pragma mark Document List

- (void)synchronizeOpenDocumentsUserDefault
{
    if ([NSDocumentController respondsToSelector:@selector(restoreWindowWithIdentifier:state:completionHandler:)]) return;
    
    NSMutableArray *aliases = [NSMutableArray array];
    NSEnumerator *enumerator = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
    KTDocument *document;
    while ( ( document = [enumerator nextObject] ) )
    {
		if ([document isKindOfClass:[KTDocument class]])	// make sure it's a KTDocument
		{
			if ( [[[document fileURL] ks_pathExtension] isEqualToString:kSVDocumentPathExtension] 
				&& ![[[document fileURL] path] hasPrefix:[[NSBundle mainBundle] bundlePath]]  )
			{
				BDAlias *alias = [BDAlias aliasWithPath:[[document fileURL] path] relativeToPath:[NSHomeDirectory() stringByResolvingSymlinksInPath]];
				if (nil == alias)
				{
					// couldn't find relative to home directory, so just do absolute
					alias = [BDAlias aliasWithPath:[[document fileURL] path]];
				}
				if ( nil != alias )
				{
					NSData *aliasData = [[[alias aliasData] copy] autorelease];
					[aliases addObject:aliasData];
				}
			}
		}
    }
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithArray:aliases]
                                              forKey:kSVOpenDocumentsKey];
	BOOL synchronized = [[NSUserDefaults standardUserDefaults] synchronize];
	if (!synchronized)
	{
		NSLog(@"Unable to synchronize defaults");
	}
}

/*	Remember any docs we open
 */
- (void)addDocument:(NSDocument *)document
{
	[super addDocument:document];
    
    [[SVWelcomeController sharedController] hideWindow:self];
}

/*	When a document is removed we don't want to reopen on launch, unless the close was part of the app quitting
 */
- (void)removeDocument:(NSDocument *)document
{
	[super removeDocument:document];
    
    if (![NSApp isTerminating])
	{
		[self synchronizeOpenDocumentsUserDefault];	// do this (again) here -- in removeDocument, it doesn't actually remove it!
		
		// Show the placeholder window when there are no docs open
        if ([[self documents] count] == 0)
        {
            [self showDocumentPlaceholderWindowInitial:NO];
        }
    }
}

- (NSArray *)reopenPreviouslyOpenedDocuments;
{
	// Figure out if we should create or open document(s)
	if ([NSDocumentController respondsToSelector:@selector(restoreWindowWithIdentifier:state:completionHandler:)])
    {
        return nil;
    }
    
    
	BOOL openLastOpened = ([[NSUserDefaults standardUserDefaults] boolForKey:@"AutoOpenLastOpenedOnLaunch"] &&
						   !(GetCurrentEventKeyModifiers() & optionKey));   // #39352
    if (!openLastOpened) return nil;
    
	
	NSArray *lastOpenedPaths = [[NSUserDefaults standardUserDefaults] arrayForKey:kSVOpenDocumentsKey];
    if (![lastOpenedPaths count]) return nil;
    
	
    NSArray *result = nil;
    NSMutableArray *filesFound = [NSMutableArray array];
	NSMutableArray *filesNotFound = [NSMutableArray array];
	
	// figure out what documents, if any, we can and can't find
	for (id aliasData in lastOpenedPaths )
    {
        BDAlias *alias = [BDAlias aliasWithData:aliasData];
        NSString *path = [alias fullPath];
        if (nil == path)
        {
            NSString *lastKnownPath = [alias lastKnownPath];
            [filesNotFound addObject:lastKnownPath];
            LOG((@"Can't find '%@'", [lastKnownPath stringByAbbreviatingWithTildeInPath]));
        }
        
        // is it in the Trash? ([KSWORKSPACE userTrashDirectory])
        else if ( NSNotFound != [path rangeOfString:@".Trash"].location )
        {
            // path contains localized .Trash, let's skip it
            LOG((@"Not opening '%@'; it is in the trash", [path stringByAbbreviatingWithTildeInPath]));
        }
        else
        {
            LOG((@"Going to open '%@'; it is NOT in the trash", path));
            [filesFound addObject:alias];
        }
    }
	
    
    // open whatever used to be open
	for (BDAlias *alias in filesFound)
    {
        NSString *path = [alias fullPath];
        
        // check to make sure path is valid
        if ( ![[NSFileManager defaultManager] fileExistsAtPath:path] )
        {
            [filesNotFound addObject:path];
            continue;
        }				
        
        
        NSURL *fileURL = [NSURL fileURLWithPath:path];
        
        NSError *error = nil;
        if (![self openDocumentWithContentsOfURL:fileURL display:YES error:&error])
        {
            error = [self makeErrorLookLikeErrorFromDoubleClickingDocument:error];
            result = (result ? [result arrayByAddingObject:error] : [NSArray arrayWithObject:error]);
        }
    }
    
    
    // Report error for files not found
    if ( [filesNotFound count] > 0 )
    {
        NSString *missingFiles = [NSString string];
        unsigned int i;
        for ( i = 0; i < [filesNotFound count]; i++ )
        {
            NSString *toAdd = [[filesNotFound objectAtIndex:i] lastPathComponent];
            toAdd = [[NSFileManager defaultManager] displayNameAtPath:toAdd];
            
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
        
        NSError *error = [KSError errorWithDomain:NSCocoaErrorDomain
                                             code:NSFileNoSuchFileError
                             localizedDescription:NSLocalizedString(@"Unable to locate previously opened files.", @"alert: Unable to locate previously opened files.")
                      localizedRecoverySuggestion:missingFiles
                                  underlyingError:nil];
        
        result = (result ? [result arrayByAddingObject:error] : [NSArray arrayWithObject:error]);
    }
	
    return result;
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
    
	NSError *result = [KSError errorWithDomain:[anError domain] code:[anError code]
						  localizedDescription:desc
                   localizedRecoverySuggestion:secondary		// we want to show the reason on the alert
                               underlyingError:anError];
	
	return result;
}

#pragma mark -
#pragma mark Recent Documents

// N.B.: This is called by -[NSDocumentController removeDocument:] so we will have to sync later too.

- (void)noteNewRecentDocument:(NSDocument *)aDocument
{
	// By default, NSDocument tries to register itself even if it's not in the documents list.
	if ([[self documents] containsObjectIdenticalTo:aDocument])
	{
		BOOL noteDocument = ![aDocument isKindOfClass:[KTPluginInstaller class]];
		
		if ([aDocument isKindOfClass:[KTDocument class]])
		{
			// we override here to prevent sample sites from being added to list
			NSURL *documentURL = [aDocument fileURL];
			NSString *documentPath = [documentURL path];
			
			NSString *samplesPath = [[NSBundle mainBundle] bundlePath];
			if ([documentPath hasPrefix:samplesPath])
			{
				noteDocument = NO;
			}
		}
		
		if (noteDocument)
		{
			[super noteNewRecentDocument:aDocument];
            
            if (![NSApp isTerminating])
            {
                [self synchronizeOpenDocumentsUserDefault];
            }
		}
	}
}

#pragma mark Inspectors

- (Class)inspectorClass;
{
    return [SVInspector class];
}

#pragma mark validation


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	OBPRECONDITION(menuItem);
	VALIDATION((@"%s %@",__FUNCTION__, menuItem));
	
		// default to YES so we don't have to do special validation for each action. Some actions might say NO.
	
	if (gLicenseViolation || [[NSApp delegate] appIsExpired])
	{
		return NO;	// No, don't let stuff be done if expired.
	}
	
	return [super validateMenuItem:menuItem];
}


@end
