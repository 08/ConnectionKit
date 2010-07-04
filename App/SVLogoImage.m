//
//  SVLogoImage.m
//  Sandvox
//
//  Created by Mike on 02/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVLogoImage.h"

#import "NSManagedObject+KTExtensions.h"


@implementation SVLogoImage

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    [self setPrimitiveValue:[NSNumber numberWithUnsignedInt:200] forKey:@"width"];
    [self setPrimitiveValue:[NSNumber numberWithUnsignedInt:128] forKey:@"height"];
}

- (void)createDefaultIntroAndCaption; { }

@dynamic hidden;

- (SVTitleBox *)titleBox { return nil; }
- (void)setTitle:(NSString *)title; { }
- (SVAuxiliaryPageletText *)introduction { return nil; }
- (void)setIntroduction:(SVAuxiliaryPageletText *)caption { }
- (SVAuxiliaryPageletText *)caption { return nil; }
- (void)setCaption:(SVAuxiliaryPageletText *)caption { }

- (NSNumber *)placement { return nil; }
- (BOOL)isPlacementEditable; { return NO; }
- (SVTextAttachment *)textAttachment { return nil; }

- (NSURL *)imagePreviewURL; // picks out URL from media, sourceURL etc.
{
    NSURL *result = [super imagePreviewURL];
    
    if (!result & ![self media])
    {
        result = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForImageResource:@"LogoPlaceholder"]];
    }
    
    return result;
}

#pragma mark HTML

- (void)writeHTML:(SVHTMLContext *)context;
{
    // We're special; do our HTML writing.
    // Only selectable if on home-page
    
    BOOL isSelectable = ([[context page] isRootPage]);
    if (isSelectable) [context willBeginWritingGraphic:self];
    
    [self writeBody:context];
    
    if (isSelectable) [context didEndWritingGraphic];
}

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Correct entity to Image
    [propertyList setObject:@"Image" forKey:@"entity"];
}

@end
