//
//  KTMediaManager+MediaFiles.m
//  Marvel
//
//  Created by Mike on 07/04/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTMediaManager+Internal.h"
#import "KTMediaFile+Internal.h"
#import "KTMediaFileEqualityTester.h"

#import "KT.h"
#import "KTDocument.h"
#import "KTDocumentInfo.h"

#import "NSArray+Karelia.h"
#import "NSData+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSManagedObjectModel+KTExtensions.h"
#import "NSString+Karelia.h"

#import "BDAlias.h"

#import <Connection/KTLog.h>

#import "Debug.h"


@interface KTMediaManager (MediaFilesPrivate)

// New media files
- (KTMediaFile *)mediaFileWithPath:(NSString *)path external:(BOOL)isExternal;

- (NSArray *)inDocumentMediaFilesWithDigest:(NSString *)digest;
- (KTInDocumentMediaFile *)inDocumentMediaFileForPath:(NSString *)path;
- (KTInDocumentMediaFile *)insertTemporaryMediaFileWithPath:(NSString *)path;

// Conversion
- (KTInDocumentMediaFile *)inDocumentMediaFileToReplaceExternalMedia:(KTExternalMediaFile *)original;

@end


#pragma mark -


@implementation KTMediaManager (MediaFiles)

#pragma mark -
#pragma mark Queries

/*	Searches for an external media file whose alias matches the supplied path.
 */
- (KTExternalMediaFile *)anyExternalMediaFileMatchingPath:(NSString *)path
{
	KTExternalMediaFile *result = nil;
	
	NSEnumerator *mediaEnumerator = [[self externalMediaFiles] objectEnumerator];
	KTExternalMediaFile *aMediaFile;
	while (aMediaFile = [mediaEnumerator nextObject])
	{
		BDAlias *anAlias = [aMediaFile alias];
		if ([[anAlias lastKnownPath] isEqualToString:path] &&
			[[anAlias fullPath] isEqualToString:path])
		{
			result = aMediaFile;
			break;
		}
	}
	
	return result;
}

- (NSArray *)externalMediaFiles
{
	NSError *error = nil;
	NSArray *result = [[self managedObjectContext] allObjectsWithEntityName:@"ExternalMediaFile" error:&error];
	if (error) {
		[[NSAlert alertWithError:error] runModal];
	}
	
	return result;
}

/*	NSManagedObjectContext gives us a nice list of inserted (temporary) objects. We just have to narrow it down to those of
 *	the KTInDocumentMediaFile class.
 */
- (NSSet *)temporaryMediaFiles
{
	NSMutableSet *result = [NSMutableSet set];
	
	NSEnumerator *insertedObjectsEnumerator = [[[self managedObjectContext] insertedObjects] objectEnumerator];
	id anInsertedObject;
	while (anInsertedObject = [insertedObjectsEnumerator nextObject])
	{
		if ([anInsertedObject isKindOfClass:[KTInDocumentMediaFile class]])	// Ignore external media
		{
			[result addObject:anInsertedObject];
		}
	}
	
	return result;
}

/*	Returns the first available unique filename
 */
- (NSString *)uniqueInDocumentFilename:(NSString *)preferredFilename;
{
	NSString *result = preferredFilename;
	
	NSString *fileName = [preferredFilename stringByDeletingPathExtension];
	NSString *extension = [preferredFilename pathExtension];
	unsigned count = 1;
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:[[[self class] managedObjectModel] entityWithName:@"InDocumentMediaFile"]];
	[fetchRequest setFetchLimit:1];
	[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"filename LIKE[c] %@", result]];
	
	
	// Loop through, only ending when the file doesn't exist
	while ([[[self managedObjectContext] executeFetchRequest:fetchRequest error:NULL] count] > 0)
	{
		count++;
		NSString *aFileName = [NSString stringWithFormat:@"%@-%u", fileName, count];
		OBASSERT(extension);
		result = [aFileName stringByAppendingPathExtension:extension];
		[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"filename LIKE[c] %@", result]];
	}
	
	
	// Tidy up
	[fetchRequest release];
	return result;
}

#pragma mark -
#pragma mark Creating/Locating MediaFiles

/*	Used to add new media files to the DB.
 *	The media manager will automatically decide whether to add the file as external or temporary media.
 */
- (KTMediaFile *)mediaFileWithPath:(NSString *)path
{
	KTMediaFile *result = [self mediaFileWithPath:path external:[self mediaFileShouldBeExternal:path]];
	return result;
}

