//
//  SVWebEditorViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorViewController.h"

#import "SVApplicationController.h"
#import "SVArticle.h"
#import "SVAttributedHTML.h"
#import "KTDocument.h"
#import "SVLogoImage.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "SVGraphicDOMController.h"
#import "SVGraphicFactory.h"
#import "SVLink.h"
#import "SVLinkManager.h"
#import "SVMediaRecord.h"
#import "SVPlugInGraphic.h"
#import "KTSite.h"
#import "SVSelectionBorder.h"
#import "SVRawHTMLGraphic.h"
#import "SVRichTextDOMController.h"
#import "SVSidebar.h"
#import "SVSidebarDOMController.h"
#import "SVSidebarPageletsController.h"
#import "SVTextAttachment.h"
#import "SVWebContentAreaController.h"
#import "SVWebContentObjectsController.h"
#import "SVWebEditorHTMLContext.h"
#import "SVWebEditorTextRange.h"

#import "NSArray+Karelia.h"
#import "NSResponder+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"

#import "KSCollectionController.h"
#import "KSPlugInWrapper.h"
#import "KSSilencingConfirmSheet.h"
#import "KTHTMLEditorController.h"

#import <BWToolkitFramework/BWToolkitFramework.h>


NSString *sSVWebEditorViewControllerWillUpdateNotification = @"SVWebEditorViewControllerWillUpdateNotification";


@interface SVWebEditorViewController ()

@property(nonatomic, readwrite) BOOL viewIsReadyToAppear;

- (void)willUpdate;
- (void)didUpdate;  // if an asynchronous update, called after the update finishes

@property(nonatomic, retain, readwrite) SVWebEditorHTMLContext *HTMLContext;

@property(nonatomic, retain, readonly) SVWebContentObjectsController *primitiveSelectedObjectsController;

- (void)setSelectedTextRange:(SVWebEditorTextRange *)textRange affinity:(NSSelectionAffinity)affinity;
@end


#pragma mark -


@implementation SVWebEditorViewController

#pragma mark Init & Dealloc

- (id)init
{
    self = [super init];
    
    _graphicsController = [[SVWebContentObjectsController alloc] init];
    [_graphicsController setAvoidsEmptySelection:NO];
    [_graphicsController setPreservesSelection:NO];    // we'll take care of that
    [_graphicsController setSelectsInsertedObjects:NO];
    [_graphicsController setObjectClass:[NSObject class]];
        
    return self;
}
    
- (void)dealloc
{    
    [[[self webEditor] undoManager] removeAllActionsWithTarget:self];
    
    [self setWebEditor:nil];   // needed to tear down data source
    [self setDelegate:nil];
    
    [_context release];
    [_graphicsController release];
    [_loadedPage release];
	self.HTMLEditorController = nil;
    
    [super dealloc];
}

#pragma mark Views

- (void)loadView
{
    WEKWebEditorView *editor = [[WEKWebEditorView alloc] init];
    
    [self setView:editor];
    [self setWebEditor:editor];
    [self setWebView:[editor webView]];
    
    // Keep links beahviour in sync with the defaults
    [editor bind:@"liveEditableAndSelectableLinks"
        toObject:[NSUserDefaultsController sharedUserDefaultsController]
     withKeyPath:[@"values." stringByAppendingString:kLiveEditableAndSelectableLinksDefaultsKey]
         options:nil];
    
    // Register the editor for drag & drop
    [editor registerForDraggedTypes:[NSArray arrayWithObject:kKTPageletsPboardType]];
    
    [editor release];
}

- (void)setWebView:(WebView *)webView
{
    // Store new webview
    [super setWebView:webView];
}

@synthesize webEditor = _webEditorView;
- (void)setWebEditor:(WEKWebEditorView *)editor
{
    [[self webEditor] setDelegate:nil];
    [[self webEditor] setDataSource:nil];
    [[self webEditor] setDraggingDestinationDelegate:nil];
    
    [editor retain];
    [_webEditorView release];
    _webEditorView = editor;
    
    [editor setDelegate:self];
    [editor setDataSource:self];
    [editor setDraggingDestinationDelegate:self];
    [editor setAllowsUndo:NO];  // will be managing this entirely ourselves
}

#pragma mark Presentation

@synthesize viewIsReadyToAppear = _readyToAppear;
- (void)setViewIsReadyToAppear:(BOOL)ready;
{
    _readyToAppear = ready;
    
    if ([_contentAreaController selectedViewControllerWhenReady] == self)
    {
        if (ready)
        {
            [_contentAreaController setSelectedViewController:self];
        }
        else
        {
            [_contentAreaController presentLoadingViewController];
        }
    }
}

