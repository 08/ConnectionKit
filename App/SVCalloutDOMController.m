//
//  SVCalloutDOMController.m
//  Sandvox
//
//  Created by Mike on 28/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVCalloutDOMController.h"

#import "SVRichTextDOMController.h"

#import "DOMNode+Karelia.h"


@interface DOMElement (SVCalloutDOMController)
- (DOMNodeList *)getElementsByClassName:(NSString *)name;
@end


#pragma mark -


@implementation SVCalloutDOMController

#pragma mark Init & Dealloc

- (void)dealloc
{
    [_calloutContent release];
    [super dealloc];
}

#pragma mark DOM

@synthesize calloutContentElement = _calloutContent;

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    [super loadHTMLElementFromDocument:document];
    
    DOMNodeList *nodes = [[self HTMLElement] getElementsByClassName:@"callout-content"];
    [self setCalloutContentElement:(DOMElement *)[nodes item:0]];
}

- (void)createHTMLElement;
{
    DOMHTMLDocument *document = [self HTMLDocument];
    
    // This logic is vry similar to SVHTMLContext. Wonder if there's a way to bring them together
    
    DOMElement *calloutContainer = [document createElement:@"DIV"];
    [calloutContainer setAttribute:@"class" value:@"callout-container"];
    
    DOMElement *callout = [document createElement:@"DIV"];
    [callout setAttribute:@"class" value:@"callout"];
    [calloutContainer appendChild:callout];
    
    DOMElement *calloutContent = [document createElement:@"DIV"];
    [calloutContent setAttribute:@"class" value:@"callout-content"];
    [callout appendChild:calloutContent];
    
    
    [self setHTMLElement:(DOMHTMLElement *)calloutContainer];
    [self setCalloutContentElement:calloutContent];
}

#pragma mark Attributed HTML

- (BOOL)writeAttributedHTML:(SVParagraphedHTMLWriterDOMAdaptor *)writer;
{
    // Temporarily switch delegate to us for writing out children
    id delegate = [writer delegate];
    [writer setDelegate:self];
    
    @try
    {
        DOMNode *aNode = [[self calloutContentElement] firstChild];
        while (aNode)
        {
            aNode = [aNode writeTopLevelParagraph:writer];
        }
    }
    @finally
    {
        [writer setDelegate:delegate];
    }
    
    return YES;
}

- (WEKWebEditorItem *)itemForDOMNode:(DOMNode *)node;
{
    for (WEKWebEditorItem *anItem in [self childWebEditorItems])
    {
        if ([anItem HTMLElement] == node) return anItem;
    }
    
    return nil;
}

- (DOMNode *)DOMAdaptor:(SVParagraphedHTMLWriterDOMAdaptor *)writer willWriteDOMElement:(DOMElement *)element;
{
    DOMNode *result = element;
    
    // If the element is inside an DOM controller, write that out instead…
    WEKWebEditorItem *item = [self itemForDOMNode:element];
    if (item)
    {
        if ([item writeAttributedHTML:writer]) result = [element nextSibling];
    }
    
    return result;
}

#pragma mark Moving

/*  Normally it's enough to move ourself up or down instead of the item. But if we contain multiple graphics, have to get more cunning
 */
- (void)moveItemUp:(WEKWebEditorItem *)item;
{
    OBPRECONDITION(item);
    OBPRECONDITION([item parentWebEditorItem] == self);
    
    
    // Is there anywhere to move to within callout?
    WEKWebEditorView *webEditor = [self webEditor];
    DOMNode *previousNode = [item previousDOMNode];
    
    while (previousNode && [webEditor shouldChangeTextInDOMRange:[self DOMRange]])
    {
        [item exchangeWithPreviousDOMNode];
        
        if ([previousNode hasSize])
        {
            [webEditor didChangeText];
            return;
        }
        
        previousNode = [item previousDOMNode];
    }
    
    
    [super moveItemUp:item];
}

- (void)moveItemDown:(WEKWebEditorItem *)item;
{
    OBPRECONDITION(item);
    OBPRECONDITION([item parentWebEditorItem] == self);
    
    
    // Is there anywhere to move to within callout?
    WEKWebEditorView *webEditor = [self webEditor];
    DOMNode *nextNode = [item nextDOMNode];
    
    while (nextNode && [webEditor shouldChangeTextInDOMRange:[self DOMRange]])
    {
        [item exchangeWithNextDOMNode];
        
        if ([nextNode hasSize])
        {
            [webEditor didChangeText];
            return;
        }
        
        nextNode = [item nextDOMNode];
    }
    
    
    // Guess not; do a normal move instead
    [super moveItemDown:item];
}

#pragma mark Other

- (NSString *)elementIdName;
{
    return [NSString stringWithFormat:@"callout-controller-%p", self];
}

- (SVCalloutDOMController *)calloutDOMController;
{
    return self;
}

- (BOOL)allowsPagelets; { return YES; }

@end


#pragma mark -


@implementation WEKWebEditorItem (SVCalloutDOMController)

- (SVCalloutDOMController *)calloutDOMController; { return [[self parentWebEditorItem] calloutDOMController]; }

@end
