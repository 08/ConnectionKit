//
//  KTPage+Web.m
//  KTComponents
//
//  Created by Dan Wood on 8/9/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTPage+Paths.h"

#import "KT.h"
#import "KTSite.h"
#import "SVApplicationController.h"
#import "SVArchivePage.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTElementPlugInWrapper.h"
#import "SVHTMLContext.h"
#import "SVHTMLTextBlock.h"
#import "SVHTMLTemplateParser.h"
#import "KTMaster.h"
#import "SVPublisher.h"
#import "SVTitleBox.h"
#import "SVWebEditorHTMLContext.h"

#import "NSBundle+KTExtensions.h"

#import "NSBundle+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"
#import "KSURLUtilities.h"
#import "NSObject+Karelia.h"

#import <WebKit/WebKit.h>

#import "Registration.h"


@interface SVSiteMenuItem : NSObject
{
	SVSiteItem *_siteItem;
	NSMutableArray *_childItems;
}
@property (retain) SVSiteItem *siteItem;
@property (retain) NSMutableArray *childItems;
- (BOOL)containsSiteItem:(SVSiteItem *)aSiteItem;

@end

@implementation SVSiteMenuItem

@synthesize siteItem = _siteItem;
@synthesize childItems = _childItems;

- (id)initWithSiteItem:(SVSiteItem *)aSiteItem
{
	if ((self = [super init]) != nil)
	{
		self.siteItem = aSiteItem;
		self.childItems = [NSMutableArray array];
	}
	return self;
}

- (BOOL)containsSiteItem:(SVSiteItem *)aSiteItem;
{
	if (self.siteItem == aSiteItem)
	{
		return YES;
	}
	for (SVSiteMenuItem *childMenuItem in self.childItems)
	{
		if ([childMenuItem containsSiteItem:aSiteItem])
		{
			return YES;	// recurse
		}
	}
	return NO;
}

- (NSUInteger)hash
{
	return [[[[self siteItem] objectID] description] hash];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: %@, children: %@", [self class], self.siteItem, self.childItems];
}

@end



@implementation KTPage (Web)

#pragma mark HTML

- (NSString *)markupString;   // creates a temporary HTML context and calls -writeHTML
{
    SVHTMLContext *context = [[SVHTMLContext alloc] init];	
	[context writeDocumentWithPage:self];
    
    NSString *result = [[context outputStringWriter] string];
    [context release];
    return result;
}

- (NSString *)markupStringForEditing;   // for viewing source for debugging purposes.
{
    SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc] init];
	[context writeDocumentWithPage:self];
    
	NSString *result = [[context outputStringWriter] string];
    [context release];
    
    return result;
}

+ (NSString *)pageTemplate
{
	static NSString *sPageTemplateString = nil;
	
	if (!sPageTemplateString)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] overridingPathForResource:@"KTPageTemplate" ofType:@"html"];
		NSData *data = [NSData dataWithContentsOfFile:path];
		sPageTemplateString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	
	return sPageTemplateString;
}

+ (NSString *)pageMainContentTemplate;
{
	static NSString *sPageTemplateString = nil;
	
	if (!sPageTemplateString)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] overridingPathForResource:@"KTPageMainContentTemplate" ofType:@"html"];
		NSData *data = [NSData dataWithContentsOfFile:path];
		sPageTemplateString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	
	return sPageTemplateString;
}

- (void)writeMainContent
{
    SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    
    SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:[[self class] pageMainContentTemplate]
                                                                        component:[context page]];
    
    [context setCurrentHeaderLevel:3];
    [parser parseIntoHTMLContext:context];
    [parser release];
}

#pragma mark Code injection

- (BOOL)canWriteCodeInjection:(SVHTMLContext *)aContext;
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return ([aContext isForPublishingProOnly]
		
		// Show the code injection in the webview as well, as long as this default is set.
		|| ([defaults boolForKey:@"ShowCodeInjectionInPreview"]) && [aContext isForEditing]
		
			);
}