/*	Basically the same as the above method, but allows the expression of a preference as to where the underlying file is stored
 */
- (KTMediaFile *)mediaFileWithPath:(NSString *)path preferExternalFile:(BOOL)preferExternal
{
	// For the time being we shall always obey the preference
	KTMediaFile *result = [self mediaFileWithPath:path external:preferExternal];
	return result;
}

/*	Does the work for the above two methods. The storage type is ALWAYS obeyed.
 */
- (KTMediaFile *)mediaFileWithPath:(NSString *)path external:(BOOL)isExternal
{
	KTMediaFile *result = nil;
	
	if (isExternal)
	{
		result = [self anyExternalMediaFileMatchingPath:path];
		if (!result)
		{
			KTLog(KTMediaLogDomain, KTLogDebug, ([NSString stringWithFormat:@"Creating external MediaFile for path:\r%@", path]));
			result = [KTExternalMediaFile insertNewMediaFileWithPath:path inManagedObjectContext:[self managedObjectContext]];
		}
	}
	else
	{
		result = [self inDocumentMediaFileForPath:path];
	}
	
	OBPOSTCONDITION(result);
	return result;
}

- (KTInDocumentMediaFile *)mediaFileWithData:(NSData *)data preferredFilename:(NSString *)preferredFilename
{
	KTInDocumentMediaFile *result = nil;
	
	// See if there is already a MediaFile with the same data
	NSArray *similarMediaFiles = [self inDocumentMediaFilesWithDigest:[data partiallyDigestString]];
	
	NSEnumerator *mediaFilesEnumerator = [similarMediaFiles objectEnumerator];
	KTInDocumentMediaFile *aMediaFile;
	while (aMediaFile = [mediaFilesEnumerator nextObject])
	{
		NSData *possibleMatch = [NSData dataWithContentsOfFile:[aMediaFile currentPath]];
		if ([possibleMatch isEqualToData:data])
		{
			result = aMediaFile;
			break;
		}
	}
	
	// No existing match was found so create a new MediaFile
	if (!result)
	{
		// Write out the file
		NSString *filename = [self uniqueInDocumentFilename:preferredFilename];
		NSString *destinationPath = [[[self document] temporaryMediaPath] stringByAppendingPathComponent:filename];
		
		KTLog(KTMediaLogDomain, KTLogDebug,
              ([NSString stringWithFormat:@"Creating temporary in-document MediaFile from data named '%@'", filename]));
		
		NSError *error = nil;
		[data writeToFile:destinationPath options:0 error:&error];
		if (error) {
			[[NSAlert alertWithError:error] runModal];
		}
		
		// Then add the object to the DB
		result = [KTInDocumentMediaFile insertNewMediaFileWithPath:destinationPath
											inManagedObjectContext:[self managedObjectContext]];
		
		[result setValue:preferredFilename forKey:@"sourceFilename"];
	}
	
	
	return result;
}

- (KTInDocumentMediaFile *)mediaFileWithImage:(NSImage *)image
{
	OBPRECONDITION(image);
	OBPRECONDITION([[image representations] count] > 0);
	
	// Figure out the filename to use
	NSString *imageUTI = [image preferredFormatUTI];
	OBASSERT(imageUTI);
	NSString *extension = [NSString filenameExtensionForUTI:imageUTI];
	OBASSERT(extension);
	NSString *filename = [@"pastedImage" stringByAppendingPathExtension:extension];
	NSData *imageData = [image representationForUTI:imageUTI];
	
	KTInDocumentMediaFile *result = [self mediaFileWithData:imageData preferredFilename:filename];
	return result;
}

- (KTMediaFile *)mediaFileWithDraggingInfo:(id <NSDraggingInfo>)info preferExternalFile:(BOOL)preferExternal
{
	KTMediaFile *result = nil;
	
	if ([[[info draggingPasteboard] types] containsObject:NSFilenamesPboardType])
	{
		NSString *path = [[[info draggingPasteboard] propertyListForType:NSFilenamesPboardType] firstObject];
		if (path)
		{
			result = [self mediaFileWithPath:path preferExternalFile:preferExternal];
		}
	}
	// TODO: Support drag sources other than files
	
	return result;
}

#pragma mark -
#pragma mark In-document Media Files

