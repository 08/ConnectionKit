//
//  SVDownloadSiteItem.m
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDownloadSiteItem.h"

#import "SVMediaRecord.h"


@implementation SVDownloadSiteItem

@dynamic media;

- (id <SVMedia>)mediaRepresentation; { return [self media]; }

@end
