// 
//  SVGraphic.m
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"

#import "SVArticle.h"
#import "SVAuxiliaryPageletText.h"
#import "KTDesign.h"
#import "SVHTMLTemplateParser.h"
#import "KTImageScalingSettings.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "SVRichText.h"
#import "SVTemplate.h"
#import "SVTextAttachment.h"
#import "SVTitleBox.h"

#import "KSWebLocation.h"
#import "KSURLUtilities.h"

#import "NSError+Karelia.h"
#import "NSString+Karelia.h"


NSString *kSVGraphicPboardType = @"com.karelia.sandvox.graphic";


@implementation SVGraphic

#pragma mark Initialization

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    
    // Text
    [self setTitle:[[self class] placeholderTitleText]];
    [self createDefaultIntroAndCaption];
}

- (void)awakeFromNew; { }

- (void)didAddToPage:(id <SVPage>)page; { }

#pragma mark Placement

- (NSNumber *)placement;
{
    SVTextAttachment *attachment = [self textAttachment];
    if (attachment) return [attachment placement];
    
    return [NSNumber numberWithInteger:SVGraphicPlacementSidebar];
}

+ (NSSet *)keyPathsForValuesAffectingPlacement;
{
    return [NSSet setWithObject:@"textAttachment.placement"];
}

- (BOOL)isPlacementEditable;    // yes for sidebar & article embedded graphics
{
    SVTextAttachment *attachment = [self textAttachment];
    BOOL result = (!attachment || [[attachment body] isKindOfClass:[SVArticle class]]);
    return result;
}

@dynamic textAttachment;

#pragma mark Pagelet

- (BOOL)shouldWriteHTMLInline; { return NO; }

// Inline graphics are not pagelets, but everything else is
- (BOOL)isPagelet;
{
    BOOL result = ([[self placement] intValue] != SVGraphicPlacementInline);
    return result;
}

- (BOOL)canWriteHTMLInline; { return NO; }

- (BOOL)isCallout;  // whether to generate enclosing <div class="callout"> etc.
{
    return ([self calloutWrapClassName] != nil);
}

- (NSString *)calloutWrapClassName; // nil if not a callout
{
    //  We are a callout if a floated pagelet
    NSString *result = nil;
    
    if ([[self placement] integerValue] == SVGraphicPlacementCallout)
    {
        result = @"";
    }
    
    return result;
}

#pragma mark Title

@dynamic titleBox;

+ (NSString *)placeholderTitleText;
{
    return NSLocalizedString(@"Pagelet", "pagelet title placeholder");
}

#pragma mark Intro & Caption

- (void)createDefaultIntroAndCaption;
{
    if ([self canHaveIntroduction])
    {
        SVAuxiliaryPageletText *text = [NSEntityDescription
                                        insertNewObjectForEntityForName:@"PageletIntroduction"
                                        inManagedObjectContext:[self managedObjectContext]];
        [self setIntroduction:text];
    }
    
    if ([self canHaveCaption])
    {
        SVAuxiliaryPageletText *text = [NSEntityDescription insertNewObjectForEntityForName:@"PageletCaption"
                                             inManagedObjectContext:[self managedObjectContext]];
        [self setCaption:text];
    }
}

@dynamic caption;
- (BOOL)validateCaption:(SVAuxiliaryPageletText **)caption error:(NSError **)error;
{
    BOOL result = ((*caption != nil) == [self canHaveCaption]);
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                     code:NSValidationMissingMandatoryPropertyError
                     localizedDescription:@"caption is non-optional"];
    }
    
    return result;
}

- (id <SVGraphic>)captionGraphic;
{
    SVAuxiliaryPageletText *result = [self caption];
    if ([[result hidden] boolValue]) result = nil;
    return result;
}

- (BOOL)canHaveCaption; { return YES; }

@dynamic introduction;
- (BOOL)validateIntroduction:(SVAuxiliaryPageletText **)introduction error:(NSError **)error;
{
    BOOL result = ((*introduction != nil) == [self canHaveIntroduction]);
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                     code:NSValidationMissingMandatoryPropertyError
                     localizedDescription:@"introduction is non-optional"];
    }
    
    return result;
}

- (BOOL)canHaveIntroduction; { return YES; }