- (void)write:(SVHTMLContext *)context codeInjectionSection:(NSString *)aKey masterFirst:(BOOL)aMasterFirst;
{
    OBPRECONDITION(context);
    
    if ([self canWriteCodeInjection:context])
	{
        NSString *masterCode = [[[self master] codeInjection] valueForKey:aKey];
		NSString *pageCode = [[self codeInjection] valueForKey:aKey];
        
		if (masterCode && aMasterFirst)		{	[context startNewline]; [context writeString:masterCode];	}
        if (pageCode)						{	[context startNewline]; [context writeString:pageCode];		}
		if (masterCode && !aMasterFirst)	{	[context startNewline]; [context writeString:masterCode];	}
    }
}

- (void)writeCodeInjectionSection:(NSString *)aKey masterFirst:(BOOL)aMasterFirst;
{
	SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    [self write:context codeInjectionSection:aKey masterFirst:aMasterFirst];
}

// Note: For the paired code injection points -- the start and end of the head, and the body -- we flip around
// the ordering so we can do thing like nesting output buffers in PHP. Page is more "local" than master.

- (void)writeCodeInjectionEarlyHead		{	[self writeCodeInjectionSection:@"earlyHead"	masterFirst:YES];	}
- (void)writeCodeInjectionHeadArea		{	[self writeCodeInjectionSection:@"headArea"		masterFirst:NO];	}
- (void)writeCodeInjectionBodyTagStart	{	[self writeCodeInjectionSection:@"bodyTagStart"	masterFirst:YES];	}
- (void)writeCodeInjectionBodyTagEnd	{	[self writeCodeInjectionSection:@"bodyTagEnd"	masterFirst:NO];	}
- (void)writeCodeInjectionBeforeHTML	{	[self writeCodeInjectionSection:@"beforeHTML"	masterFirst:NO];	}

// Special case: Show a space in between the two; no newlines.
- (void)writeCodeInjectionBodyTag
{
	SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    if ([self canWriteCodeInjection:context])
    {
        NSString *masterCode = [[[self master] codeInjection] valueForKey:@"bodyTag"];
		NSString *pageCode = [[self codeInjection] valueForKey:@"bodyTag"];
		
		if (masterCode)				[context writeString:masterCode];
		if (masterCode && pageCode)	[context writeText:@" "];	// space in between, only if we have both
		if (pageCode)				[context writeString:pageCode];
    }
}

#pragma mark Comments

- (NSString *)commentsTemplate	// instance method too for key paths to work in tiger
{
	static NSString *result;
	
	if (!result)
	{
		NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"KTCommentsTemplate" ofType:@"html"];
		result = [[NSString alloc] initWithContentsOfFile:templatePath];
	}
	
	return result;
}

#pragma mark CSS

/*  Used by KTPageTemplate.html to generate links to the stylesheets needed by this page. Used to be a dedicated [[stylesheet]] parser function
 */
- (void)writeStylesheetLinks
{
    SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    NSString *path = nil;
    
    // Write link to main.CSS file -- the most specific
    NSURL *mainCSSURL = [context mainCSSURL];
    if (mainCSSURL)
    {
        [context writeLinkToStylesheet:[context relativeURLStringOfURL:mainCSSURL]
                                 title:[[[self master] design] title]
                                 media:nil];
    }
	
	
	// design's print.css but not for Quick Look
    if ([context isForPublishing])
	{
        NSURL *printCSSURL = [context URLOfDesignFile:@"print.css"];
        if ( printCSSURL )
        {
            path = [context relativeURLStringOfURL:printCSSURL];
            if (path)
            {
                [context writeLinkToStylesheet:path title:nil media:@"print"];
            }
        }
	}
}

#pragma mark Publishing

- (void)publish:(id <SVPublisher>)publishingEngine recursively:(BOOL)recursive;
{
    NSString *path = [self uploadPath];
    SVHTMLContext *context = [publishingEngine beginPublishingHTMLToPath:path];
	
    [context writeDocumentWithPage:self];
    
    
	// Generate and publish RSS feed if needed
	if ([[self collectionSyndicationType] boolValue])
	{
		NSString *RSSFilename = [self RSSFileName];
        NSString *RSSUploadPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:RSSFilename];
        
        SVHTMLContext *context = [publishingEngine beginPublishingHTMLToPath:RSSUploadPath];
        [self writeRSSFeed:context];
        [context close];
	}
    
    
    // Publish archives
    for (SVArchivePage *anArchivePage in [self archivePages])
    {
        SVHTMLContext *context = [publishingEngine beginPublishingHTMLToPath:
                                  [anArchivePage uploadPath]];
        
        [context writeDocumentWithArchivePage:anArchivePage];
        [context close];
    }
    
    
    // Want the page itself to be placed on the queue last, so if publishing fails between the two, both will be republished next time round
    [context close];
    
    
    // Continue onto the next page if the app is licensed
    if (recursive && !gLicenseIsBlacklisted && gRegistrationString)
    {
        for (SVSiteItem *anItem in [self sortedChildren])
        {
            if (![[anItem isDraft] boolValue])
            {
                [anItem publish:publishingEngine recursively:recursive];
            }
        }
    }
}