- (NSArray *)inDocumentMediaFilesWithDigest:(NSString *)digest
{
	// Search the DB for matching digests
	NSFetchRequest *fetchRequest = [[[self class] managedObjectModel]
									fetchRequestFromTemplateWithName:@"MediaFilesWithDigest"
									substitutionVariable:digest forKey:@"DIGEST"];
	
	NSError *error = nil;
	NSArray *result = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
	if (error) {
		[[NSAlert alertWithError:error] runModal];
	}
	
	return result;
}

/*	Look to see if there is an existing equivalent media file. If so, return that. Otherwise create a new one.
 */
- (KTInDocumentMediaFile *)inDocumentMediaFileForPath:(NSString *)path
{
	OBPRECONDITION(path);
    
    KTInDocumentMediaFile *result = nil;
	
	
	// Search the DB for matching digests. This gives us a rough set of results.
	NSArray *similarMedia = [self inDocumentMediaFilesWithDigest:[NSData partiallyDigestStringFromContentsOfFile:path]];
	if ([similarMedia count] > 0)
	{
		NSEnumerator *matchEnumerator = [similarMedia objectEnumerator];
		KTInDocumentMediaFile *aMediaFile;
		while (aMediaFile = [matchEnumerator nextObject])
		{
			if ([[NSFileManager defaultManager] contentsEqualAtPath:path andPath:[aMediaFile currentPath]])
			{
				result = aMediaFile;
				break;
			}
		}
	}
	
	
	// No match was found so create a new MediaFile
	if (!result)
	{
		result = [self insertTemporaryMediaFileWithPath:path];
	}
	
	return result;
}

/*	Support method that ensures the temporary media directory does not already contain a file with the same name
 */
- (BOOL)prepareTemporaryMediaDirectoryForFileNamed:(NSString *)filename
{
	// See if there's already a file there
	NSString *proposedPath = [[[self document] temporaryMediaPath] stringByAppendingPathComponent:filename];
	BOOL result = !([[NSFileManager defaultManager] fileExistsAtPath:proposedPath]);
	
	// If there is an existing file, try to delete it. Log the operation for debugging purposes
	if (!result)
	{
		int tag = 0;
		result = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
															  source:[proposedPath stringByDeletingLastPathComponent]
														 destination:@""
															   files:[NSArray arrayWithObject:filename]
															     tag:&tag]; 
		
		NSString *message = [NSString stringWithFormat:@"Preparing for temporary media file at\n%@\nbut one already exists. %@",
                             proposedPath,
                             (result) ? @"It was moved to the trash." : @"It could not be deleted."];
		KTLog(KTMediaLogDomain, (result) ? KTLogWarn : KTLogError, message);
	}
	
	return result;
}

/*	Creates a brand new entry in the DB for the media at the path.
 *	The path itself is copied to app support as a temporary store; it is moved internally at save-time.
 */
- (KTInDocumentMediaFile *)insertTemporaryMediaFileWithPath:(NSString *)path
{
	KTInDocumentMediaFile *result = nil;
    
    
    KTLog(KTMediaLogDomain, KTLogDebug, ([NSString stringWithFormat:@"Creating temporary in-document MediaFile from path:\r%@", path]));
	
	// Figure out the filename and copy the file there
	NSString *sourceFilename = [path lastPathComponent];
	NSString *destinationFilename = [self uniqueInDocumentFilename:sourceFilename];
	NSString *destinationPath = [[[self document] temporaryMediaPath] stringByAppendingPathComponent:destinationFilename];
	
	[self prepareTemporaryMediaDirectoryForFileNamed:destinationFilename];
	if ([[NSFileManager defaultManager] copyPath:path toPath:destinationPath handler:self])
    {
        // Add the file to the DB.
        result = [KTInDocumentMediaFile insertNewMediaFileWithPath:destinationPath
                                            inManagedObjectContext:[self managedObjectContext]];
		
        // Store the file's source filename
        [result setValue:sourceFilename forKey:@"sourceFilename"];
    }
    else
    {
        KTLog(KTMediaLogDomain,
              KTLogError,
              ([NSString stringWithFormat:@"Unable to create in-document MediaFile. The path may not exist:\r%@", path]));
    }
    
	return result;
    
}


#pragma mark -
#pragma mark Conversion

/*	Convert any external media files to internal if the document's settings recommend it.
 */
- (void)moveApplicableExternalMediaInDocument
{
	NSArray *externalMediaFiles = [self externalMediaFiles];
	NSEnumerator *mediaFileEnumerator = [externalMediaFiles objectEnumerator];
	KTExternalMediaFile *aMediaFile;
	
	while (aMediaFile = [mediaFileEnumerator nextObject])
	{
		if (![self mediaFileShouldBeExternal:[aMediaFile currentPath]])
		{
			[self inDocumentMediaFileToReplaceExternalMedia:aMediaFile];
		}
	}
}