#pragma mark Layout/Styling

@dynamic showBackground;
@dynamic showBorder;

#pragma mark Metrics

@dynamic width;
- (BOOL)validateWidth:(NSNumber **)width error:(NSError **)error;
{
    // Subclasses can override to accept smaller widths
    BOOL result = ((*width == nil) || [*width unsignedIntegerValue] >= 200);
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSValidationNumberTooSmallError localizedDescription:@"Width of standard pagelets must be 200 pixels or greater"];
    }
    
    return result;
}

@dynamic height;

- (CGFloat)maxWidthOnPage:(KTPage *)page;
{
    KTDesign *design = [[page master] design];
    
    SVGraphicPlacement placement = [[self placement] intValue];
    
    KTImageScalingSettings *settings = nil;
    switch (placement)
    {
        case SVGraphicPlacementInline:
        {
            if ([[page showSidebar] boolValue])
            {
                settings = [design imageScalingSettingsForUse:@"KTSidebarPageMedia"];
            }
            else
            {
                settings = [design imageScalingSettingsForUse:@"KTPageMedia"];
            }
            break;
        }
            
        case SVGraphicPlacementCallout:
            settings = [design imageScalingSettingsForUse:@"KTPageletMedia"];
            break;
            
        case SVGraphicPlacementSidebar:
            settings = [design imageScalingSettingsForUse:@"sidebarImage"];
            break;
    }
    OBASSERT(settings);
    
    
    CGFloat result = [settings size].width;
    return result;
}

- (NSNumber *)constrainedProportionsRatio; { return nil; }

- (void)makeOriginalSize;
{
    [self setWidth:[NSNumber numberWithInt:200]];
    [self setHeight:nil];
}

- (BOOL)canMakeOriginalSize;
{
    // Graphics can return to their original size if explicitly sized, or placed outside sidebar
    BOOL result = ([self isExplicitlySized] ||
                   [[self placement] intValue] == SVGraphicPlacementInline);
    return result;
}

- (BOOL)isExplicitlySized; { return NO; }

- (NSNumber *)contentWidth;
{
    return ([[self placement] intValue] == SVGraphicPlacementInline ?
            [self width] :
            NSNotApplicableMarker);
}
- (void)setContentWidth:(NSNumber *)width;
{
    [self setWidth:width];
}
+ (NSSet *)keyPathsForValuesAffectingContentWidth; { return [NSSet setWithObject:@"width"]; }

#pragma mark Sidebar

+ (BOOL)validateSortKeyForPagelets:(NSSet **)pagelets error:(NSError **)error;
{
    BOOL result = YES;
    
    // All our pagelets should have unique sort keys
    NSSet *sortKeys = [*pagelets valueForKey:@"sortKey"];
    if ([sortKeys count] != [*pagelets count])
    {
        result = NO;
        if (error)
        {
            NSDictionary *info = [NSDictionary dictionaryWithObject:@"Pagelet sort keys are not unique" forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSManagedObjectValidationError userInfo:info];
        }
    }
    
    return result;
}

@dynamic sortKey;

@dynamic sidebars;

#pragma mark Template

- (BOOL)wasCreatedByTemplate;
{
    return [[self valueForUndefinedKey:@"wasCreatedByTemplate"] boolValue];
}

- (void)setWasCreatedByTemplate:(BOOL)template;
{
    [self setValue:NSBOOL(template) forUndefinedKey:@"wasCreatedByTemplate"];
}

- (BOOL) usesExtensiblePropertiesForUndefinedKey:(NSString *)key;
{
    if ([key isEqualToString:@"wasCreatedByTemplate"])
    {
        return YES;
    }
    else
    {
        return [super usesExtensiblePropertiesForUndefinedKey:key];
    }
}

#pragma mark Validation

- (BOOL)validateForInsert:(NSError **)error
{
    BOOL result = [super validateForInsert:error];
    if (result && [self textAttachment]) result = [[self textAttachment] validateWrapping:error];
    
    return result;
}

- (BOOL)validateForUpdate:(NSError **)error
{
    BOOL result = [super validateForUpdate:error];
    if (result && [self textAttachment]) result = [[self textAttachment] validateWrapping:error];
    
    return result;
}

#pragma mark HTML

