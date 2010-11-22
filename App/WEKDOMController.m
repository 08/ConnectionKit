//
//  WEKDOMController.m
//  Sandvox
//
//  Created by Mike on 24/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "WEKDOMController.h"
#import <WebKit/WebKit.h>


@interface WEKDOMEventListener : NSObject <DOMEventListener>
{
@private
    id <DOMEventListener>   _target;    // weak ref
}

@property(nonatomic, assign) id <DOMEventListener> eventsTarget;

@end


#pragma mark -


@implementation WEKDOMController

#pragma mark Init & Dealloc

- (id)initWithHTMLDocument:(DOMHTMLDocument *)document;
{
    self = [self init];
    _DOMDocument = [document retain];
    return self;
}
@synthesize HTMLDocument = _DOMDocument;

- (id)initWithHTMLElement:(DOMHTMLElement *)element;
{
    self = [self init];
    [self setHTMLElement:element];
    return self;
}

- (void)dealloc
{
    [_eventListener setEventsTarget:nil];
    
    [_DOMDocument release];
    [_DOMElement release];
    [_eventListener release];
    [_representedObject release];
    
    [super dealloc];
}

#pragma mark DOM

@synthesize HTMLElement = _DOMElement;

- (void)createHTMLElement
{
    // Nothing to do by default
}

- (BOOL)isHTMLElementCreated { return (_DOMElement != nil); }

- (DOMRange *)DOMRange; // returns -HTMLElement as a range
{
    DOMElement *element = [self HTMLElement];
    DOMRange *result = [[element ownerDocument] createRange];
    [result selectNode:element];
    return result;
}

- (id <DOMEventListener>)eventsListener;
{
    if (!_eventListener)
    {
        _eventListener = [[WEKDOMEventListener alloc] init];
        [_eventListener setEventsTarget:(id <DOMEventListener>)self];   // expect subclasses to conform
    }
    return _eventListener;
}

#pragma mark Content

@synthesize representedObject = _representedObject;

@end


#pragma mark -


@implementation WEKDOMEventListener

@synthesize eventsTarget = _target;

- (void)handleEvent:(DOMEvent *)event;
{
    [[self eventsTarget] handleEvent:event];
}

@end
