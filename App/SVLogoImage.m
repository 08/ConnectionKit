//
//  SVLogoImage.m
//  Sandvox
//
//  Created by Mike on 02/03/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVLogoImage.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"
#import "KTPage.h"

#import "NSManagedObject+KTExtensions.h"


@interface SVMediaGraphic (SVLogoImage)
- (void)setSourceWithMediaRecord:(SVMediaRecord *)media;
@end


#pragma mark -


@implementation SVLogoImage

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    NSURL *placeholderURL = [NSURL fileURLWithPath:
                             [[NSBundle mainBundle] pathForImageResource:@"LogoPlaceholder"]];
    
    [self setSourceWithMediaRecord:[SVMediaRecord mediaWithBundledURL:placeholderURL
                                                           entityName:[[self class] mediaEntityName]
                                       insertIntoManagedObjectContext:[self managedObjectContext]]];
    
    [[self plugIn] setWidth:[NSNumber numberWithUnsignedInteger:200]
                     height:[NSNumber numberWithUnsignedInteger:128]];
    
    [self makeOriginalSize];
    [self setTypeToPublish:[[self media] typeOfFile]];
}

- (SVMediaRecord *)posterFrame; { return nil; }
- (void)setPosterFrame:(SVMediaRecord *)media; { }

- (void)createDefaultIntroAndCaption; { }

+ (NSString *)mediaEntityName; { return @"LogoMedia"; }

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

- (SVLink *)link; { return NSNotApplicableMarker; }

#pragma mark Metrics

- (CGFloat)maxWidthOnPage:(KTPage *)page; { return 200.0; }

#pragma mark HTML

- (BOOL)shouldWriteHTMLInline; { return YES; }  // we're not a pagelet

- (void)writeBody:(SVHTMLContext *)context;
{
    [context pushClassName:@"logo"];
    [super writeBody:context];
}

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Correct entity to Image
    [propertyList setObject:@"Image" forKey:@"entity"];
}

@end