- (void)buildClassName:(SVHTMLContext *)context;
{
    if (![self isCallout])
    {
        SVTextAttachment *textAttachment = [self textAttachment];
        if ([[textAttachment causesWrap] boolValue])
        {
            [context pushClassName:@"graphic-container"];
            
            switch ([[textAttachment wrap] integerValue])
            {
                case SVGraphicWrapNone:
                    [context pushClassName:@"narrow"];  // fallback for imported images
                    break;
                case SVGraphicWrapLeft:
                    [context pushClassName:@"narrow right"];
                    break;
                case SVGraphicWrapRight:
                    [context pushClassName:@"narrow left"];
                    break;
                case SVGraphicWrapLeftSplit:
                    [context pushClassName:@"wide right"];
                    break;
                case SVGraphicWrapCenterSplit:
                    [context pushClassName:@"wide center"];
                    break;
                case SVGraphicWrapRightSplit:
                    [context pushClassName:@"wide left"];
                    break;
            }
            [context addDependencyOnObject:self keyPath:@"textAttachment.wrap"];
        }
        [context addDependencyOnObject:self keyPath:@"textAttachment.causesWrap"];
    }
}

- (NSString *)inlineGraphicClassName; { return nil; }

- (void)writeBody:(SVHTMLContext *)context;
{
    SUBCLASSMUSTIMPLEMENT;
    [self doesNotRecognizeSelector:_cmd];
}

+ (SVTemplate *)template;
{
    static SVTemplate *result;
    if (!result)
    {
        result = [[SVTemplate templateNamed:@"PageletTemplate.html"] retain];
    }
    
    return result;
}

- (void)writeHTML;
{
    [[[SVHTMLTemplateParser currentTemplateParser] HTMLContext] writeGraphic:self];
}

#pragma mark Thumbnail

- (void)writeThumbnailImage:(SVHTMLContext *)context
                   maxWidth:(NSUInteger)width
                  maxHeight:(NSUInteger)height;
{
    // Default is for no thumbnail!
}

- (id)imageRepresentation; { return nil; }
- (NSString *)imageRepresentationType; { return nil; }

#pragma mark RSS

@dynamic includeAsRSSEnclosure;

- (id <SVEnclosure>)enclosure; { return nil; }

#pragma mark Inspector

+ (SVInspectorViewController *)makeInspectorViewController; { return nil; }

- (Class)inspectorFactoryClass; { return [self class]; }

- (id)objectToInspect; { return self; }

- (id)valueForUndefinedKey:(NSString *)key
{
    if ([self usesExtensiblePropertiesForUndefinedKey:key])
    {
        return [super valueForUndefinedKey:key];
    }
    else
    {
        return NSNotApplicableMarker;
    }
}

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    [propertyList setObject:[[self entity] name] forKey:@"entity"];
    
    SVTextAttachment *attachment = [self textAttachment];
    [propertyList setValue:[self placement] forKey:@"placement"];
    [propertyList setValue:[attachment causesWrap] forKey:@"causesWrap"];
    [propertyList setValue:[attachment wrap] forKey:@"wrap"];
    
    [propertyList setValue:[[self titleBox] serializedProperties]   // might be nil in a subclass
                    forKey:@"titleBox"];
}

- (void)writeToPasteboard:(NSPasteboard *)pboard;
{
    [pboard setPropertyList:[self serializedProperties]
                    forType:kSVGraphicPboardType];
}

+ (id)graphicWithSerializedProperties:(id)properties
       insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    OBPRECONDITION(properties);
    
    NSString *entityName = [properties objectForKey:@"entity"];
    
    SVGraphic *result = [NSEntityDescription
                          insertNewObjectForEntityForName:entityName
                          inManagedObjectContext:context];
    
    [result awakeFromPropertyList:properties];
    
    return result;
}

+ (NSArray *)graphicsFromPasteboard:(NSPasteboard *)pasteboard
     insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    if ([[pasteboard types] containsObject:kSVGraphicPboardType])
    {
        id plist = [pasteboard propertyListForType:kSVGraphicPboardType];
        if (plist)
        {
            id graphic = [self graphicWithSerializedProperties:plist
                                insertIntoManagedObjectContext:context];
            
            return [NSArray arrayWithObject:graphic];
        }
    }
    
    return nil;
}

