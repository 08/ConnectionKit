//
//  SVPageletTitleBox.m
//  Sandvox
//
//  Created by Mike on 15/03/2010.
//  Copyright 2010-11 Karelia Software. All rights reserved.
//

#import "SVPageletTitleBox.h"

#import "SVGraphic.h"
#import "SVTextAttachment.h"


@implementation SVPageletTitleBox

@dynamic pagelet;

#pragma mark Validation

- (BOOL)validateForInsert:(NSError **)error;
{
    BOOL result = [super validateForInsert:error];
    if (result && [[self pagelet] textAttachment]) result = [[[self pagelet] textAttachment] validateWrapping:error];
    return result;
}

- (BOOL)validateForUpdate:(NSError **)error;
{
    BOOL result = [super validateForUpdate:error];
    if (result && [[self pagelet] textAttachment]) result = [[[self pagelet] textAttachment] validateWrapping:error];
    return result;
}

@end