- (void)webViewDidFirstLayout
{
    // Being a little bit cunning to make sure we sneak in before views can be drawn
    [[NSRunLoop currentRunLoop] performSelector:@selector(switchToLoadingPlaceholderViewIfNeeded)
                                         target:self
                                       argument:nil
                                          order:(NSDisplayWindowRunLoopOrdering - 1)
                                          modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
}

- (void)switchToLoadingPlaceholderViewIfNeeded
{
    // This method will be called fractionally after the webview has done its first layout, and (hopefully!) before that layout has actually been drawn. Therefore, if the webview is still loading by this point, it was an intermediate load and not suitable for display to the user, so switch over to the placeholder.
    if ([self isUpdating]) 
    {
        [self setViewIsReadyToAppear:NO];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (![self isUpdating]) [self loadPage:nil];
    
    // Once we move offscreen, we're no longer suitable to be shown
    [self setViewIsReadyToAppear:NO];
	
	// Close out the HTML editor
	self.HTMLEditorController = nil;

}

#pragma mark Loading

/*  Loading is to Updating as Drawing is to Displaying (in NSView)
 */

- (void)loadPage:(KTPage *)page;
{
    // Mark as updating. Reset counter first since loading page wipes away any in-progress updates
    _updatesCount = 0;
    [self willUpdate];
    
    WEKWebEditorView *webEditor = [self webEditor];
    
    
    // Tear down old dependencies and DOM controllers.
    [webEditor setContentItem:nil];
    
    
    // Prepare the environment for generating HTML
    [_graphicsController setPage:page]; // do NOT set the controller's MOC. Unless you set both MOC
                                                        // and entity name, saving will raise an exception. (crazy I know!)
    
    
    // Construct HTML Context
    NSMutableString *pageHTML = [[NSMutableString alloc] init];
	SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc] initWithMutableString:pageHTML];
    
    [context setPage:page];
    [context setLiveDataFeeds:[[NSUserDefaults standardUserDefaults] boolForKey:kSVLiveDataFeedsKey]];
    [context setSidebarPageletsController:[_graphicsController sidebarPageletsController]];
    
    
    // Go for it. You write that HTML girl!
	if (page) [context writeDocumentWithPage:page];
    [context flush];
    
    
    //  Start loading. Some parts of WebKit need to be attached to a window to work properly, so we need to provide one while it's loading in the
    //  background. It will be removed again after has finished since the webview will be properly part of the view hierarchy.
    
    // Turned this off because I'm not sure it's needed - Mike
    //[[self webView] setHostWindow:[[self view] window]];   // TODO: Our view may be outside the hierarchy too; it woud be better to figure out who our window controller is and use that.
    
    [self setHTMLContext:context];
    
    
    // Record location
    _visibleRect = [[webEditor documentView] visibleRect];
    
    
	// Figure out the URL to use. 
	NSURL *pageURL = [context baseURL];
    if (![pageURL scheme] ||        // case 44071: WebKit will not load the HTML or offer delegate
        ![pageURL host] ||          // info if the scheme is something crazy like fttp:
        !([[pageURL scheme] isEqualToString:@"http"] || [[pageURL scheme] isEqualToString:@"https"]))
    {
        pageURL = nil;
    }
    
    
    // Load the HTML into the webview
    [webEditor loadHTMLString:pageHTML baseURL:pageURL];
    
    
    // Tidy up
    [context release];
    [pageHTML release];
}

- (KTPage *)loadedPage; // the last page to successfully load into Web Editor
{
    return _loadedPage;
}

- (void)webEditorViewDidFinishLoading:(WEKWebEditorView *)sender;
{
    WEKWebEditorView *webEditor = [self webEditor];
    DOMDocument *domDoc = [webEditor HTMLDocument];
    OBASSERT(domDoc);
    
    
    // Context holds the controllers. We need to send them over to the Web Editor.
    // Doing so will populate .graphicsController, so need to clear out its content & remember the selection first
    
    NSArray *selection = [[self graphicsController] selectedObjects];
    [[self graphicsController] setContent:nil];
    
    SVWebEditorHTMLContext *context = [self HTMLContext];
    [_loadedPage release]; _loadedPage = [[context page] retain];
    [webEditor setContentItem:[context rootDOMController]];
    
    [[self graphicsController] setSelectedObjects:selection];    // restore selection
    
    
    // Restore scroll point
    [[self webEditor] scrollToPoint:_visibleRect.origin];
    
    
    // Did Update
    [self didUpdate];
    

    // Mark as loaded
    [self setViewIsReadyToAppear:YES];
    
    
    // Give focus to article? This has to wait until we're onscreen
    if ([self articleShouldBecomeFocusedAfterNextLoad])
    {
        if ([[[self view] window] makeFirstResponder:[self webEditor]])
        {
            SVRichTextDOMController *articleController = (id)[self articleDOMController];
            DOMDocument *document = [[articleController HTMLElement] ownerDocument];
            
            DOMRange *range = [document createRange];
            [range setStart:[articleController textHTMLElement] offset:0];
            [[self webEditor] setSelectedDOMRange:range affinity:0];
        }
        
        [self setArticleShouldBecomeFocusedAfterNextLoad:NO];
    }
    
    
    // Can now ditch context contents
    [context close];
}

@synthesize articleShouldBecomeFocusedAfterNextLoad = _articleShouldBecomeFocusedAfterNextLoad;

#pragma mark Updating

- (void)update;
{
	[self loadPage:[[self HTMLContext] page]];
	
    // Clearly the webview is no longer in need of refreshing
    _willUpdate = NO;
	_needsUpdate = NO;
}

- (BOOL)isUpdating; { return _updatesCount; }

- (void)willUpdate;
{
    if (![self isUpdating]) 
    {
        [[NSNotificationCenter defaultCenter]
         postNotificationName:sSVWebEditorViewControllerWillUpdateNotification
         object:self];
    
        // If the update takes too long, switch over to placeholder
        [self performSelector:@selector(updateDidTimeout) withObject:nil afterDelay:0.1f];
    }
    
    
    // Record that the webview is being loaded with content. Otherwise, the policy delegate will refuse requests. Also record location
    _updatesCount++;
}

