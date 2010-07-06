//
//  SVParagraphedHTMLWriter.m
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVParagraphedHTMLWriter.h"

#import "SVRichTextDOMController.h"
#import "SVGraphicDOMController.h"
#import "SVImage.h"
#import "SVMediaRecord.h"
#import "SVTextAttachment.h"

#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "DOMNode+Karelia.h"


@implementation SVParagraphedHTMLWriter

#pragma mark Init & Dealloc

- (id)initWithOutputWriter:(id <KSWriter>)stream;
{
    if (self = [super initWithOutputWriter:stream])
    {
        _attachments = [[NSMutableSet alloc] init];
    }
    
    return self;
}

- (void)dealloc
{
    [_attachments release];
    [super dealloc];
}

#pragma mark Properties

@synthesize allowsPagelets = _allowsBlockGraphics;

#pragma mark Output

- (NSSet *)textAttachments; { return [[_attachments copy] autorelease]; }

- (void)writeTextAttachment:(SVTextAttachment *)attachment;
{
    [_attachments addObject:attachment];
    [self writeString:[NSString stringWithUnichar:NSAttachmentCharacter]];
}

#pragma mark Cleanup

- (WEKWebEditorItem *)orphanedWebEditorItemMatchingDOMNode:(DOMNode *)aNode;
{
    for (WEKWebEditorItem *anItem in [[self delegate] childWebEditorItems])
    {
        DOMNode *node = [anItem HTMLElement];
        if (![node parentNode] && [node isEqualNode:aNode]) return anItem;
    }
    
    return nil;
}

- (DOMNode *)handleInvalidBlockElement:(DOMElement *)element;
{
    // Move the element and its next siblings up a level. Next stage of recursion will find them there
    
    
    DOMNode *parent = [element parentNode];
    DOMNode *newParent = [parent parentNode];
    NSArray *nodes = [parent childDOMNodesAfterChild:[element previousSibling]];
    
    [newParent insertDOMNodes:nodes beforeChild:[parent nextSibling]];
    
    
    return nil;
}

- (DOMNode *)convertImageElementToGraphic:(DOMHTMLImageElement *)imageElement;
{
    // Is there an orphaned item we should reconnect to?
    WEKWebEditorItem *orphanedItem = [self orphanedWebEditorItemMatchingDOMNode:imageElement];
    if (orphanedItem)
    {
        [orphanedItem setHTMLElement:imageElement];
        [[self delegate] write:self selectableItem:(SVGraphicDOMController *)orphanedItem];
        return [orphanedItem HTMLElement];
    }
    
    
    // Make an image object
    SVRichTextDOMController *textController = [self delegate];
    SVRichText *text = [textController representedObject];
    NSManagedObjectContext *context = [text managedObjectContext];
    
    SVMediaRecord *media;
    NSURL *URL = [imageElement absoluteImageURL];
    if ([URL isFileURL])
    {
        media = [SVMediaRecord mediaWithURL:URL
                                 entityName:@"GraphicMedia"
             insertIntoManagedObjectContext:context
                                      error:NULL];
    }
    else
    {
        WebResource *resource = [[[[imageElement ownerDocument] webFrame] dataSource] subresourceForURL:URL];
        
        media = [SVMediaRecord mediaWithWebResource:resource
                                         entityName:@"GraphicMedia"
                     insertIntoManagedObjectContext:context];
        
        [media setPreferredFilename:[@"pastedImage" stringByAppendingPathExtension:[URL pathExtension]]];
    }
    
    SVImage *image = [SVImage insertNewImageInManagedObjectContext:context];
    [image setMedia:media];
    
    
    // Try to divine image size
    int width = [imageElement width];
    int height = [imageElement height];
    
    if (width > 0 && height > 0)
    {
        [image setWidth:[NSNumber numberWithInt:width]];
        [image setHeight:[NSNumber numberWithInt:height]];
    }
    else
    {
        [image makeOriginalSize];
    }
    [image setConstrainProportions:YES];
    
    
    // Make corresponding text attachment
    SVTextAttachment *textAttachment = [NSEntityDescription
                                        insertNewObjectForEntityForName:@"TextAttachment"
                                        inManagedObjectContext:context];
    [textAttachment setGraphic:image];
    [textAttachment setBody:text];
    [textAttachment setPlacement:[NSNumber numberWithInteger:SVGraphicPlacementInline]];
    
    
    // Create controller for graphic
    SVDOMController *controller = [image newDOMController];
    [controller setHTMLContext:[textController HTMLContext]];
    [controller setHTMLElement:imageElement];
    
    [textController addChildWebEditorItem:controller];
    [controller release];
    
    
    // Replace old DOM element with new one
    DOMNode *result = [imageElement nextSibling];
    DOMNode *parentNode = [imageElement parentNode];
    [parentNode removeChild:imageElement];
    [parentNode insertBefore:[controller HTMLElement] refChild:result];
    
    
    // Write the replacement
    [textController write:self selectableItem:controller];
    
    
    return result;
}

