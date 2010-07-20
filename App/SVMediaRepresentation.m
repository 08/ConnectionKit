//
//  SVMediaRepresentation.m
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaRepresentation.h"

#import "SVImageScalingOperation.h"
#import "KTImageScalingURLProtocol.h"


@implementation SVMediaRepresentation

- (id)initWithMediaRecord:(SVMediaRecord *)mediaRecord;
{
    [self init];
    
    _mediaRecord = [mediaRecord retain];
    
    return self;
}

- (id)initWithMediaRecord:(SVMediaRecord *)mediaRecord
                    width:(NSNumber *)width
                   height:(NSNumber *)height
                 fileType:(NSString *)type;
{
    self = [self initWithMediaRecord:mediaRecord];
    
    _width = [width copy];
    _height = [height copy];
    _type = [type copy];
    
    return self;
}

- (void)dealloc
{
    [_mediaRecord release];
    [_width release];
    [_height release];
    [_type release];
    
    [super dealloc];
}

@synthesize mediaRecord = _mediaRecord;
@synthesize width = _width;
@synthesize height = _height;
@synthesize fileType = _type;

- (BOOL)isNativeRepresentation;
{
    BOOL result = !([self width] || [self height]);
    return result;
}

- (NSData *)data;
{
    if (![self isNativeRepresentation])
    {
        NSURL *URL = [NSURL sandvoxImageURLWithFileURL:[[self mediaRecord] fileURL]
                                                  size:NSMakeSize([[self width] floatValue], [[self height] floatValue])
                                           scalingMode:KSImageScalingModeAspectFit
                                            sharpening:0.0f
                                     compressionFactor:1.0f
                                              fileType:[self fileType]];
        
        SVImageScalingOperation *op = [[SVImageScalingOperation alloc] initWithURL:URL];
        [op start];
        
        NSData *result = [op result];
        [op release];
        
        return result;
    }
    else
    {
        return [[self mediaRecord] fileContents];
    }
}

- (BOOL)isEqualToMediaRepresentation:(SVMediaRepresentation *)otherRep;
{
    BOOL result = ([[self mediaRecord] isEqual:[otherRep mediaRecord]] &&
                   KSISEQUAL([self width], [otherRep width]) &&
                   KSISEQUAL([self height], [otherRep height]) &&
                   KSISEQUAL([self fileType], [otherRep fileType]));
    return result;
}

- (BOOL)isEqual:(id)object;
{
    return (self == object ||
            ([object isKindOfClass:[SVMediaRepresentation class]] &&
             [self isEqualToMediaRepresentation:object]));
}

- (NSUInteger)hash { return [[self mediaRecord] hash]; }

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone;
{
    return [self retain];   // immutable
}

@end
