//
//  SVImage.h
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVMediaGraphic.h"


@class SVLink, SVTextAttachment;

@interface SVImage : SVMediaGraphic

+ (SVImage *)insertNewImageWithMedia:(SVMediaRecord *)media;
+ (SVImage *)insertNewImageInManagedObjectContext:(NSManagedObjectContext *)context;


#pragma mark Metrics
@property(nonatomic, copy) NSString *alternateText;


#pragma mark Link
@property(nonatomic, copy) SVLink *link;


#pragma mark Publishing

@property(nonatomic) NSBitmapImageFileType storageType;
@property(nonatomic, copy) NSString *typeToPublish;

@property(nonatomic, copy) NSNumber *compressionFactor; // float, 0-1


@end



