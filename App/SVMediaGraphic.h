//
//  SVMediaGraphic.h
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"


@class SVMediaRecord;

@interface SVMediaGraphic : SVGraphic

#pragma mark Media

@property(nonatomic, retain) SVMediaRecord *media;
- (void)setMediaWithURL:(NSURL *)URL;

@property(nonatomic, copy) NSURL *externalSourceURL;

- (BOOL)hasFile;    // for bindings


#pragma mark Size

// If -constrainProportions returns YES, these 3 methods will adjust image size to maintain proportions
@property(nonatomic, copy)  NSNumber *width;
@property(nonatomic, copy)  NSNumber *height;
- (void)setSize:(NSSize)size;

@property(nonatomic)        BOOL constrainProportions;

- (CGSize)originalSize;
- (void)makeOriginalSize;
- (BOOL)canMakeOriginalSize;


@end