- (void)awakeFromPropertyList:(id)propertyList;
{
    [super awakeFromPropertyList:propertyList];
    
    // Restore title
    NSDictionary *serializedTitle = [propertyList objectForKey:@"titleBox"];
    if (serializedTitle)
    {
        [[self titleBox] awakeFromPropertyList:serializedTitle];
    }
    else
    {
        [self setShowsTitle:NO];
    }
    
    
    // Ensure border is correct. plist may have set it to nil
    if (![self showBorder]) [self setBordered:NO];
}

#pragma mark Pasteboard

- (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard; { return nil; }

- (BOOL)awakeFromPasteboardItems:(NSArray *)items; { return YES; }

#pragma mark SVPlugInContainer

- (NSString *)title	// get title, but without attributes
{
	return [[self titleBox] text];
}

- (void)setTitle:(NSString *)title;
{
    SVTitleBox *text = [self titleBox];
    if (!text)
    {
        text = [NSEntityDescription insertNewObjectForEntityForName:@"PageletTitle" inManagedObjectContext:[self managedObjectContext]];
        [self setTitleBox:text];
    }
    [text setText:title];
}

+ (NSSet *)keyPathsForValuesAffectingTitle
{
    return [NSSet setWithObject:@"titleBox.text"];
}

- (BOOL)showsTitle
{
    BOOL result = NO;
    if ([[self placement] intValue] != SVGraphicPlacementInline)
    {
        NSNumber *hidden = [[self titleBox] hidden];
        result = (hidden && ![hidden boolValue]);
    }
    return result;
}
- (void)setShowsTitle:(BOOL)show { [[self titleBox] setHidden:[NSNumber numberWithBool:!show]]; }
+ (NSSet *)keyPathsForValuesAffectingShowsTitle; { return [NSSet setWithObject:@"titleBox.hidden"]; }

- (BOOL)isBordered { return [[self showBorder] boolValue]; }
- (void)setBordered:(BOOL)border { [self setShowBorder:[NSNumber numberWithBool:border]]; }
+ (NSSet *)keyPathsForValuesAffectingBordered { return [NSSet setWithObject:@"showBorder"]; }

@dynamic title;
@dynamic showsTitle;
@dynamic bordered;

- (BOOL)showsIntroduction
{
    BOOL result = NO;
    if ([[self placement] intValue] != SVGraphicPlacementInline)
    {
        NSNumber *hidden = [[self introduction] hidden];
        result = (hidden && ![hidden boolValue]);
    }
    return result;
}
- (void)setShowsIntroduction:(BOOL)show { [[self introduction] setHidden:NSBOOL(!show)]; }
+ (NSSet *)keyPathsForValuesAffectingShowsIntroduction; { return [NSSet setWithObject:@"introduction.hidden"]; }

- (BOOL)showsCaption
{
    NSNumber *hidden = [[self caption] hidden];
    return (hidden && ![hidden boolValue]);
}
- (void)setShowsCaption:(BOOL)show { [[self caption] setHidden:NSBOOL(!show)]; }
+ (NSSet *)keyPathsForValuesAffectingShowsCaption; { return [NSSet setWithObject:@"caption.hidden"]; }

- (NSNumber *)containerWidth;
{
    if ([[self placement] intValue] == SVGraphicPlacementInline)
    {
        NSNumber *result = [self width];
        
        // Images can be smaller than 200px, but container should still be 200px in which case
        if (result && [result unsignedIntegerValue] < 200) result = [NSNumber numberWithInt:200];
        return result;
    }
    else
    {
        return [NSNumber numberWithUnsignedInt:200];
    }
}

- (void)setContainerWidth:(NSNumber *)width;
{
    if (width && [width unsignedIntegerValue] < 200)
    {
        width = [NSNumber numberWithInt:200];
    }
    
    [self setWidth:width];
}

@end


#pragma mark -


@implementation SVGraphic (Deprecated)

#pragma mark Title

- (NSString *)titleHTMLString
{
    return [[self titleBox] textHTMLString];
}

+ (NSSet *)keyPathsForValuesAffectingTitleHTMLString
{
    return [NSSet setWithObject:@"titleBox.textHTMLString"];
}

@end