- (void)didUpdate;
{
    // Lower the update count, checking if we're already at 0 to avoid wraparound (could've made a mistake)
    if ([self isUpdating])
    {
        _updatesCount--;
    
        // Nothing to do if still going
        if ([self isUpdating]) return;
    }
    
    
    WEKWebEditorView *webEditor = [self webEditor];
    
    
    // Cancel the timer
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(updateDidTimeout)
                                               object:nil];
    
    
    // If the timer did fire, need to bring ourselves back into view
    if ([_contentAreaController selectedViewController] != self &&
        [_contentAreaController selectedViewControllerWhenReady] == self)
    {
        [_contentAreaController setSelectedViewController:self];
    }
    
    
    // Match selection to controller
    NSArray *selectedObjects = [[self graphicsController] selectedObjects];
    NSMutableArray *newSelection = [[NSMutableArray alloc] initWithCapacity:[selectedObjects count]];
    
    for (id anObject in selectedObjects)
    {
        id newItem = [[[self webEditor] contentItem] hitTestRepresentedObject:anObject];
        if ([newItem isSelectable]) [newSelection addObject:newItem];
    }
    
    [[self webEditor] selectItems:newSelection byExtendingSelection:NO];   // this will feed back to us and the controller in notification
    [newSelection release];
    
    
    // Restore selection…
    if (_selectionToRestore)
    {
        // …but only if WebView's First Responder
        if ([webEditor ks_followsResponder:[[webEditor window] firstResponder]])
        {
            [self setSelectedTextRange:_selectionToRestore affinity:NSSelectionAffinityDownstream];
        }
        
        [_selectionToRestore release]; _selectionToRestore = nil;
    }
    
    // Fallback to end of article if needs be. #75712
    if (![webEditor selectedItem] && ![webEditor selectedDOMRange])
    {
        if ([webEditor ks_followsResponder:[[[self view] window] firstResponder]])
        {
            DOMRange *range = [self webEditor:webEditor fallbackDOMRangeForNoSelection:nil];
            [webEditor setSelectedDOMRange:range affinity:0];
        }
    }
}

- (void)updateDidTimeout
{
    [_contentAreaController presentLoadingViewController];
}

#pragma mark Update Scheduling