#pragma mark Other

/*!	Generate path to javascript.  Nil if not there */
- (NSString *)javascriptURLPath	// loaded after jquery so this can contain jquery in it.
{
	NSString *result = nil;
	
	NSBundle *designBundle = [[[self master] design] bundle];
	BOOL scriptExists = ([designBundle pathForResource:@"javascript" ofType:@"js"] != nil);
	if (scriptExists)
	{
		NSURL *javascriptURL = [NSURL URLWithString:@"javascript.js" relativeToURL:[[self master] designDirectoryURL]];
		result = [javascriptURL ks_stringRelativeToURL:[self URL]];
	}
	
	return result;
}


/*!	Return the string that makes up the title.  Page Title | Site Title | Author ... this is the DEFAULT if not set by windowTitle property.
*/
- (NSString *)comboTitleText
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *titleSeparator = [defaults objectForKey:@"TitleSeparator"];
	
	if ( [self isDeleted] || (nil == [[self site] rootPage]) )
	{
		return @"Bad Page!";
	}
	
	NSMutableString *buf = [NSMutableString string];
	
	BOOL needsSeparator = NO;
	NSString *title = [[self titleBox] text];
	if ( nil != title && ![title isEqualToString:@""])
	{
		[buf appendString:title];
		needsSeparator = YES;
	}
	
	
	NSString *siteTitleText = [[[[self master] siteTitle] textHTMLString] stringByConvertingHTMLToPlainText];
	if ( (nil != siteTitleText) && ![siteTitleText isEqualToString:@""] && ![siteTitleText isEqualToString:title] )
	{
		if (needsSeparator)
		{
			[buf appendString:titleSeparator];
		}
		[buf appendString:siteTitleText];
		needsSeparator = YES;
	}
	
	NSString *author = [[self master] valueForKey:@"author"];
	if (nil != author
		&& ![author isEqualToString:@""]
		&& ![author isEqualToString:siteTitleText]
		)
	{
		if (needsSeparator)
		{
			[buf appendString:titleSeparator];
		}
		[buf appendString:author];
	}
	
	if ([buf isEqualToString:@""])
	{
		buf = [NSMutableString stringWithString:NSLocalizedString(@"Untitled Page","fallback page title if no title is otherwise found")];
	}
	
	return buf;
}

#pragma mark DTD

// For code review:  Where can this utility class go?
+ (NSString *)stringFromDocType:(KTDocType)docType local:(BOOL)isLocal;
{
	NSString *result = nil;
	if (isLocal)
	{
		NSURL *dtd = nil;
		switch (docType)
		{
			case KTHTML401DocType:
				dtd = nil;	// don't load a local DTD for HTML 4.01
				result = [NSString stringWithFormat:@"<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"%@\">", [dtd absoluteString]];
				break;
			case KTXHTMLTransitionalDocType:
				dtd = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"xhtml1-transitional" ofType:@"dtd" inDirectory:@"DTD"]];
				result = [NSString stringWithFormat:@"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"%@\">", [dtd absoluteString]];
				break;
			case KTXHTMLStrictDocType:
				dtd = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"xhtml1-strict" ofType:@"dtd" inDirectory:@"DTD"]];
				result = [NSString stringWithFormat:@"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"%@\">", [dtd absoluteString]];
				break;
			case KTHTML5DocType:
				result = [NSString stringWithFormat:@"<!DOCTYPE html>"];	// Do we do something special to deal with DTDs?
				break;
			default:
				break;
		}
		
	}
	else
	{
		result = [SVHTMLContext stringFromDocType:docType];
	}
	return result;
}

