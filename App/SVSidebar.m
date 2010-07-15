// 
//  SVSidebar.m
//  Sandvox
//
//  Created by Mike on 29/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVSidebar.h"

#import "SVGraphic.h"
#import "SVHTMLTemplateParser.h"
#import "KTPage.h"
#import "SVSidebarPageletsController.h"
#import "SVTemplate.h"
#import "SVWebEditorHTMLContext.h"

#import "NSSortDescriptor+Karelia.h"


@implementation SVSidebar 

@dynamic page;

#pragma mark Pagelets

@dynamic pagelets;

- (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error
{
    return [SVGraphic validateSortKeyForPagelets:pagelets error:error];
}

#pragma mark HTML

- (void)writeHTML:(SVHTMLContext *)context;
{
    [context willBeginWritingSidebar:self];
    
    SVTemplate *template = [SVTemplate templateNamed:@"SidebarTemplate.html"];
    
    SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc]
                                    initWithTemplate:[template templateString]
                                    component:self];
    
    [parser parseIntoHTMLContext:context];
    [parser release];
    
    // HACK!
    if ([context respondsToSelector:@selector(endDOMController)])
    {
        [context performSelector:@selector(endDOMController)];
    }
}

- (void)writeHTML; { [self writeHTML:[SVHTMLContext currentContext]]; }

- (void)writePageletsHTML:(SVHTMLContext *)context;
{
    // Use the best controller available to give us an ordered list of pagelets
    NSArrayController *controller = [context cachedSidebarPageletsController];
    if (!controller)
    {
        controller = [[SVSidebarPageletsController alloc] initWithSidebar:self];
        [controller autorelease];
    }
    
    //[context addDependencyOnObject:controller keyPath:@"arrangedObjects"];    // taken care of by SVSidebarDOMController now
    
    
    // Write HTML
    [context writeGraphics:[controller arrangedObjects]];
}

- (void)writePageletsHTML;
{
    [self writePageletsHTML:[SVHTMLContext currentContext]];
}

- (NSString *)elementIdName; { return @"sidebar-container"; }

- (BOOL)shouldPublishEditingElementID; { return YES; }

@end