- (void)scheduleUpdate
{
    // Private method known only to our Main DOM Controller. Schedules an update if needed.
    if (!_willUpdate)
	{
		// Install a fresh observer for the end of the run loop
		[[NSRunLoop currentRunLoop] performSelector:@selector(updateIfNeeded)
                                             target:self
                                           argument:nil
                                              order:0
                                              modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
	}
    _willUpdate = YES;
}

@synthesize needsUpdate = _needsUpdate;
- (void)setNeedsUpdate;
{
    _needsUpdate = YES;
    
    [self scheduleUpdate];
    //[self removeAllDependencies];   // no point observing now we're marked for update
}

- (void)updateIfNeeded
{
    if (!_willUpdate) return;   // don't you waste my time sucker!
    	
    if ([self needsUpdate])
    {
        [self update];
    }
    else
    {
        [[[self webEditor] contentItem] updateIfNeeded];    // will call -didUpdate if anything did
        _willUpdate = NO;
    }
}

- (IBAction)reload:(id)sender { [self setNeedsUpdate]; }

#pragma mark Content

@synthesize primitiveSelectedObjectsController = _graphicsController;
- (id <KSCollectionController>)graphicsController
{
    return [self primitiveSelectedObjectsController];
}

@synthesize firstResponderItem = _firstResponderItem;

@synthesize HTMLContext = _context;
- (void)setHTMLContext:(SVWebEditorHTMLContext *)context;
{
    if (context != [self HTMLContext])
    {
        [[self HTMLContext] setWebEditorViewController:nil];
        [_context release]; _context = [context retain];
        [context setWebEditorViewController:self];
    }
}

- (void)registerWebEditorItem:(WEKWebEditorItem *)item;  // recurses through, registering descendants too
{
    // Ensure element is loaded
    DOMDocument *domDoc = [[self webEditor] HTMLDocument];
    if (![item isHTMLElementCreated]) [item loadHTMLElementFromDocument:domDoc];
    //if ([item representedObject]) OBASSERT([item HTMLElement]);
    
    
    //  Populate controller with content. For now, this is simply all the represented objects of all the DOM controllers
    id anObject = [item representedObject];
    if (anObject && //  second bit of this if statement: images are owned by 2 DOM controllers, DON'T insert twice!
        ![[_graphicsController arrangedObjects] containsObjectIdenticalTo:anObject])
    {
        [[self graphicsController] addObject:anObject];
    }
    
    
    // Start observing dependencies
    [item setObservesDependencies:YES];
    
    
    // Register descendants
    for (WEKWebEditorItem *anItem in [item childWebEditorItems])
    {
        [self registerWebEditorItem:anItem];
    }
}

- (void)unregisterWebEditorItem:(WEKWebEditorItem *)item;  // recurses through, registering descendants too
{
    // Turn off dependencies
    [item setObservesDependencies:NO];
    
    // Unregister descendants
    for (WEKWebEditorItem *anItem in [item childWebEditorItems])
    {
        [self unregisterWebEditorItem:anItem];
    }
}

#pragma mark Text Areas

- (SVTextDOMController *)textAreaForDOMNode:(DOMNode *)node;
{
    WEKWebEditorItem *controller = [[[self webEditor] contentItem] hitTestDOMNode:node];
    SVTextDOMController *result = [controller textDOMController];
    return result;
}

- (SVTextDOMController *)textAreaForDOMRange:(DOMRange *)range;
{
    OBPRECONDITION(range);
    
    // One day there might be better logic to apply, but for now, testing the start of the range is enough
    return [self textAreaForDOMNode:[range startContainer]];
}

- (WEKWebEditorItem *)articleDOMController;
{
    SVRichText *article = [[[self HTMLContext] page] article];
    WEKWebEditorItem *result = [[[self webEditor] contentItem] hitTestRepresentedObject:article];
    return result;
}

#pragma mark Element Insertion

- (void)_insertPageletInSidebar:(SVGraphic *)pagelet;
{
    // Place at end of the sidebar
    [[_graphicsController sidebarPageletsController] addObject:pagelet];
    
    // Add to main controller too
    NSArrayController *controller = [self graphicsController];
    
    BOOL selectInserted = [controller selectsInsertedObjects];
    [controller setSelectsInsertedObjects:YES];
    [controller addObject:pagelet];
    [controller setSelectsInsertedObjects:selectInserted];
}

- (IBAction)insertPagelet:(id)sender;
{
    if (![[self firstResponderItem] tryToPerform:_cmd with:sender])
    {
        [self insertPageletInSidebar:sender];
    }
}

- (IBAction)insertPageletInSidebar:(id)sender;
{
    // Create element
    KTPage *page = [[self HTMLContext] page];
    if (!page) return NSBeep(); // pretty rare. #75495
    
    
    SVGraphic *pagelet = [SVGraphicFactory graphicWithActionSender:sender
                                      insertIntoManagedObjectContext:[page managedObjectContext]];
    
    
    // Insert it
    [pagelet willInsertIntoPage:page];
    [self _insertPageletInSidebar:pagelet];
}

- (IBAction)insertFile:(id)sender;
{
    if (![self tryToMakeSelectionPerformAction:_cmd with:sender])
    {
        NSWindow *window = [[self view] window];
        NSOpenPanel *panel = [[[window windowController] document] makeChooseDialog];
        
        [panel beginSheetForDirectory:nil file:nil modalForWindow:window modalDelegate:self didEndSelector:@selector(chooseDialogDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    }
}

- (void)chooseDialogDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSCancelButton) return;
    
    KTPage *page = [[self HTMLContext] page];
    NSManagedObjectContext *context = [page managedObjectContext];
    
    SVMediaRecord *media = [SVMediaRecord mediaWithURL:[sheet URL]
                                            entityName:@"GraphicMedia"
                        insertIntoManagedObjectContext:context
                                                 error:NULL];
    
    if (media)
    {
        SVImage *image = [SVImage insertNewImageWithMedia:media];
        [image willInsertIntoPage:page];
        [self _insertPageletInSidebar:image];
    }
    else
    {
        NSBeep();
    }
}

#pragma mark Special Insertion

- (void)insertPageletTitle:(id)sender;
{
    // Give the selected pagelets a title if needed
    for (id anObject in [[self graphicsController] selectedObjects])
    {
        if ([anObject isKindOfClass:[SVGraphic class]])
        {
            SVGraphic *pagelet = (SVGraphic *)anObject;
            if ([[[pagelet titleBox] text] length] <= 0)
            {
                [pagelet setTitle:[[pagelet class] placeholderTitleText]];
            }
        }
    }
}

- (IBAction)paste:(id)sender;
{
    SVSidebarPageletsController *sidebarPageletsController =
    [_graphicsController sidebarPageletsController];
    
    NSUInteger index = [sidebarPageletsController selectionIndex];
    if (index >= NSNotFound) index = 0;
    
    [sidebarPageletsController insertPageletsFromPasteboard:[NSPasteboard generalPasteboard]
                                      atArrangedObjectIndex:index];
}


#pragma mark Graphic Placement

- (void)doPlacementCommandBySelector:(SEL)action;
{
    // Whenever there's some kind of text selection, the responsible controller must take it. If there's no controller, cannot perform
    NSResponder *controller = [self firstResponderItem];
    if (controller)
    {
        [controller doCommandBySelector:action];
    }
    else
    {
        NSBeep();
    }
}

- (void)placeInline:(id)sender;
{
    // Whenever there's some kind of text selection, the responsible controller must take it. If there's no controller, cannot perform
    [self doPlacementCommandBySelector:_cmd];
}

- (IBAction)placeBlockLevelIfNeeded:(NSButton *)sender; // calls -placeBlockLevel if sender's state is on
{
    if ([sender state] == NSOnState)
    {
        [self doPlacementCommandBySelector:@selector(placeBlockLevel:)];
    }
}

- (IBAction)placeAsCallout:(id)sender;
{
    // Whenever there's some kind of text selection, the responsible controller must take it. If there's no controller, cannot perform
    [self doPlacementCommandBySelector:_cmd];
    
    // TODO: Handle going from sidebar to callout
}

- (IBAction)placeInSidebar:(id)sender;
{
    // Whenever there's some kind of text selection, the responsible controller must take it. If there's no controller, cannot perform
    [self doPlacementCommandBySelector:_cmd];
    
    // Otherwise assume selection is already in sidebar so nothing needs doing
}

- (void)moveToBlockLevel:(id)sender;
{
    [[self firstResponderItem] tryToPerform:_cmd with:sender];
}

#pragma mark Action Forwarding

- (void)makeTextLarger:(id)sender;
{
    [[self webView] makeTextLarger:sender];
}

- (void)makeTextSmaller:(id)sender;
{
    [[self webView] makeTextSmaller:sender];
}

- (void)makeTextStandardSize:(id)sender;
{
    [[self webView] makeTextStandardSize:sender];
}

- (BOOL)tryToMakeSelectionPerformAction:(SEL)action with:(id)anObject;
{
    DOMRange *selection = [[self webEditor] selectedDOMRange];
    if (selection)
    {
        SVTextDOMController *text = [self textAreaForDOMRange:selection];
        return [text tryToPerform:action with:anObject];
    }
    return NO;
}

#pragma mark Undo

- (SVWebEditorTextRange *)selectedTextRange;
{
    WEKWebEditorView *webEditor = [self webEditor];
    
    DOMRange *domRange = [webEditor selectedDOMRange];
    if (!domRange) return nil;
    
    
    SVWebEditorTextRange *result = nil;
    
    SVTextDOMController *item = [self textAreaForDOMRange:domRange];
    if (item)
    {
        result = [SVWebEditorTextRange rangeWithDOMRange:domRange
                                         containerObject:[item representedObject]
                                           containerNode:[item textHTMLElement]];
    }
    
    return result;
}

- (void)setSelectedTextRange:(SVWebEditorTextRange *)textRange affinity:(NSSelectionAffinity)affinity;
{
    OBPRECONDITION(textRange);
    
    WEKWebEditorView *webEditor = [self webEditor];
    
    id item = [[webEditor contentItem] hitTestRepresentedObject:[textRange containerObject]];
    if (item)
    {
        DOMRange *domRange = [[webEditor HTMLDocument] createRange];
        [textRange populateDOMRange:domRange fromContainerNode:[item textHTMLElement]];
        
        [webEditor setSelectedDOMRange:domRange affinity:affinity];
    }
}

- (void)undo_setSelectedTextRange:(SVWebEditorTextRange *)range;
{
    // Ignore if not already marked for update, since that could potentially reset the selection in the distant future, which is very odd for users. Ideally, this situation won't arrise
    // But, er, it does. So I'm commenting it out.
    //if (![self needsUpdate]) return;
    
    
    [_selectionToRestore release]; _selectionToRestore = [range copy];
    
    // Push opposite onto undo stack
    WEKWebEditorView *webEditor = [self webEditor];
    NSUndoManager *undoManager = [webEditor undoManager];
    
    [[undoManager prepareWithInvocationTarget:self]
     undo_setSelectedTextRange:[self selectedTextRange]];
}

- (void)textDOMControllerDidChangeText:(SVTextDOMController *)controller; { }

#pragma mark UI Validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;	// WARNING: IF YOU ADD ITEMS HERE, YOU NEED TO SYNCHRONIZE WITH -[KTDocWindowController validateMenuItem:]
{
	VALIDATION((@"%s %@",__FUNCTION__, menuItem));
    BOOL result = YES;		// default to YES so we don't have to do special validation for each action. Some actions might say NO.
    
	SEL action = [menuItem action];
	
	if (action == @selector(editRawHTMLInSelectedBlock:))
	{
		result = NO;	// default to no unless found below.
		for (id selection in [self.graphicsController selectedObjects])
		{
			if ([selection isKindOfClass:[SVRawHTMLGraphic class]])
			{
				result = YES;
				break;
			}
		}
	}
	else if (action == @selector(makeTextLarger:))
	{
		result = [[self webView] canMakeTextLarger];
	}
	else if (action == @selector(makeTextSmaller:))
	{
		result = [[self webView] canMakeTextSmaller];
	}
	else if (action == @selector(makeTextStandardSize:))
	{
		result = [[self webView] canMakeTextStandardSize];
	}
	
	
    return result;
}

#pragma mark Delegate

@synthesize delegate = _delegate;
- (void)setDelegate:(id <SVWebEditorViewControllerDelegate>)delegate;
{
    if (_delegate)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:_delegate name:sSVWebEditorViewControllerWillUpdateNotification object:self];
    }
    
    _delegate = delegate;
    
    if ([delegate respondsToSelector:@selector(webEditorViewControllerWillUpdate:)])
    {
        [[NSNotificationCenter defaultCenter] addObserver:delegate
                                                 selector:@selector(webEditorViewControllerWillUpdate:)
                                                     name:sSVWebEditorViewControllerWillUpdateNotification
                                                   object:self];
    }
}