#pragma mark Site Menu

- (void)writeMenu:(SVHTMLContext *)context
 forSiteMenuItems:(NSArray *)anArray
        treeLevel:(int)aTreeLevel
{
	KTPage *currentParserPage = [context page];
	
	[context startElement:@"ul" idName:nil className:nil];

	int i=1;	// 1-based iteration
	int last = [anArray count];

	for (SVSiteMenuItem *item in anArray)
	{
		SVSiteItem *siteItem = item.siteItem;
		NSArray *children = item.childItems;

		if (siteItem == currentParserPage)
		{
			[context startElement:@"li" idName:nil className:
			 [NSString stringWithFormat:@"i%d %@%@%@ currentPage", i, (i%2)?@"o":@"e", (i==last)? @" last" : @"", [children count] ? @" hasSubmenu" : @""]];
		}
		else
		{
			// define currentParent as being that this menu item is along the path to the currently generated page.
			BOOL isCurrentParent = (currentParserPage != siteItem
									&& [currentParserPage isDescendantOfItem:siteItem]
									&& [item containsSiteItem:currentParserPage]
									);
			
			[context startElement:@"li" idName:nil className:
			 [NSString stringWithFormat:@"i%d %@%@%@%@",
			  i,
			  (i%2)?@"o":@"e",
			  (i==last)? @" last" : @"",
			  [children count] ? @" hasSubmenu" : @"",
			  isCurrentParent ? @" currentParent" : @""
			  ]];
			
			NSString *urlString = [context relativeURLStringOfURL:[siteItem URL]];
			
			[context startAnchorElementWithHref:urlString title:[siteItem title] target:nil rel:nil];
			// TODO: targetStringForPage:targetPage
		}
		
		// Build a text block
		SVHTMLTextBlock *textBlock = [[[SVHTMLTextBlock alloc] init] autorelease];
		
		[textBlock setEditable:NO];
		[textBlock setFieldEditor:NO];
		[textBlock setRichText:NO];
		[textBlock setImportsGraphics:NO];
		[textBlock setTagName:@"span"];
		
		[textBlock setHTMLSourceObject:siteItem];
		[textBlock setHTMLSourceKeyPath:@"menuTitle"];
		
		[textBlock writeHTML:context];
		
		if (siteItem != currentParserPage)
		{
			[context endElement];	// a
		}
		
		if ([children count])
		{
			[self writeMenu:context forSiteMenuItems:children treeLevel:aTreeLevel+1];
			[context endElement];	// li
        }
		else
		{
			[context endElement];	// li
		}
		i++;
	}
	[context endElement];	// ul
}


// Create the site menu forest.  Needed in both writeHierMenuLoader and writeSiteMenu.  Maybe cache value later?