- (DOMNode *)handleInvalidDOMElement:(DOMElement *)element;
{
    // Ignore callout <div>s
    if ([[element tagName] isEqualToString:@"DIV"] &&
        [[element className] hasPrefix:@"callout-container"])
    {
        return [element nextSibling];
    }
    
    
    // Invalid top-level elements should be converted into paragraphs
    else if ([[element tagName] isEqualToString:@"IMG"])
    {
        return [self convertImageElementToGraphic:(DOMHTMLImageElement *)element];
    }
    else if ([self openElementsCount] == 0)
    {
        DOMElement *result = [self changeDOMElement:element toTagName:@"P"];
        return result;  // pretend the element was written, but retry on this new node
    }
    else
    {
        // Non-top-level block elements should be converted into paragraphs higher up the tree
        DOMDocument *doc = [element ownerDocument];
        DOMCSSStyleDeclaration *style = [doc getComputedStyle:element pseudoElement:nil];
        if ([[style getPropertyValue:@"display"] isEqualToString:@"block"])
        {
            return [self handleInvalidBlockElement:element];
        }
        else
        {
            return [super handleInvalidDOMElement:element];
        }
    }
}

#pragma mark Basic Writing

- (void)writeText:(NSString *)string;
{
    // At start of top element, ignore whitespace. #76588
    if ([self openElementsCount] == 1 &&
        [_pendingStartTagDOMElements count] &&
        [string isWhitespace])
    {
        return;
    }
    
    [super writeText:string];
}

#pragma mark Validation

- (BOOL)validateTagName:(NSString *)tagName
{
    // Paragraphs are permitted in body text
    if ([tagName isEqualToString:@"P"] ||
        [tagName isEqualToString:@"UL"] ||
        [tagName isEqualToString:@"OL"])
    {
        BOOL result = ([self openElementsCount] == 0 || [self topElementIsList]);
        return result;
    }
    else
    {
        BOOL result = ([tagName isEqualToString:@"A"] ||
                       [super validateTagName:tagName]);
    
        return result;
    }
}

- (BOOL)validateAttribute:(NSString *)attributeName;
{
    // Super doesn't allow links; we do.
    if ([[self topElement] isEqualToString:@"a"])
    {
        BOOL result = ([attributeName isEqualToString:@"href"] ||
                       [attributeName isEqualToString:@"target"] ||
                       [attributeName isEqualToString:@"style"] ||
                       [attributeName isEqualToString:@"charset"] ||
                       [attributeName isEqualToString:@"hreflang"] ||
                       [attributeName isEqualToString:@"name"] ||
                       [attributeName isEqualToString:@"title"] ||
                       [attributeName isEqualToString:@"rel"] ||
                       [attributeName isEqualToString:@"rev"]);
        
        return result;               
    }
    else
    {
        return [super validateAttribute:attributeName];
    }
}

- (BOOL)validateStyleProperty:(NSString *)propertyName;
{
    BOOL result = [super validateStyleProperty:propertyName];
    
    if (!result && [propertyName isEqualToString:@"text-align"])
    {
        NSString *tagName = [self topElement];
        if ([tagName isEqualToString:@"p"])
        {
            result = YES;
        }
    }
    
    return result;
}

@end


#pragma mark -


@implementation DOMNode (SVBodyText)

- (DOMNode *)topLevelParagraphWriteToStream:(KSHTMLWriter *)context;
{
    //  Don't want unknown nodes
    DOMNode *result = [self nextSibling];
    [[self parentNode] removeChild:self];
    return result;
}

@end


@implementation DOMElement (SVBodyText)

- (DOMNode *)topLevelParagraphWriteToStream:(KSHTMLWriter *)context;
{
    //  Elements can be treated pretty normally
    DOMNode *node = [context willWriteDOMElement:self];
    if (node == self)
    {
        return [context _writeDOMElement:self];
    }
    else
    {
        return node;
    }
}

@end


@implementation DOMText (SVBodyText)

- (DOMNode *)topLevelParagraphWriteToStream:(KSHTMLWriter *)context;
{
    NSString *text = [self textContent];
    if ([text isWhitespace])
    {
        //  Only allowed  a single newline at the top level. Ignore whitespace at the very start of text
        DOMNode *previousNode = [self previousSibling];
        if (previousNode)
        {
            if ([previousNode nodeType] == DOM_TEXT_NODE)
            {
                return [super topLevelParagraphWriteToStream:context];  // delete self
            }
            else
            {
                [self setTextContent:@"\n"];    // XML Writer will take care of writing its own whitespace
            }
        }
        
        return [self nextSibling];
    }
    else
    {
        // Create a paragraph to contain the text
        DOMDocument *doc = [self ownerDocument];
        DOMElement *paragraph = [doc createElement:@"P"];
        [[self parentNode] appendChild:paragraph];
        
        // Move content into the paragraph
        DOMNode *aNode;
        DOMNode *previousNode = [self previousSibling];
        while ((aNode = [paragraph previousSibling]) != previousNode)
        {
            [paragraph insertBefore:aNode refChild:[paragraph firstChild]];
        }
        
        return paragraph;
    }
}

@end