#pragma mark HTMLEditorController

@synthesize HTMLEditorController = _HTMLEditorController;

- (KTHTMLEditorController *)HTMLEditorController	// lazily instantiate
{
	if ( nil == _HTMLEditorController )
	{
		KTHTMLEditorController *controller = [[[KTHTMLEditorController alloc] init] autorelease];
		[self setHTMLEditorController:controller];
//		[self addWindowController:controller];
	}
	return _HTMLEditorController;
}

- (IBAction)editRawHTMLInSelectedBlock:(id)sender
{
	for (id selection in [self.graphicsController selectedObjects])
	{
		if ([selection isKindOfClass:[SVRawHTMLGraphic class]])
		{
			KTHTMLEditorController *controller = [self HTMLEditorController];
			SVRawHTMLGraphic *graphic = (SVRawHTMLGraphic *) selection;
						
			SVTitleBox *titleBox = [graphic titleBox];
			if (titleBox)
			{
				[controller setTitle:[titleBox text]];
			}
			else
			{
				[controller setTitle:nil];
			}
			
			[controller setHTMLSourceObject:graphic];	// so it can save things back.
			
			[controller showWindow:nil];
			break;
		}
	}
}

#pragma mark -

#pragma mark SVSiteItemViewController

- (BOOL)viewShouldAppear:(BOOL)animated webContentAreaController:(SVWebContentAreaController *)controller
{
    _contentAreaController = controller;    // weak ref
    
    KTPage *page = [[controller selectedPage] pageRepresentation];
    if (page != [[self HTMLContext] page])
    {
        [self loadPage:page];
        
        // UI-wise it might be better to test if the page contains the HTML loaded into the editor
        // e.g. while editing pagelet in sidebar, it makes sense to leave the editor open
        self.HTMLEditorController = nil;
    }
    
    return [self viewIsReadyToAppear];
}