/*  Attempts to move a given file into the document. Returns nil if this fails (e.g. the file can't be located).
 */
- (KTInDocumentMediaFile *)inDocumentMediaFileToReplaceExternalMedia:(KTExternalMediaFile *)original
{
	OBPRECONDITION(original);
	
	KTInDocumentMediaFile *result = nil;
    
    
	// Get the replacement file.
	NSString *path = [original currentPath];
    if (path)
    {
        result = [self inDocumentMediaFileForPath:path];
        OBASSERT(result);
        
        
        // Migrate relationships
        [[result mutableSetValueForKey:@"uploads"] unionSet:[original valueForKey:@"uploads"]];
        [[result mutableSetValueForKey:@"scaledImages"] unionSet:[original valueForKey:@"scaledImages"]];
        [[result mutableSetValueForKey:@"containers"] unionSet:[original valueForKey:@"containers"]];
	}
	
	return result;
}

#pragma mark -
#pragma mark Support

/*	Look at where the media is currently located and decide (based on the user's preference) where it should be stored.
 */
- (BOOL)mediaFileShouldBeExternal:(NSString *)path
{
	BOOL result = NO;	// The safest option so we use it as a fall back
	
	// If the user has requested the "automatic" or "reference" option we must consider the matter further
	KTCopyMediaType copyingSetting = [[[self document] documentInfo] copyMediaOriginals];
	switch (copyingSetting)
	{
		case KTCopyMediaNone:
			result = YES;
			break;
			
		case KTCopyMediaAutomatic:
			// If it's a piece of iMedia reference rather than copy it
			if ([[self class] fileConstituesIMedia:path])
			{
				result = YES;
			}
			else
			{
				result = NO;
			}
			break;
			
		case KTCopyMediaAll:
			result = NO;
			break;
	}
	
	return result;
}

/*	Determines if the file is considered to be "iMedia"
 */
+ (BOOL)fileConstituesIMedia:(NSString *)path
{
	//  anything in ~/Movies, ~/Music, or ~/Pictures is considered iMedia.
    //  NB: there appear to be no standard library functions for finding these
	//  but supposedly these names are constant and .localized files
	//  change what name appears in Finder
	
	// We resolve symbolic links so that the path of the arbitrary file added will match the actual path
	// of the home directory
	NSString *homeDirectory = NSHomeDirectory();
    NSString *moviesDirectory	= [[homeDirectory stringByAppendingPathComponent:@"Movies"] stringByResolvingSymlinksInPath];
    NSString *musicDirectory	= [[homeDirectory stringByAppendingPathComponent:@"Music"] stringByResolvingSymlinksInPath];
    NSString *picturesDirectory	= [[homeDirectory stringByAppendingPathComponent:@"Pictures"] stringByResolvingSymlinksInPath];
    
    if ( [path hasPrefix:moviesDirectory] || [path hasPrefix:musicDirectory] || [path hasPrefix:picturesDirectory] )
    {
        return YES;
    }
	
	
	//  anything in iPhoto (using defaults) is iMedia
	NSDictionary *iPhotoDefaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.iPhoto"];
	NSString *iPhotoRoot = [iPhotoDefaults valueForKey:@"RootDirectory"];	
	if (iPhotoRoot && [path hasPrefix:iPhotoRoot])
	{
		return YES;
	}
    
    
	//  anything in iTunes (using defaults) is iMedia
    static NSString *sITunesRoot = nil;
	if (!sITunesRoot)
	{
		// FIXME: the defaults key used here was determined empirically and could break!
		// FIXME: This could be very slow to resolve if this points who-knows-where.  And it doesn't save the alias back if it's changed. 
		NSDictionary *iTunesDefaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.iTunes"];
		NSString *musicFolderLocationKey = @"alis:11345:Music Folder Location";
		NSData *aliasData = [iTunesDefaults valueForKey:musicFolderLocationKey];
		BDAlias *alias = [[[BDAlias alloc] initWithData:aliasData] autorelease];
		sITunesRoot = [[alias fullPath] retain];
		//			}
	}
	if (sITunesRoot && [path hasPrefix:sITunesRoot] )
	{
		return YES;
	}
	
	
	return NO;
}

@end
