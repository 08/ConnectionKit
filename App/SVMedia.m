//
//  SVMedia.m
//  Sandvox
//
//  Created by Mike on 27/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMedia.h"
#import "SVMediaProtocol.h"

#import "NSFileManager+Karelia.h"
#import "NSString+Karelia.h"
#import "KSURLUtilities.h"
#import "QTMovie+Karelia.h"


@implementation SVMedia

#pragma mark Init & Dealloc

- (id)initByReferencingURL:(NSURL *)fileURL;
{
    OBPRECONDITION(fileURL);
    [self init];
    
    _fileURL = [fileURL copy];
    [self setPreferredFilename:[fileURL ks_lastPathComponent]];
    
    return self;
}

- (id)initWithContentsOfURL:(NSURL *)URL error:(NSError **)outError;
{
    [self init];
    
    NSData *data = [[NSData alloc] initWithContentsOfURL:URL options:0 error:outError];
    if (data)
    {
        self = [self initWithData:data URL:URL];
        _fileURL = [URL copy];
        [data release];
    }
    else
    {
        [self release]; self = nil;
    }
    
    return self;
}

- (id)initWithWebResource:(WebResource *)resource;
{
    OBPRECONDITION(resource);
    [self init];
    
    _webResource = [resource copy];
    [self setPreferredFilename:[[resource URL] ks_lastPathComponent]];
    
    return self;
}

- (id)initWithData:(NSData *)data URL:(NSURL *)url;
{
    NSString *type = [NSString MIMETypeForUTI:
                      [NSString UTIForFilenameExtension:[url ks_pathExtension]]];
    
    WebResource *resource = [[WebResource alloc] initWithData:data
                                                          URL:url
                                                     MIMEType:type
                                             textEncodingName:nil
                                                    frameName:nil];
    
    self = [self initWithWebResource:resource];
    [resource release];
    return self;
}

- (void)dealloc;
{
    [_fileURL release];
    [_webResource release];
    [_preferredFilename release];
    
    [super dealloc];
}

#pragma mark Properties

@synthesize fileURL = _fileURL;
@synthesize webResource = _webResource;

- (NSURL *)mediaURL;
{
    NSURL *result = [[self webResource] URL];
    if (!result) result = [self fileURL];
    return result;
}
- (NSData *)mediaData;
{
    return [_webResource data];
}

@synthesize preferredFilename = _preferredFilename;

- (NSString *)preferredUploadPath;
{
    NSString *result = [@"_Media" stringByAppendingPathComponent:
                        [[self preferredFilename] legalizedWebPublishingFilename]];
    
    if ([[result pathExtension] isEqualToString:@"jpg"])    // #91088
    {
        result = [[result stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpeg"];
    }
    
    return result;
}

- (id)imageRepresentation
{
    return (nil != [self mediaData]
            ? (id)[self mediaData] 
            : (id)[self mediaURL]);
}

- (NSString *)imageRepresentationType
{
    return ([self mediaData] 
            ? IKImageBrowserNSDataRepresentationType 
            : IKImageBrowserNSURLRepresentationType);
}

- (BOOL)isEqual:(id)object;
{
    if ([object conformsToProtocol:@protocol(SVMedia)])
    {
        return [self isEqualToMedia:object];
    }
    
    return NO;
}

- (BOOL)isEqualToMedia:(id <SVMedia>)otherMedia;
{
    return ([[self mediaURL] ks_isEqualToURL:[otherMedia mediaURL]] ||
            [[self mediaData] isEqualToData:[otherMedia mediaData]]);
}

- (NSUInteger)hash; { return 0; }

#pragma mark Comparing Media

- (BOOL)fileContentsEqualMedia:(SVMedia *)otherMedia;
{
    NSURL *otherURL = [otherMedia fileURL];
    
    // If already in-memory might as well use it. If without a file URL, have no choice!
    if (!otherURL || [otherMedia mediaData])
    {
        NSData *data = [NSData newDataWithContentsOfMedia:otherMedia];
        
        BOOL result = [self fileContentsEqualData:data];
        [data release];
        return result;
    }
    else
    {
        return [self fileContentsEqualContentsOfURL:otherURL];
    }
}

- (BOOL)fileContentsEqualContentsOfURL:(NSURL *)otherURL;
{
    BOOL result = NO;
    
    NSURL *URL = [self fileURL];
    if (URL)
    {
        result = [[NSFileManager defaultManager] contentsEqualAtPath:[otherURL path]
                                                             andPath:[URL path]];
    }
    else
    {
        // Fallback to comparing data. This could be made more efficient by looking at the file size before reading in from disk
        NSData *data = [self mediaData];
        result = [[NSFileManager defaultManager] ks_contents:data equalContentsAtURL:otherURL];
    }
    
    return result;
}

- (BOOL)fileContentsEqualData:(NSData *)otherData;
{
    BOOL result = NO;
    
    NSData *data = [NSData newDataWithContentsOfMedia:self];
    
    result = [data isEqualToData:otherData];
    
    [data release];
    return result;
}

#pragma mark Writing Files

- (BOOL)writeToURL:(NSURL *)URL error:(NSError **)outError;
{
    // Try writing out data from memory. It'll fail if there was none
    NSData *data = [self mediaData];
    BOOL result = [data writeToURL:URL options:0 error:outError];
    if (!result)
    {
        // Fallback to copying the file
        result = [[NSFileManager defaultManager] copyItemAtPath:[[self fileURL] path]
                                                         toPath:[URL path]
                                                          error:outError];
    }
    
    
    return result;
}

#pragma mark Deprecated

- (NSString *)typeOfFile
{
	NSString *fileName = [self preferredFilename];
	NSString *UTI = [NSString UTIForFilenameExtension:[fileName pathExtension]];
	return UTI;
}

- (CGSize)originalSize;
{
    CGSize result = CGSizeZero;
    
	if ([[self typeOfFile] conformsToUTI:(NSString *)kUTTypeImage])
	{
		result = IMBImageItemGetSize((id)self);
	}
	else if ([[self typeOfFile] conformsToUTI:(NSString *)kUTTypeMovie])
	{
		NSSize dimensions = [QTMovie dimensionsOfMovieWithIMBImageItem:(id)self];
		result = NSSizeToCGSize(dimensions);
    }
	else if ([[self typeOfFile] conformsToUTI:@"com.adobe.shockwave-flash"])
	{
		NSLog(@"Um, why do we have to get the dimension this way when we already set it ?");
    }
	else
	{
		NSLog(@"Unknown file type %@ for media", [self typeOfFile]);
	}
    
    return result;
}

@end


#pragma mark -


@implementation NSData (SVMedia)

+ (NSData *)newDataWithContentsOfMedia:(id <SVMedia>)media;
{
    NSData *result = [[media mediaData] copy];
    if (!result) result = [[NSData alloc] initWithContentsOfURL:[media mediaURL]];
    return result;
}

@end