#pragma mark -

#pragma mark WebEditorViewDataSource

- (WEKWebEditorItem <SVWebEditorText> *)webEditor:(WEKWebEditorView *)sender
                             textBlockForDOMRange:(DOMRange *)range;
{
    return [self textAreaForDOMRange:range];
}

- (BOOL)webEditor:(WEKWebEditorView *)sender deleteItems:(NSArray *)items;
{
    NSArray *objects = [items valueForKey:@"representedObject"];
    if ([objects isEqualToArray:[[self graphicsController] selectedObjects]])
    {
        [[self graphicsController] remove:self];
    }
    else
    {
        [[self graphicsController] removeObjects:objects];
    }
    
    return YES;
}

- (BOOL)webEditor:(WEKWebEditorView *)sender addSelectionToPasteboard:(NSPasteboard *)pasteboard;
{
    BOOL result = NO;
    
    
    if ([sender selectedDOMRange])
    {
        SVTextDOMController *textController = [[self firstResponderItem] textDOMController];
        [textController addSelectionTypesToPasteboard:pasteboard];
        return YES;
    }
    else
    {
        // Want serialized pagelets on pboard
        SVGraphic *graphic = [[sender selectedItem] representedObject];
        if ([graphic isKindOfClass:[SVGraphic class]])
        {
            result = YES;
            
            [pasteboard addTypes:[NSArray arrayWithObject:kSVGraphicPboardType] owner:self];
            [graphic writeToPasteboard:pasteboard];
        }
        
        // Place HTML on pasteboard
        //[pasteboard setString:html forType:NSHTMLPboardType];
        //[html release];
        //[pasteboard addTypes:[NSArray arrayWithObject:NSHTMLPboardType] owner:self];
    }
    
    
    
    return result;
}