- (NSArray *)createSiteMenuForestIsHierarchical:(BOOL *)outHierarchical;
{
	BOOL isHierarchical = NO;
	KTSite *site = self.site;
	NSArray *pagesInSiteMenu = site.pagesInSiteMenu;

	HierMenuType hierMenuType = [[[self master] design] hierMenuType];
	NSMutableArray *forest = [NSMutableArray array];
	if (HIER_MENU_NONE == hierMenuType)
	{
		// Flat menu, either by design's preference or user default
		for (SVSiteItem *siteMenuItem in pagesInSiteMenu)
		{
			if ([siteMenuItem shouldIncludeInSiteMenu])
			{
				SVSiteMenuItem *item = [[[SVSiteMenuItem alloc] initWithSiteItem:siteMenuItem] autorelease];
				[forest addObject:item];
			}
		}
	}
	else	// hierarchical menu
	{
		// build up the hierarchical site menu.
		// Array of dictionaries keyed with "page" and "children" array
		NSMutableArray *childrenLookup = [NSMutableArray array];
		// Assume we are traversing tree in sorted order, so children will always be found after parent, which makes it easy to build this tree.
		for (SVSiteItem *siteMenuItem in pagesInSiteMenu)
		{
			if ([siteMenuItem shouldIncludeInSiteMenu])
			{
				BOOL wasSubPage = NO;
				KTPage *parent = (KTPage *)siteMenuItem;		// Parent will *always* be a KTPage once we calculate it
				SVSiteMenuItem *item = nil;
				do // loop through, looking to see if this (or parent) page is a sub-page of an already-found page in the site menu.
				{
					SVSiteMenuItem *itemToAddTo = nil;
					// See if this is already known about
					for (SVSiteMenuItem *checkItem in childrenLookup)
					{
						if (checkItem.siteItem == parent)
						{
							itemToAddTo = checkItem;
							break;
						}
					}					
					if (itemToAddTo)	// Was there a parent menu item?
					{
						// If so, create a new entry for this page, with an empty array of children; add to list of children
						item = [[[SVSiteMenuItem alloc] initWithSiteItem:siteMenuItem] autorelease];
						[itemToAddTo.childItems addObject:item];
						parent = nil;	// stop looking
						wasSubPage = YES;
						isHierarchical = YES;		// there is a hierarchical menu here
					}
					else // No, this page (or its parent) was not in the menu list so go up one level to keep looking.
					{
						parent = [parent parentPage];
					}
				}
				while (nil != parent && ![parent isRoot]);	// Stop when we reach root. Note that we don't put items under root.
				
				if (!item)
				{
					item = [[[SVSiteMenuItem alloc] initWithSiteItem:siteMenuItem] autorelease];
				}
				[childrenLookup addObject:item];		// quick lookup from page to children
				
				if (!wasSubPage)	// Not a sub-page, so it's a top-level menu item.
				{
					[forest addObject:item];		// Add to our list of top-level menus
				}
			}
		}	// end for
	}
	if (outHierarchical)
	{
		*outHierarchical = isHierarchical;
	}
	return forest;
}


- (void)writeHierMenuLoader
{
	HierMenuType hierMenuType = [[[self master] design] hierMenuType];
	if (HIER_MENU_NONE != hierMenuType && self.site.pagesInSiteMenu.count)
	{
		// Now check if we *really* have a hierarchy.  No point in writing out loader if site menu is flat.
		BOOL isHierarchical = NO;
		(void) [self createSiteMenuForestIsHierarchical:&isHierarchical];
		if (isHierarchical)
		{
			SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
			
			NSString *path = nil;
			NSURL *src = nil;
			
			// Note: We want to add the CSS as a separate link; *not* merging it into main.css, so that it can access the arrow images in _Resources.
			path = [[NSBundle mainBundle] overridingPathForResource:@"ddsmoothmenu" ofType:@"css"];
			src = [context addResourceWithURL:[NSURL fileURLWithPath:path]];
			[context writeLinkToStylesheet:[src absoluteString] title:nil media:nil];	// nil title; we don't want a title! https://bugs.webkit.org/show_bug.cgi?id=43870
			
			path = [[NSBundle mainBundle] overridingPathForResource:@"ddsmoothmenu" ofType:@"js"];
			src = [context addResourceWithURL:[NSURL fileURLWithPath:path]];
			
			NSString *prelude = [NSString stringWithFormat:@"\n%@\n%@\n%@\n%@\n%@", 
@"/***********************************************",
@"* Smooth Navigational Menu- (c) Dynamic Drive DHTML code library (www.dynamicdrive.com)",
@"* This notice MUST stay intact for legal use",
@"* Visit Dynamic Drive at http://www.dynamicdrive.com/ for full source code",
@"***********************************************/"];
			
			[context startJavascriptElementWithSrc:[src absoluteString]];
			[context stopWritingInline];
			[context writeString:prelude];
			[context endElement];
			
			/*
			 These are ddsmoothmenu's options we could set here, or maybe I could modify the JS file that gets uploaded....
			 
			 //Specify full URL to down and right arrow images (23 is padding-right added to top level LIs with drop downs):
			 arrowimages: {down:['downarrowclass', 'down.gif', 23], right:['rightarrowclass', 'right.gif']},
			 transition: {overtime:300, outtime:300}, //duration of slide in/ out animation, in milliseconds
			 shadow: {enable:true, offsetx:5, offsety:5}, //enable shadow?
			 showhidedelay: {showdelay: 100, hidedelay: 200}, //set delay in milliseconds before sub menus appear and disappear, respectively
			 */
			
			NSURL *arrowDown = [NSURL fileURLWithPath:[[NSBundle mainBundle]
													   pathForResource:@"down"
													   ofType:@"gif"]];
			NSURL *arrowDownSrc = [context addResourceWithURL:arrowDown];
			NSURL *arrowRight = [NSURL fileURLWithPath:[[NSBundle mainBundle]
														pathForResource:@"right"
														ofType:@"gif"]];
			NSURL *arrowRightSrc = [context addResourceWithURL:arrowRight];
			
			[context startJavascriptElementWithSrc:nil];
			
			// [context startJavascriptCDATA];		// probably not needed
			[context writeString:[NSString stringWithFormat:
								  @"ddsmoothmenu.arrowimages = {down:['downarrowclass', '%@', 23], right:['rightarrowclass', '%@']}",
								  [arrowDownSrc absoluteString], [arrowRightSrc absoluteString]]];
			[context writeString:@"\n"];
			
			BOOL isVertical = hierMenuType == HIER_MENU_VERTICAL || (hierMenuType == HIER_MENU_VERTICAL_IF_SIDEBAR && [[self showSidebar] boolValue]);
			
			[context writeString:[NSString stringWithFormat:
								  @"ddsmoothmenu.init({ mainmenuid: 'sitemenu-content',orientation:'%@', classname:'%@',contentsource:'markup'})",					  
								  (isVertical ? @"v" : @"h"),
								  (isVertical ? @"ddsmoothmenu-v" : @"ddsmoothmenu")]];
			// [context endJavascriptCDATA];
			[context endElement];
		}
	}
}

