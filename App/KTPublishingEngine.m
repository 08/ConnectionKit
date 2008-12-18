//
//  KTExportEngine.m
//  Marvel
//
//  Created by Mike on 12/12/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTPublishingEngine.h"

#import "KTAbstractElement+Internal.h"
#import "KTAbstractPage+Internal.h"
#import "KTDesign.h"
#import "KTDocumentInfo.h"
#import "KTHTMLTextBlock.h"
#import "KTMaster+Internal.h"
#import "KTPage+Internal.h"

#import "KTMediaContainer.h"
#import "KTMediaFile.h"
#import "KTMediaFileUpload.h"

#import "NSString+Publishing.h"
#import "NSBundle+KTExtensions.h"

#import "NSData+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSPlugin.h"
#import "KSThreadProxy.h"

#import "Debug.h"
#import "Registration.h"


NSString *KTPublishingEngineErrorDomain = @"KTPublishingEngineError";


#define KTParsingInterval 0.1


@interface KTPublishingEngine (Private)

- (void)startConnection;
- (void)setRootTransferRecord:(CKTransferRecord *)rootRecord;

- (void)parseAndUploadPageIfNeeded:(KTAbstractPage *)page;
- (void)_parseAndUploadPageIfNeeded:(KTAbstractPage *)page;
- (KTPage *)_pageToPublishAfterPageExcludingChildren:(KTAbstractPage *)page;

- (void)_uploadMainCSSAndGraphicalText:(NSURL *)mainCSSFileURL remoteDesignDirectoryPath:(NSString *)remoteDesignDirectoryPath;

- (void)uploadMediaIfNeeded:(KTMediaFileUpload *)media;

- (void)addResourceFile:(NSURL *)resourceURL;

- (CKTransferRecord *)createDirectory:(NSString *)remotePath;
- (unsigned long)remoteFilePermissions;
- (unsigned long)remoteDirectoryPermissions;

@end


#pragma mark -


@implementation KTPublishingEngine

#pragma mark -
#pragma mark Init & Dealloc

/*  Subfolder can be either nil (there isn't one), or a path relative to the doc root. Exporting
 *  never uses a subfolder, but full-on publishing can.
 */
- (id)initWithSite:(KTDocumentInfo *)site
  documentRootPath:(NSString *)docRoot
     subfolderPath:(NSString *)subfolder
{
	OBPRECONDITION(site);
    if (docRoot && ![docRoot isEqualToString:@""]) OBPRECONDITION([docRoot isAbsolutePath]);
    OBPRECONDITION(!subfolder || ![subfolder isAbsolutePath]);
// FIXME: Providing a relative path needs to be better handled elsewhere in the system
    
    if (self = [super init])
	{
		_documentInfo = [site retain];
        
        _uploadedMedia = [[NSMutableSet alloc] init];
        _resourceFiles = [[NSMutableSet alloc] init];
        
        _documentRootPath = [docRoot copy];
        _subfolderPath = [subfolder copy];
	}
	
	return self;
}

