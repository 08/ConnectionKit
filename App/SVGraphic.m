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
#import "SVHTMLTemplateParser.h"
#import "KTPage.h"
#import "SVRichText.h"
#import "SVTemplate.h"
#import "SVTextAttachment.h"
#import "SVTitleBox.h"

#import "NSError+Karelia.h"
#import "NSString+Karelia.h"


NSString *kSVGraphicPboardType = @"com.karelia.sandvox.graphic";


@implementation SVGraphic

#pragma mark Initialization

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    
    // UID
    [self setPrimitiveValue:[NSString shortUUIDString] forKey:@"elementID"];
    
    
    // Text
    [self setTitle:[[self class] placeholderTitleText]];
    [self createDefaultIntroAndCaption];
}

- (void)willInsertIntoPage:(KTPage *)page;
{
    [self didAddToPage:page];
}

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

// Inline graphics are not pagelets, but everything else is
- (BOOL)isPagelet;
{
    BOOL result = ([[self placement] intValue] != SVGraphicPlacementInline);
    return result;
}

- (BOOL)mustBePagelet; { return YES; }

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

- (NSString *)className;
{
    NSString *result = nil;
    
    if (![self isCallout])
    {
        SVTextAttachment *textAttachment = [self textAttachment];
        if ([[textAttachment causesWrap] boolValue])
        {
            switch ([[textAttachment wrap] integerValue])
            {
                case SVGraphicWrapNone:
                    result = @"inline";
                    break;
                case SVGraphicWrapLeft:
                    result = @"narrow right";
                    break;
                case SVGraphicWrapRight:
                    result = @"narrow left";
                    break;
                case SVGraphicWrapLeftSplit:
                    result = @"wide right";
                    break;
                case SVGraphicWrapCenterSplit:
                    result = @"wide center";
                    break;
                case SVGraphicWrapRightSplit:
                    result = @"wide left";
                    break;
            }
        }
    }
    
    return result;
}

+ (NSSet *)keyPathsForValuesAffectingClassName
{
    return [NSSet setWithObjects:@"textAttachment.causesWrap", @"textAttachment.wrap", nil];
}

- (void)writeBody:(SVHTMLContext *)context;
{
    SUBCLASSMUSTIMPLEMENT;
    [self doesNotRecognizeSelector:_cmd];
}

// For the benefit of pagelet HTML template
- (void)writeBody { [self writeBody:[[SVHTMLTemplateParser currentTemplateParser] HTMLContext]]; }

+ (SVTemplate *)template;
{
    static SVTemplate *result;
    if (!result)
    {
        result = [[SVTemplate templateNamed:@"PageletTemplate.html"] retain];
    }
    
    return result;
}

@dynamic elementID;

- (void)writeHTML;
{
    [[[SVHTMLTemplateParser currentTemplateParser] HTMLContext] writeGraphic:self];
}

#pragma mark Thumbnail

- (id <IMBImageItem>)thumbnail { return nil; }

#pragma mark Inspector

+ (SVInspectorViewController *)makeInspectorViewController; { return nil; }

- (Class)inspectorFactoryClass; { return [self class]; }

- (id)valueForUndefinedKey:(NSString *)key
{
    return NSNotApplicableMarker;
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
    // Don't deserialize element ID as it means we have two of them!
    NSString *ID = [self elementID];
    [super awakeFromPropertyList:propertyList];
    
    [self willChangeValueForKey:@"elementID"];
    [self setPrimitiveValue:ID forKey:@"elementID"];
    [self didChangeValueForKey:@"elementID"];
    
    
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

#pragma mark SVPageletPlugInContainer

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
    NSNumber *hidden = [[self titleBox] hidden];
    return (hidden && ![hidden boolValue]);
}
- (void)setShowsTitle:(BOOL)show { [[self titleBox] setHidden:[NSNumber numberWithBool:!show]]; }
+ (NSSet *)keyPathsForValuesAffectingShowsTitle; { return [NSSet setWithObject:@"titleBox.hidden"]; }

- (BOOL)isBordered { return [[self showBorder] boolValue]; }
- (void)setBordered:(BOOL)border { [self setShowBorder:[NSNumber numberWithBool:border]]; }
+ (NSSet *)keyPathsForValuesAffectingBordered { return [NSSet setWithObject:@"showBorder"]; }

#pragma mark SVPlugInContainer

@dynamic title;
@dynamic showsTitle;
@dynamic bordered;

- (BOOL)showsIntroduction
{
    NSNumber *hidden = [[self introduction] hidden];
    return (hidden && ![hidden boolValue]);
}
- (void)setShowsIntroduction:(BOOL)show { [[self introduction] setHidden:[NSNumber numberWithBool:!show]]; }
+ (NSSet *)keyPathsForValuesAffectingShowsIntroduction; { return [NSSet setWithObject:@"introduction.hidden"]; }

- (BOOL)showsCaption
{
    NSNumber *hidden = [[self caption] hidden];
    return (hidden && ![hidden boolValue]);
}
- (void)setShowsCaption:(BOOL)show { [[self caption] setHidden:[NSNumber numberWithBool:!show]]; }
+ (NSSet *)keyPathsForValuesAffectingShowsCaption; { return [NSSet setWithObject:@"caption.hidden"]; }

- (void)disableUndoRegistration;
{
    NSUndoManager *undoManager = [[self managedObjectContext] undoManager];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification
                                                        object:undoManager];
    
    [undoManager disableUndoRegistration];
}

- (void)enableUndoRegistration;
{
    NSUndoManager *undoManager = [[self managedObjectContext] undoManager];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification
                                                        object:undoManager];
    
    [undoManager enableUndoRegistration];
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