// Same as WebUIDelegate method, except it only gets called if .draggingDestinationDelegate rejected the drag
- (NSUInteger)webEditor:(WEKWebEditorView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo;
{
    NSUInteger result = WebDragDestinationActionDHTML;
    
    NSArray *types = [[draggingInfo draggingPasteboard] types];
    if (![types containsObject:kSVGraphicPboardType] &&
        ![types containsObject:@"com.karelia.html+graphics"])
    {
        result = result | WebDragDestinationActionEdit;
        
        // Don't drop graphics into text areas which don't support it
        id source = [draggingInfo draggingSource];
        if ([source isKindOfClass:[NSResponder class]] &&
            [sender ks_followsResponder:source] &&
            [sender selectedItem])
        {
            NSPoint location = [sender convertPointFromBase:[draggingInfo draggingLocation]];
            DOMRange *range = [[sender webView] editableDOMRangeForPoint:location];
            if (range)
            {
                SVTextDOMController *controller = [self textAreaForDOMRange:range];
                
                if (![[controller textBlock] importsGraphics])
                {
                    result = result - WebDragDestinationActionEdit;
                }
            }
        }
    }
    
    return result;
}

#pragma mark SVWebEditorViewDelegate

- (void)webEditorViewDidFirstLayout:(WEKWebEditorView *)sender;
{
    OBPRECONDITION(sender == [self webEditor]);
    [self webViewDidFirstLayout];
}

           - (BOOL)webEditor:(WEKWebEditorView *)sender
shouldChangeSelectedDOMRange:(DOMRange *)currentRange
                  toDOMRange:(DOMRange *)proposedRange
                    affinity:(NSSelectionAffinity)selectionAffinity
                       items:(NSArray *)proposedSelectedItems
              stillSelecting:(BOOL)stillSelecting;
{
    //  Update our content controller's selected objects to reflect the new selection in the Web Editor View
    
    OBPRECONDITION(sender == [self webEditor]);
    
    
    // HACK: Ignore these messages while loading as we'll sort out selection once the load is done
    BOOL result = YES;
    if (![self isUpdating])
    {
        // If there is a text selection, it may encompass more than a single object. If so, ignore selected items
        if (proposedRange)
        {
            switch ([proposedSelectedItems count])
            {    
                case 0:
                {
                    // Nothing directly selected, but the range may be inside a selectable element
                    WEKWebEditorItem *item = [sender selectableItemForDOMNode:
                                              [proposedRange commonAncestorContainer]];
                    
                    proposedSelectedItems = (item ? [NSArray arrayWithObject:item] : nil);
                    break;
                }
                    
                case 1:
                {
                    WEKWebEditorItem *item = [proposedSelectedItems objectAtIndex:0];
                    if (![proposedRange ks_selectsNode:[item HTMLElement]]) proposedSelectedItems = nil;
                    break;
                }
                    
                default:
                    proposedSelectedItems = nil;
            }
        }
        
                                                            
        // Match the controller's selection to the view
        NSArray *objects = [proposedSelectedItems valueForKey:@"representedObject"];
        result = [[self graphicsController] setSelectedObjects:objects];
    }
    
    return result;
}

- (void)webEditorDidChangeSelection:(NSNotification *)notification;
{
    WEKWebEditorView *webEditor = [notification object];
    OBPRECONDITION(webEditor == [self webEditor]);
    
    
    // Set our first responder item to match
    id controller = [webEditor focusedText];
    if (!controller)
    {
        NSSet *selection = [[NSSet alloc] initWithArray:[webEditor selectedItems]];
        NSSet *containerControllers = [selection valueForKey:@"textDOMController"];
        
        if ([containerControllers count] == 0)  // fallback to sidebar DOM controller
        {
            containerControllers = [selection valueForKey:@"sidebarDOMController"];
        }
        
        if ([containerControllers count] == 1)
        {
            controller = [containerControllers anyObject];
        }
    }
    [self setFirstResponderItem:controller];
    
    
    // Do something?? link related
    if (![[self webEditor] selectedDOMRange])
    {
        SVLink *link = NSNotApplicableMarker;
        @try
        {
            [[self graphicsController] valueForKeyPath:@"selection.link"];
        }
        @catch (NSException *exception)
        {
            if (![[exception name] isEqualToString:NSUndefinedKeyException]) @throw exception;
        }
        
        if (NSIsControllerMarker(link))
        {
            [[SVLinkManager sharedLinkManager] setSelectedLink:nil
                                                      editable:(link == NSMultipleValuesMarker)];
        }
        else
        {
            [[SVLinkManager sharedLinkManager] setSelectedLink:link editable:YES];
        }
    }
}

- (DOMRange *)webEditor:(WEKWebEditorView *)sender fallbackDOMRangeForNoSelection:(NSEvent *)selectionEvent;
{
    SVTextDOMController *item = (id)[self articleDOMController];
    DOMNode *articleNode = [item textHTMLElement];
    
    DOMRange *result = [[articleNode ownerDocument] createRange];
    
    NSPoint location = [[articleNode documentView] convertPointFromBase:[selectionEvent locationInWindow]];
    if (selectionEvent && location.y < NSMidY([articleNode boundingBox]))
    {
        [result setStartBefore:[articleNode firstChild]];
    }
    else
    {
        [result setStartAfter:[articleNode lastChild]];
    }
    
    return result;
}

- (BOOL)webEditor:(WEKWebEditorView *)sender createLink:(SVLinkManager *)actionSender;
{
    if (![sender selectedDOMRange])
    {
        SVLink *link = [actionSender selectedLink];
        [[self graphicsController] setValue:link forKeyPath:@"selection.link"];
        return YES;
    }
    
    return NO;
}

- (void)webEditor:(WEKWebEditorView *)sender didReceiveTitle:(NSString *)title;
{
    [self setTitle:title];
}

- (NSURLRequest *)webEditor:(WEKWebEditorView *)sender
            willSendRequest:(NSURLRequest *)request
           redirectResponse:(NSURLResponse *)redirectResponse
             fromDataSource:(WebDataSource *)dataSource;
{
    // Force the WebView to dump its cached resources from the WebDataSource so that any change to main.css gets picked up
    /*
    if ([[request mainDocumentURL] isEqual:[request URL]])
    {
        for (SVMediaRecord *aMediaRecord in [[self HTMLContext] media])
        {
            WebResource *resource = [aMediaRecord webResource];
            if (resource) [dataSource addSubresource:resource];
        }
        
        NSMutableURLRequest *result = [[request mutableCopy] autorelease];
        [result setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        return result;
    }    */
    
    
    // Preload main CSS
    if ([[request URL] ks_isEqualToURL:[[self HTMLContext] mainCSSURL]])
    {
        SVHTMLContext *context = [self HTMLContext];
        NSData *data = [[context mainCSS] dataUsingEncoding:NSUTF8StringEncoding];
        CFStringRef charSet = CFStringConvertEncodingToIANACharSetName(kCFStringEncodingUTF8);
        
        WebResource *resource = [[WebResource alloc] initWithData:data
                                                              URL:[request URL]
                                                         MIMEType:@"text/css"
                                                 textEncodingName:(NSString *)charSet
                                                        frameName:nil];
        [dataSource addSubresource:resource];
        [resource release];
}
    
    return request;
}

- (void)webEditor:(WEKWebEditorView *)sender handleNavigationAction:(NSDictionary *)actionInfo request:(NSURLRequest *)request;
{
    NSURL *URL = [actionInfo objectForKey:@"WebActionOriginalURLKey"];
    
    
    // A link to another page within the document should open that page. Let the delegate take care of deciding how to open it
    KTPage *myPage = [[self HTMLContext] page];
    NSURL *relativeURL = [URL URLRelativeToURL:[myPage URL]];
    NSString *relativePath = [relativeURL relativePath];
    
    if (([[URL scheme] isEqualToString:@"applewebdata"] || [relativePath hasPrefix:kKTPageIDDesignator]) &&
        [[actionInfo objectForKey:WebActionNavigationTypeKey] intValue] != WebNavigationTypeOther)
    {
        KTPage *page = [[myPage site] pageWithPreviewURLPath:relativePath];
        if (page)
        {
            [[self delegate] webEditorViewController:self openPage:page];
        }
        else if ([[self view] window])
        {
            [KSSilencingConfirmSheet alertWithWindow:[[self view] window]
                                        silencingKey:@"shutUpFakeURL"
                                               title:NSLocalizedString(@"Non-Page Link",@"title of alert")
                                              format:NSLocalizedString
             (@"You clicked on a link that would open a page that Sandvox cannot directly display.\n\n\t%@\n\nWhen you publish your website, you will be able to view the page with your browser.", @""),
             [URL path]];
        }
    }
    
    
    // Open normal links in the user's browser
    else if ([[URL scheme] isEqualToString:@"http"])
    {
        int navigationType = [[actionInfo objectForKey:WebActionNavigationTypeKey] intValue];
        switch (navigationType)
        {
            case WebNavigationTypeFormSubmitted:
            case WebNavigationTypeBackForward:
            case WebNavigationTypeReload:
            case WebNavigationTypeFormResubmitted:
                // 1.x allowed the webview to load these - do we want actually want to?
                break;
                
            case WebNavigationTypeOther:
                // Only allow the request if we're loading a page. BUGSID:26693 this stops meta tags refreshing the page
                break;
                
            default:
                // load with user's preferred browser:
                [[NSWorkspace sharedWorkspace] attemptToOpenWebURL:URL];
        }
    }
    
    // We used to do [listener use] for file: URLs. Why?
    // And again the fallback option for to -use. Why?
}

- (void)webEditorWillChange:(NSNotification *)notification;
{
    WEKWebEditorView *webEditor = [self webEditor];
    NSUndoManager *undoManager = [webEditor undoManager];
    
    // There's no point recording the action if registration is disabled. Especially since grabbing the selection is a relatively expensive op
    if ([undoManager isUndoRegistrationEnabled])
    {
        [[undoManager prepareWithInvocationTarget:self] 
         undo_setSelectedTextRange:[self selectedTextRange]];
    }
}

- (BOOL)webEditor:(WEKWebEditorView *)sender doCommandBySelector:(SEL)action;
{
    // Take over pasting if the Web Editor can't support it
    if (action == @selector(paste:) && ![sender validateAction:action])
    {
        [self paste:nil];
        return YES;
    }
    else if (action == @selector(moveUp:) || action == @selector(moveDown:))
    {
        for (WEKWebEditorItem *anItem in [sender selectedItems])
        {
            if ([anItem sidebarDOMController])
            {
                [[_graphicsController sidebarPageletsController] performSelector:action
                                                                      withObject:nil];
                break;
            }
        }        
    }
    else if (action == @selector(reload:))
    {
        [self doCommandBySelector:action];
    }
    
    
    return NO;
}

- (void)webEditor:(WEKWebEditorView *)sender didAddItem:(WEKWebEditorItem *)item;
{
    OBPRECONDITION(sender == [self webEditor]);
    [self registerWebEditorItem:item];
}

- (void)webEditor:(WEKWebEditorView *)sender willRemoveItem:(WEKWebEditorItem *)item;
{
    OBPRECONDITION(sender == [self webEditor]);
    [self unregisterWebEditorItem:item];
}

#pragma mark NSDraggingDestination

- (NSObject *)destinationForDraggingInfo:(id <NSDraggingInfo>)dragInfo;
{
    WEKWebEditorView *webEditor = [self webEditor];
    
    NSDictionary *element = [[webEditor webView] elementAtPoint:
                             [webEditor convertPointFromBase:[dragInfo draggingLocation]]];
    
    DOMNode *node = [element objectForKey:WebElementDOMNodeKey];
    
    id result = [[webEditor contentItem] hitTestDOMNode:node draggingInfo:dragInfo];
    
    if (!result)
    {
        // Don't allow drops of pagelets inside non-page body text.
        if ([dragInfo draggingSource] == webEditor && [[webEditor draggedItems] count])
        {
            if (![[[[[self textAreaForDOMNode:node] representedObject] entity] name]
                  isEqualToString:@"Article"])
            {
                result = nil;
            }
        }
    }
    
    
    return result;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    _draggingDestination = [self destinationForDraggingInfo:sender];
    return [_draggingDestination draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
{
    NSObject *destination = [self destinationForDraggingInfo:sender];
    
    // Switching to a new drag target, so tell the old one drag exited
    if (destination == _draggingDestination)
    {
        return [_draggingDestination draggingUpdated:sender];
    }
    else
    {
        if ([_draggingDestination respondsToSelector:@selector(draggingExited:)])
        {
            [_draggingDestination draggingExited:sender];
        }
        
        _draggingDestination = destination;
        return [_draggingDestination draggingEntered:sender];
    }
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    if ([_draggingDestination respondsToSelector:_cmd]) [_draggingDestination draggingExited:sender];
    _draggingDestination = nil;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
{
    BOOL result = YES;
    
    if ([_draggingDestination respondsToSelector:_cmd])
    {
        result = [_draggingDestination prepareForDragOperation:sender];
    }
    
    return result;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
    BOOL result = [_draggingDestination performDragOperation:sender];
    return result;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;
{
    if ([_draggingDestination respondsToSelector:_cmd])
    {
        [_draggingDestination concludeDragOperation:sender];
    }
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender;
{
    if ([_draggingDestination respondsToSelector:_cmd])
    {
        [_draggingDestination draggingEnded:sender];
    }
    _draggingDestination = nil;
}

@end