- (void)dealloc
{
    // The connection etc. should already have been shut down
    OBASSERT(!_connection);
    
    [_baseTransferRecord release];
    [_rootTransferRecord release];
    [_documentInfo release];
	[_documentRootPath release];
    [_subfolderPath release];
    [_uploadedMedia release];
    [_resourceFiles release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Delegate

- (id <KTPublishingEngineDelegate>)delegate { return _delegate; }

- (void)setDelegate:(id <KTPublishingEngineDelegate>)delegate { _delegate = delegate; }

#pragma mark -
#pragma mark Simple Accessors

- (KTDocumentInfo *)site { return _documentInfo; }

- (NSString *)documentRootPath { return _documentRootPath; }

- (NSString *)subfolderPath { return _subfolderPath; }
    
/*  Combines doc root and subfolder to get the directory that all content goes into
 */
- (NSString *)baseRemotePath
{
    NSString *result = [[self documentRootPath] stringByAppendingPathComponent:[self subfolderPath]];
    return result;
}

#pragma mark -
#pragma mark Overall flow control

- (void)start
{
	if ([self hasStarted]) return;
    _hasStarted = YES;
    
    
    // Setup connection and transfer records
    [self startConnection];
    [self setRootTransferRecord:[CKTransferRecord rootRecordWithPath:[self documentRootPath]]];
    
    
    // Start by publishing the home page
    [self performSelector:@selector(parseAndUploadPageIfNeeded:)
               withObject:[[self site] root]
               afterDelay:KTParsingInterval];
}

- (void)cancel
{
    // TODO: End parsing of pages etc as well
    if ([self hasStarted] && ![self hasFinished])
    {
        [[self connection] forceDisconnect];
        [self didFinish];
    }
}

- (BOOL)hasStarted
{
    return _hasStarted;
}

- (BOOL)hasFinished
{
    return _hasFinished;
}

#pragma mark -
#pragma mark Transfer Records

- (CKTransferRecord *)rootTransferRecord { return _rootTransferRecord; }

/*  Also has the side-effect of updating the base transfer record
 */
- (void)setRootTransferRecord:(CKTransferRecord *)rootRecord
{
    [rootRecord retain];
    [_rootTransferRecord release];
    _rootTransferRecord = rootRecord;
    
    // If there is a subfolder, create it. This also gives us a valid -baseTransferRecord
    [self willChangeValueForKey:@"baseTransferRecord"]; // Automatic KVO-notifications are used for rootTransferRecord
    [_baseTransferRecord release];
    _baseTransferRecord = (rootRecord) ? [[self createDirectory:[self baseRemotePath]] retain] : nil;
    [self didChangeValueForKey:@"baseTransferRecord"];
}

/*  The transfer record corresponding to -baseRemotePath. There is no decdicated setter method, use
 *  -setRootTransferRecord: instead to generate a new baseTransferRecord.
 */
- (CKTransferRecord *)baseTransferRecord
{
   return _baseTransferRecord;
}

@end


#pragma mark -


@implementation KTPublishingEngine (SubclassSupport)

#pragma mark -
#pragma mark Overall flow control

/*  Called once we've finished, regardless of success.
 */
- (void)didFinish
{
    _hasFinished = YES;
    
    [_connection setDelegate:nil];
    [_connection release]; _connection = nil;
    
    
    // Case 37891: Wipe the undo stack as we don't want the user to undo back past the publishing changes
    NSUndoManager *undoManager = [[[self site] managedObjectContext] undoManager];
    [undoManager removeAllActions];
}

/*  Call this method if something went wrong. The delegate will be alerted, and the engine halted
 */
- (void)failWithError:(NSError *)error;
{
    [self cancel];
    [[self delegate] publishingEngine:self didFailWithError:error];
}

#pragma mark -
#pragma mark Connection

/*  Simple accessor for the connection. If we haven't started uploading yet, or have finished, it returns nil.
 *  The -connect method is responsible for creating and storing the connection.
 */
- (id <CKConnection>)connection { return _connection; }

- (void)startConnection
{
    _connection = [[self createConnection] retain];
    [_connection setDelegate:self];
    [_connection connect];
}

/*  Designed for easy subclassing, this method creates the connection but does not store or connect it
 */
- (id <CKConnection>)createConnection
{
    id <CKConnection> result = [[[CKFileConnection alloc] init] autorelease];
    
    // Create site directory
    [result createDirectory:[self baseRemotePath]];
    
    return result;
}

/*  Exporting shouldn't require any authentication
 */
- (void)connection:(id <CKConnection>)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
{
    [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
}

/*	Just pass on a simplified version of these 2 messages to our delegate
 */
- (void)connection:(id <CKConnection>)con uploadDidBegin:(NSString *)remotePath;
{
	[[self delegate] publishingEngine:self didBeginUploadToPath:remotePath];
}

- (void)connection:(id <CKConnection>)con upload:(NSString *)remotePath progressedTo:(NSNumber *)percent;
{
    if (![self hasFinished])
    {
        [[self delegate] publishingEngineDidUpdateProgress:self];
    }
}

/*  Once publishing is fully complete, without any errors, ping google if there is a sitemap
 */
- (void)connection:(id <CKConnection>)con didDisconnectFromHost:(NSString *)host;
{
    [self didFinish];
    [[self delegate] publishingEngineDidFinish:self];
}

/*  We either ignore the error and continue or fail and inform the delegate
 */
- (void)connection:(id <CKConnection>)con didReceiveError:(NSError *)error;
{
    if (con != [self connection]) return;
    
    
    
    if ([[error userInfo] objectForKey:ConnectionDirectoryExistsKey]) 
	{
		return; //don't alert users to the fact it already exists, silently fail
	}
	else if ([error code] == 550 || [[[error userInfo] objectForKey:@"protocol"] isEqualToString:@"createDirectory:"] )
	{
		return;
	}
	else if ([con isKindOfClass:NSClassFromString(@"WebDAVConnection")] && 
			 ([[[error userInfo] objectForKey:@"directory"] isEqualToString:@"/"] || [error code] == 409 || [error code] == 204 || [error code] == 404))
	{
		// web dav returns a 409 if we try to create / .... which is fair enough!
		// web dav returns a 204 if a file to delete is missing.
		// 404 if the file to delete doesn't exist
		
		return;
	}
	else if ([error code] == kSetPermissions) // File connection set permissions failed ... ignore this (why?)
	{
		return;
	}
	else
	{
		[self failWithError:error];
	}
}

#pragma mark -
#pragma mark Pages

/*  Uploads the site map if the site has the option enabled
 */
- (void)uploadGoogleSiteMapIfNeeded
{
    if ([[self site] boolForKey:@"generateGoogleSitemap"])
    {
        NSString *sitemapXML = [[self site] googleSiteMapXMLString];
        NSData *siteMapData = [sitemapXML dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
        NSData *gzipped = [siteMapData compressGzip];
        
        NSString *siteMapPath = [[self baseRemotePath] stringByAppendingPathComponent:@"sitemap.xml.gz"];
        [self uploadData:gzipped toPath:siteMapPath];
    }
}

/*  Semi-public method that parses the page, uploading HTML, media, resources etc. as needed.
 *  It then moves onto the next page after a short delay
 */
- (void)parseAndUploadPageIfNeeded:(KTAbstractPage *)page
{
    // Generally this method is called from -performSelector:afterDelay: so do our own exception reporting
    @try
    {
        
        [self _parseAndUploadPageIfNeeded:page];
        
        
        // Continue onto the next page if the app is licensed
        if (!gLicenseIsBlacklisted && (nil != gRegistrationString))	// License is OK
        {
            KTAbstractPage *nextPage = nil;
            
            
            // First try to publish any children or archive pages
            if ([page isKindOfClass:[KTPage class]])
            {
                NSArray *children = [(KTPage *)page sortedChildren];
                if ([children count] > 0)
                {
                    nextPage = [children objectAtIndex:0];
                }
                else
                {
                    NSArray *archives = [(KTPage *)page sortedArchivePages];
                    if ([archives count] > 0)
                    {
                        nextPage = [children objectAtIndex:0];
                    }
                }
            }
            
            
            // If there are no children, we have to search up the tree
            if (!nextPage)
            {
                nextPage = [self _pageToPublishAfterPageExcludingChildren:page];
            }
            
            
            if (nextPage)
            {
                [self performSelector:@selector(parseAndUploadPageIfNeeded:)
                           withObject:nextPage
                           afterDelay:KTParsingInterval];
                
                return;
            }
        }
        
        
        // Pages are finished, move onto the next
        
        // Upload banner image and design
        KTMaster *master = [[[self site] root] master];
        KTMediaFileUpload *bannerImage = [[[master scaledBanner] file] defaultUpload];
        if (bannerImage)
        {
            [self uploadMediaIfNeeded:bannerImage];
        }
        [self uploadDesign];
        
        
        // Upload resources
        [self uploadResourceFiles];
        
        
        // Upload sitemap if the site has one
        [self uploadGoogleSiteMapIfNeeded];
        
        
        // Once everything is uploaded, disconnect
        [[self connection] disconnect];
        
        
        // Inform the delegate
        [[self delegate] publishingEngineDidFinishGeneratingContent:self];
    }
    @catch (NSException *exception)
    {
        [NSApp reportException:exception];
        @throw;
    }
}

- (void)_parseAndUploadPageIfNeeded:(KTAbstractPage *)page
{
	OBASSERT([NSThread isMainThread]);
	
	
    // Bail early if the page is not for publishing
	NSString *uploadPath = [page uploadPath];
	if (!uploadPath) return;
	
	if ([page isKindOfClass:[KTPage class]])
	{
		// This is currently a special case to make sure Download Page media is published
		// We really ought to generalise this feature if any other plugins actually need it
		if ([[[[page plugin] bundle] bundleIdentifier] isEqualToString:@"sandvox.DownloadElement"])
		{
			KTMediaFileUpload *upload = [[page delegate] performSelector:@selector(mediaFileUpload)];
			if (upload)
			{
				[self uploadMediaIfNeeded:upload];
			}
		}
		
		// Don't publish drafts or special pages with no direct content
		if ([(KTPage *)page pageOrParentDraft] || ![(KTPage *)page shouldPublishHTMLTemplate]) return;
	}
    
    
    // Generate HTML data
	KTPage *masterPage = ([page isKindOfClass:[KTPage class]]) ? (KTPage *)page : [page parent];
	NSString *HTML = [[page contentHTMLWithParserDelegate:self isPreview:NO] stringByAdjustingHTMLForPublishing];
	OBASSERT(HTML);
	
	NSString *charset = [[masterPage master] valueForKey:@"charset"];
	NSStringEncoding encoding = [charset encodingFromCharset];
	NSData *pageData = [HTML dataUsingEncoding:encoding allowLossyConversion:YES];
	OBASSERT(pageData);
    
    
    // Give subclasses a chance to ignore the upload
    NSData *digest = nil;
    if (![self shouldUploadHTML:HTML encoding:encoding forPage:page toPath:uploadPath digest:&digest])
    {
        return;
    }
    
    
    
    // Upload page data. Store the page and its digest with the record for processing later
    NSString *fullUploadPath = [[self baseRemotePath] stringByAppendingPathComponent:uploadPath];
	if (fullUploadPath)
    {
		CKTransferRecord *transferRecord = [self uploadData:pageData toPath:fullUploadPath];
        OBASSERT(transferRecord);
        
        if (digest)
        {
            [transferRecord setProperty:page forKey:@"object"];
            [transferRecord setProperty:digest forKey:@"dataDigest"];
            [transferRecord setProperty:uploadPath forKey:@"path"];
        }
	}
    
    
	// Ask the delegate for any extra resource files that the parser didn't catch
    if ([page isKindOfClass:[KTPage class]])
    {
        NSMutableSet *resources = [[NSMutableSet alloc] init];
        [(KTPage *)page makeComponentsPerformSelector:@selector(addResourcesToSet:forPage:) 
                                           withObject:resources 
                                             withPage:(KTPage *)page 
                                            recursive:NO];
        
        NSEnumerator *resourcesEnumerator = [resources objectEnumerator];
        NSString *aResourcePath;
        while (aResourcePath = [resourcesEnumerator nextObject])
        {
            [self addResourceFile:[NSURL fileURLWithPath:aResourcePath]];
        }
        
        [resources release];
    }
	
	
    
	// Generate and publish RSS feed if needed
	if ([page isKindOfClass:[KTPage class]] && [page boolForKey:@"collectionSyndicate"] && [(KTPage *)page collectionCanSyndicate])
	{
		NSString *RSSString = [(KTPage *)page RSSFeedWithParserDelegate:self];
		if (RSSString)
		{			
			// Now that we have page contents in unicode, clean up to the desired character encoding.
			NSData *RSSData = [RSSString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
			OBASSERT(RSSData);
			
			NSString *RSSFilename = [[NSUserDefaults standardUserDefaults] objectForKey:@"RSSFileName"];
			NSString *RSSUploadPath = [[fullUploadPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:RSSFilename];
			[self uploadData:RSSData toPath:RSSUploadPath];
		}
	}
}

/*  Support method for determining which page to publish next. Only searches UP the tree.
 */
- (KTPage *)_pageToPublishAfterPageExcludingChildren:(KTAbstractPage *)page
{
    OBPRECONDITION(page);
    
    KTPage *result = nil;
    
    KTPage *parent = [page parent];
    NSArray *siblings = [parent sortedChildren];
    unsigned nextIndex = [siblings indexOfObjectIdenticalTo:page] + 1;
    if (nextIndex < [siblings count])
    {
        result = [siblings objectAtIndex:nextIndex];
    }
    else if (parent)
    {
        result = [self _pageToPublishAfterPageExcludingChildren:parent];
    }
    
    return result;
}

/*  Slightly messy support methid that allows KTPublishingEngine to reject publishing non-stale pages
 */
- (BOOL)shouldUploadHTML:(NSString *)HTML encoding:(NSStringEncoding)encoding forPage:(KTAbstractPage *)page toPath:(NSString *)uploadPath digest:(NSData **)outDigest;
{
    return YES;
}

#pragma mark -
#pragma mark Media

- (NSSet *)uploadedMedia
{
    return [[_uploadedMedia copy] autorelease];
}

/*  Adds the media file to the upload queue (if it's not already in it)
 */
- (void)uploadMediaIfNeeded:(KTMediaFileUpload *)media
{
    if (![_uploadedMedia containsObject:media])    // Don't bother if it's already in the queue
    {
        NSString *sourcePath = [[media valueForKey:@"file"] currentPath];
        NSString *uploadPath = [[self baseRemotePath] stringByAppendingPathComponent:[media pathRelativeToSite]];
        if (sourcePath && uploadPath)
        {
            // Upload the media. Store the media object with the transfer record for processing later
            CKTransferRecord *transferRecord = [self uploadContentsOfURL:[NSURL fileURLWithPath:sourcePath] toPath:uploadPath];
            [transferRecord setProperty:media forKey:@"object"];
            
            // Record that we're uploading the object
            [_uploadedMedia addObject:media];
        }
    }
}

/*  Upload the media if needed
 */
- (void)HTMLParser:(KTHTMLParser *)parser didParseMediaFile:(KTMediaFile *)mediaFile upload:(KTMediaFileUpload *)upload;	
{
    [self uploadMediaIfNeeded:upload];
}

#pragma mark -
#pragma mark Design

- (void)uploadDesign
{
    KTDesign *design = [[[[self site] root] master] design];
    
    
    // Create the design directory
	NSString *remoteDesignDirectoryPath = [[self baseRemotePath] stringByAppendingPathComponent:[design remotePath]];
	CKTransferRecord *designTransferRecord = [self createDirectory:remoteDesignDirectoryPath];
    [designTransferRecord setProperty:design forKey:@"object"];
    
    
    // Upload the design's resources
	NSEnumerator *resourcesEnumerator = [[design resourceFileURLs] objectEnumerator];
	NSURL *aResource;
	while (aResource = [resourcesEnumerator nextObject])
	{
		NSString *filename = [aResource lastPathComponent];
        if (![filename isEqualToString:@"main.css"])    // We handle uploading CSS separately
        {
            NSString *uploadPath = [remoteDesignDirectoryPath stringByAppendingPathComponent:filename];
            [self uploadContentsOfURL:aResource toPath:uploadPath];
        }
	}
}

- (void)_uploadMainCSSAndGraphicalText:(NSURL *)mainCSSFileURL remoteDesignDirectoryPath:(NSString *)remoteDesignDirectoryPath
{
    NSMutableString *mainCSS = [NSMutableString stringWithContentsOfURL:mainCSSFileURL];
    
    // Add on CSS for each block
    NSDictionary *graphicalTextBlocks = [self graphicalTextBlocks];
    NSEnumerator *textBlocksEnumerator = [graphicalTextBlocks keyEnumerator];
    NSString *aGraphicalTextID;
    while (aGraphicalTextID = [textBlocksEnumerator nextObject])
    {
        KTHTMLTextBlock *aTextBlock = [graphicalTextBlocks objectForKey:aGraphicalTextID];
        KTMediaFile *aGraphicalText = [[aTextBlock graphicalTextMedia] file];
        
        NSString *path = [[NSBundle mainBundle] overridingPathForResource:@"imageReplacementEntry" ofType:@"txt"];
        OBASSERT(path);
        
        NSMutableString *CSS = [NSMutableString stringWithContentsOfFile:path usedEncoding:NULL error:NULL];
        if (CSS)
        {
            [CSS replace:@"_UNIQUEID_" with:aGraphicalTextID];
            [CSS replace:@"_WIDTH_" with:[NSString stringWithFormat:@"%i", [aGraphicalText integerForKey:@"width"]]];
            [CSS replace:@"_HEIGHT_" with:[NSString stringWithFormat:@"%i", [aGraphicalText integerForKey:@"height"]]];
            
            NSString *baseMediaPath = [[aGraphicalText defaultUpload] pathRelativeToSite];
            NSString *mediaPath = [@".." stringByAppendingPathComponent:baseMediaPath];
            [CSS replace:@"_URL_" with:mediaPath];
            
            [mainCSS appendString:CSS];
        }
        else
        {
            NSLog(@"Unable to read in image replacement CSS from %@", path);
        }
    }
    
    
    // Upload the CSS
    NSData *mainCSSData = [[mainCSS unicodeNormalizedString] dataUsingEncoding:NSUTF8StringEncoding
                                                          allowLossyConversion:YES];
    [self uploadData:mainCSSData toPath:[remoteDesignDirectoryPath stringByAppendingPathComponent:@"main.css"]];
}

/*	Upload graphical text media
 */
- (void)HTMLParser:(KTHTMLParser *)parser didParseTextBlock:(KTHTMLTextBlock *)textBlock
{
	KTMediaFileUpload *media = [[[textBlock graphicalTextMedia] file] defaultUpload];
	if (media)
	{
		//[self addGraphicalTextBlock:textBlock];
		[self uploadMediaIfNeeded:media];
	}
}

#pragma mark -
#pragma mark Resource Files

- (NSSet *)resourceFiles
{
    return [[_resourceFiles copy] autorelease];
}

- (void)addResourceFile:(NSURL *)resourceURL
{
    resourceURL = [resourceURL absoluteURL];    // Ensures hashing and -isEqual: work right
    
    if (![_resourceFiles containsObject:resourceURL])
    {
        [_resourceFiles addObject:resourceURL];
    }
}

- (void)HTMLParser:(KTHTMLParser *)parser didEncounterResourceFile:(NSURL *)resourceURL
{
	OBPRECONDITION(resourceURL);
    [self addResourceFile:resourceURL];
}

/*  Takes all the queued up resource files and uploads them. KTRemotePublishingEngine uses this as
 *  the cut-in point for if there are no changes to publish.
 */
- (void)uploadResourceFiles
{
    NSString *resourcesDirectoryName = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultResourcesPath"];
    NSString *resourcesDirectoryPath = [[self baseRemotePath] stringByAppendingPathComponent:resourcesDirectoryName];
    
    NSEnumerator *resourcesEnumerator = [[self resourceFiles] objectEnumerator];
    NSURL *aResource;
    while (aResource = [resourcesEnumerator nextObject])
    {
        NSString *resourceRemotePath = [resourcesDirectoryPath stringByAppendingPathComponent:[aResource lastPathComponent]];
        
        [self uploadContentsOfURL:aResource toPath:resourceRemotePath];
    }
}

#pragma mark -
#pragma mark Uploading Support

/*	Use these methods instead of asking the connection directly. They will handle creating the
 *  appropriate directories first if needed.
 */
- (CKTransferRecord *)uploadContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath
{
	OBPRECONDITION(localURL);
    OBPRECONDITION([localURL isFileURL]);
    OBPRECONDITION(remotePath);
    
    
    // Is the URL actually a directory? If so, upload its contents
    BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[localURL path] isDirectory:&isDirectory] && isDirectory)
    {
        NSArray *subpaths = [[NSFileManager defaultManager] directoryContentsAtPath:[localURL path]];
        NSEnumerator *subpathsEnumerator = [subpaths objectEnumerator];
        NSString *aSubPath;
        while (aSubPath = [subpathsEnumerator nextObject])
        {
            NSURL *aURL = [localURL URLByAppendingPathComponent:aSubPath isDirectory:NO];
            NSString *aRemotePath = [remotePath stringByAppendingPathComponent:aSubPath];
            [self uploadContentsOfURL:aURL toPath:aRemotePath];
        }
        
        return nil;
    }
    
    
    // Create all required directories. Need to use -setName: otherwise the record will have the full path as its name
    CKTransferRecord *parent = [self createDirectory:[remotePath stringByDeletingLastPathComponent]];
	CKTransferRecord *result = [[self connection] uploadFile:[localURL path] toFile:remotePath checkRemoteExistence:NO delegate:nil];
    [result setName:[remotePath lastPathComponent]];
    [parent addContent:result];
    
    // Also set permissions for the file
    [[self connection] setPermissions:[self remoteFilePermissions] forFile:remotePath];
    
    return result;
    
}

- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)remotePath
{
	OBPRECONDITION(data);
    OBPRECONDITION(remotePath);
    
    
    CKTransferRecord *parent = [self createDirectory:[remotePath stringByDeletingLastPathComponent]];
	
    id <CKConnection> connection = [self connection];
    OBASSERT(connection);
    CKTransferRecord *result = [connection uploadFromData:data toFile:remotePath checkRemoteExistence:NO delegate:nil];
    OBASSERT(result);
    [result setName:[remotePath lastPathComponent]];
    
    [parent addContent:result];
    
    [connection setPermissions:[self remoteFilePermissions] forFile:remotePath];
    
    return result;
}

/*  Creates the specified directory including any parent directories that haven't already been queued for creation.
 *  Returns a CKTransferRecord used to represent the directory during publishing.
 */
- (CKTransferRecord *)createDirectory:(NSString *)remotePath
{
    OBPRECONDITION(remotePath);
    
    
    CKTransferRecord *root = [self rootTransferRecord];
    OBASSERT(root);
    if ([[root path] isEqualToString:remotePath]) return root;
    
    
    // Ensure the parent directory is created first
    NSString *parentDirectoryPath = [remotePath stringByDeletingLastPathComponent];
    OBASSERT(![parentDirectoryPath isEqualToString:remotePath]);
    CKTransferRecord *parent = [self createDirectory:parentDirectoryPath];
    
    
    // Create the directory if it hasn't been already
    CKTransferRecord *result = nil;
    int i;
    for (i = 0; i < [[parent contents] count]; i++)
    {
        CKTransferRecord *aRecord = [[parent contents] objectAtIndex:i];
        if ([[aRecord path] isEqualToString:remotePath])
        {
            result = aRecord;
            break;
        }
    }
    
    if (!result)
    {
        // This code will not set permissions for the document root or its parent directories as the
        // document root is created before this code gets called
        [[self connection] createDirectory:remotePath permissions:[self remoteDirectoryPermissions]];
        result = [CKTransferRecord recordWithName:[remotePath lastPathComponent] size:0];
        [parent addContent:result];
    }
    
    return result;
}

/*  The POSIX permissions that should be applied to files and folders on the server.
 */

- (unsigned long)remoteFilePermissions
{
    unsigned long result = 0;
    
    NSString *perms = [[NSUserDefaults standardUserDefaults] stringForKey:@"pagePermissions"];
    if (perms)
    {
        if (![perms hasPrefix:@"0"])
        {
            perms = [NSString stringWithFormat:@"0%@", perms];
        }
        char *num = (char *)[perms UTF8String];
        unsigned int p;
        sscanf(num,"%o",&p);
        result = p;
    }
    
    // Fall back
    if (result == 0)
    {
        result = 0644;
    }
    
    
    return result;
}

- (unsigned long)remoteDirectoryPermissions
{
    unsigned long result = ([self remoteFilePermissions] | 0111);
    return result;
}

@end