- (void)writeSiteMenu
{
	if (self.site.pagesInSiteMenu.count)	// Are there any pages in the site menu?
	{
		SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
		
		[context addDependencyOnObject:self keyPath:@"site.pagesInSiteMenu"];

		[context startElement:@"div" idName:@"sitemenu" className:nil];			// <div id="sitemenu">
		[context startElement:@"h2" idName:nil className:@"hidden"];				// hidden skip navigation menu
		[context writeString:
		 NSLocalizedStringWithDefaultValue(@"skipNavigationTitleHTML", nil, [NSBundle mainBundle], @"Site Navigation", @"Site navigation title on web pages (can be empty if link is understandable)")];

		[context startAnchorElementWithHref:@"#page-content" title:nil target:nil rel:@"nofollow"];
		[context writeString:NSLocalizedStringWithDefaultValue(@"skipNavigationLinkHTML", nil, [NSBundle mainBundle], @"[Skip]", @"Skip navigation LINK on web pages")];
		
		[context endElement];	// a
		[context endElement];	// h2
		
		
		[context startElement:@"div" idName:@"sitemenu-content" className:nil];		// <div id="sitemenu-content">
	
		
		NSArray *forest = [self createSiteMenuForestIsHierarchical:nil];
		[self writeMenu:context forSiteMenuItems:forest treeLevel:0];

		
		
		[context writeEndTagWithComment:@"/sitemenu-content"];
		[context writeEndTagWithComment:@"/sitemenu"];
	}
}
/*
 Based on this template markup:
 [[if site.pagesInSiteMenu]]
	 <div id='sitemenu'>
		 <h2 class='hidden'>[[`skipNavigationTitleHTML]]<a rel='nofollow' href='#page-content'>[[`skipNavigationLinkHTML]]</a></h2>
		 <div id='sitemenu-content'>
			 <ul>
				 [[forEach site.pagesInSiteMenu toplink]]
					 [[if toplink==parser.currentPage]]
						 <li class='[[i]] [[eo]][[last]] currentPage'>
							[[textblock property:toplink.menuTitle graphicalTextCode:mc tag:span]]
						 </li>
					 [[else2]]
						 <li class='[[i]] [[eo]][[last]][[if !parser.currentPage.includeInSiteMenu]][[if toplink==parser.currentPage.parentPage]][[if parser.currentPage.parentPage.index]] currentParent[[endif5]][[endif4]][[endif3]]'>
							 <a [[target toplink]]href='[[path toplink]]' title='[[=&toplink.titleText]]'>
							 [[textblock property:toplink.menuTitle graphicalTextCode:m tag:span]]</a>
						 </li>
					 [[endif2]]
				 [[endForEach]]
			 </ul>
		 </div> <!-- sitemenu-content -->
	 </div> <!-- sitemenu -->
 [[endif]]
*/ 

@end
