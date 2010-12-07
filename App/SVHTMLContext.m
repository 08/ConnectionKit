//
//  SVHTMLContext.m
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorHTMLContext.h"

#import "KTDesign.h"
#import "SVEnclosure.h"
#import "KTHostProperties.h"
#import "SVHTMLTemplateParser.h"
#import "SVHTMLTextBlock.h"
#import "KTMaster.h"
#import "SVMediaGraphic.h"
#import "KTPage.h"
#import "KTSite.h"
#import "SVTemplate.h"
#import "SVTextAttachment.h"
#import "SVTextBox.h"
#import "SVTitleBox.h"
#import "SVWebEditingURL.h"

#import "SVCalloutDOMController.h"  // don't like having to do this

#import "NSIndexPath+Karelia.h"
#import "NSString+Karelia.h"
#import "KSURLUtilities.h"
#import "NSObject+Karelia.h"

#import "KSStringWriter.h"

#import "Registration.h"


@interface SVHTMLIterator : NSObject
{
    NSUInteger  _iteration;
    NSUInteger  _count;
}

- (id)initWithCount:(NSUInteger)count;
@property(nonatomic, readonly) NSUInteger count;

@property(nonatomic, readonly) NSUInteger iteration;
- (NSUInteger)nextIteration;

@end


@interface SVHTMLContext ()
- (BOOL)isWritingCallout;
@property(nonatomic, retain, readonly) KSMegaBufferedWriter *calloutBuffer;

- (void)pushAttributes:(NSDictionary *)attributes;

- (SVHTMLIterator *)currentIterator;
@end


#pragma mark -


@implementation SVHTMLContext

#pragma mark Init & Dealloc

- (id)initWithOutputWriter:(id <KSWriter>)output; // designated initializer
{
    // Buffer for grouping callouts
    _calloutBuffer = [[KSMegaBufferedWriter alloc] initWithOutputWriter:output];
    [_calloutBuffer setDelegate:self];
    
    
    [super initWithOutputWriter:_calloutBuffer];
    
    
    _includeStyling = YES;
    
    _liveDataFeeds = YES;
    
    _docType = KTXHTMLTransitionalDocType;
    _maxDocType = NSIntegerMax;
    
    _headerLevel = 1;
    
    _headerMarkup = [[NSMutableString alloc] init];
    _endBodyMarkup = [[NSMutableString alloc] init];
    _iteratorsStack = [[NSMutableArray alloc] init];
    
    return self;
}

- (id)initWithOutputStringWriter:(KSStringWriter *)output;
{
    if (self = [self initWithOutputWriter:output])
    {
        _output = [output retain];
    }
    
    return self;
}

- (id)init;
{
    KSStringWriter *output = [[KSStringWriter alloc] init];
    self = [self initWithOutputStringWriter:output];
    [output release];
    return self;
}

- (id)initWithOutputWriter:(id <KSWriter>)output inheritFromContext:(SVHTMLContext *)context;
{
    NSStringEncoding encoding = (context ? [context encoding] : NSUTF8StringEncoding);
    
    if (self = [self initWithOutputWriter:output encoding:encoding])
    {
        // Copy across properties
        [self setIndentationLevel:[context indentationLevel]];
        _currentPage = [[context page] retain];
        _baseURL = [[context baseURL] copy];
        [self setIncludeStyling:[context includeStyling]];
        [self setLiveDataFeeds:[context liveDataFeeds]];
        [self setDocType:[context docType]];
    }
    
    return self;
}

- (void)dealloc
{
    [_language release];
    [_baseURL release];
    [_currentPage release];
    
    [_mainCSSURL release];
        
    [_headerMarkup release];
    [_endBodyMarkup release];
    [_iteratorsStack release];
    
    [super dealloc];
    
    OBASSERT(!_calloutBuffer);
    OBASSERT(!_output);
}

#pragma mark Status

- (void)reset;
{
    [[self outputStringWriter] removeAllCharacters];
}

#pragma mark Document

- (void)startDocumentWithPage:(KTPage *)page
{
    OBPRECONDITION(page);
    
    
    // Store the page
    [page retain];
    [_currentPage release]; _currentPage = page;
    
    id article = [[page article] retain];
    [_article release]; _article = article;
    
    
	// Prepare global properties
    [self setLanguage:[[page master] language]];
    
    
    // For publishing, want to know the URL of main.css *on the server*
    if (![self isForEditing])
    {
        NSURL *cssURL = [self URLOfDesignFile:@"main.css"];
        [_mainCSSURL release]; _mainCSSURL = [cssURL copy];
    }
    
    
    // First Code Injection
	[page write:self codeInjectionSection:@"beforeHTML" masterFirst:NO];
    
    
    // Start the document
    KTDocType docType = [self docType];
    [self startDocument:[[self class] stringFromDocType:docType]
               encoding:[[[page master] charset] encodingFromCharset]
                isXHTML:(docType >= KTXHTMLTransitionalDocType)];
    
    
    // Global CSS
    NSString *path = [[NSBundle mainBundle] pathForResource:@"sandvox" ofType:@"css"];
    if (path) [self addCSSWithURL:[NSURL fileURLWithPath:path]];
}

- (void)writeDocumentContentsWithPage:(KTPage *)page;
{
    // It's template time!
	SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithPage:page];
    [parser parseIntoHTMLContext:self];
    [parser release];
    
    
    // Now, did that change the doctype? Retry if possible!
    if (_maxDocType > KTHTML5DocType) _maxDocType = KTXHTMLTransitionalDocType;
    if (_maxDocType != [self docType])
    {
        if ([self outputStringWriter])
        {
            [self reset];
            [self setDocType:_maxDocType];
            [self writeDocumentWithPage:page];
        }
    }
	
    
    // If we're for editing, include additional editing CSS. Used to write the design CSS just here as well, but that interferes with animations. #96704
	if ([self isForEditing])
	{
		NSString *editingCSSPath = [[NSBundle mainBundle] pathForResource:@"design-time"
                                                                   ofType:@"css"];
        if (editingCSSPath) [self addCSSWithURL:[NSURL fileURLWithPath:editingCSSPath]];
	}    
}

- (void)writeDocumentWithPage:(KTPage *)page;
{
    [self startDocumentWithPage:page];
    [self writeDocumentContentsWithPage:page];
}

- (void)writeDocumentWithArchivePage:(SVArchivePage *)archive;
{
    KTPage *collection = [archive collection];
    [self startDocumentWithPage:collection];
    
    [self setBaseURL:[archive URL]];
    
    [_article release];
    _article = [archive retain];
    
    [self writeDocumentContentsWithPage:collection];
}

#pragma mark Properties

@synthesize outputStringWriter = _output;
@synthesize totalCharactersWritten = _charactersWritten;

@synthesize baseURL = _baseURL;
@synthesize liveDataFeeds = _liveDataFeeds;
@synthesize language = _language;

#pragma mark Doctype

@synthesize docType = _docType;

- (void)limitToMaxDocType:(KTDocType)docType;
{
    if (docType < _maxDocType) _maxDocType = docType;
}

+ (NSString *)titleOfDocType:(KTDocType)docType  localize:(BOOL)shouldLocalizeForDisplay;
{
	NSString *result = nil;
	NSString *localizedResult = nil;
	switch (docType)
	{
		case KTHTML401DocType:
			result = @"HTML 4.01 Transitional";
			localizedResult = NSLocalizedString(@"HTML 4.01", @"Description of style of HTML - note that we do not say Transitional");
			break;
		case KTXHTMLTransitionalDocType:
			result = @"XHTML 1.0 Transitional";
			localizedResult = NSLocalizedString(@"XHTML 1.0 Transitional", @"Description of style of HTML");
			break;
		case KTXHTMLStrictDocType:
			result = @"XHTML 1.0 Strict";
			localizedResult = NSLocalizedString(@"XHTML 1.0 Strict", @"Description of style of HTML");
			break;
		case KTHTML5DocType:
			result = @"HTML5";
			localizedResult = NSLocalizedString(@"HTML5", @"Description of style of HTML");
			break;
		default:
			break;
	}
	return shouldLocalizeForDisplay ? localizedResult : result;
}

+ (NSString *)stringFromDocType:(KTDocType)docType;
{
    NSString *result = nil;
	
    switch (docType)
    {
        case KTHTML401DocType:
            result = @"<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">";
            break;
        case KTXHTMLTransitionalDocType:
            result = @"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">";
            break;
        case KTXHTMLStrictDocType:
            result = @"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">";
            break;
        case KTHTML5DocType:
            result = [NSString stringWithFormat:@"<!DOCTYPE html>"];
            break;
        default:
            break;
    }
    
    return result;
}

#pragma mark Purpose

- (KTHTMLGenerationPurpose)generationPurpose; { return kSVHTMLGenerationPurposeNormal; }

- (BOOL)isForEditing; { return [self generationPurpose] == kSVHTMLGenerationPurposeEditing; }

- (BOOL)isEditable { return [self isForEditing]; }  // left in for compat. for now
+ (NSSet *)keyPathsForValuesAffectingEditable
{
    return [NSSet setWithObject:@"generationPurpose"];
}

- (BOOL)isForQuickLookPreview;
{
    BOOL result = [self generationPurpose] == kSVHTMLGenerationPurposeQuickLookPreview;
    return result;
}

- (BOOL)isForPublishing
{
    BOOL result = [self generationPurpose] == kSVHTMLGenerationPurposeNormal;
    return result;
}

- (BOOL)isForPublishingProOnly
{
	return [self isForPublishing] && (nil != gRegistrationString) && gIsPro;
}

// Similar to above, but might be overridden by subclass to prevent sending to HTML validator
- (BOOL)shouldWriteServerSideScripts; { return [self isForPublishing]; }

- (BOOL)canWriteProMarkup;
{
	return [self isForPublishingProOnly]
			// Show the code injection in the webview as well, as long as this default is set.
			|| ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowCodeInjectionInPreview"] && [self isForEditing]);
}

#pragma mark CSS

@synthesize includeStyling = _includeStyling;

@synthesize mainCSSURL = _mainCSSURL;

- (void)addCSSString:(NSString *)css;
{
    if (![self isForPublishing])
    {
        [self writeStyleElementWithCSSString:css];
    }
}

- (void)addCSSWithURL:(NSURL *)cssURL;
{
    if (![self isForPublishing])
    {
        [self writeLinkToStylesheet:[self relativeURLStringOfURL:cssURL]
                              title:nil
                              media:nil];
    }
}

#pragma mark Header Tags

@synthesize currentHeaderLevel = _headerLevel;

- (NSString *)currentHeaderLevelTagName;
{
    NSString *result = [NSString stringWithFormat:@"h%u", [self currentHeaderLevel]];
    return result;
}

#pragma mark Elements/Comments

// Override to sort the keys so that they are always consistently written.
- (void)startElement:(NSString *)elementName attributes:(NSDictionary *)attributes;
{
	[self pushAttributes:attributes];
    [self startElement:elementName];
}

- (void)pushAttributes:(NSDictionary *)attributes;
{
    NSArray *sortedAttributes = [[attributes allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for (NSString *aName in sortedAttributes)
    {
        NSString *aValue = [attributes objectForKey:aName];
        [self pushAttribute:aName value:aValue];
    }
}

#pragma mark Preferred ID

- (NSString *)pushPreferredIdName:(NSString *)preferredID;
{
    NSString *result = preferredID;
    NSUInteger count = 1;
    while (![self isIDValid:result])
    {
        count++;
        result = [NSString stringWithFormat:@"%@-%u", preferredID, count];
    }
    
    [self pushAttribute:@"id" value:result];
    
    return result;
}

- (NSString *)startElement:(NSString *)tagName
           preferredIdName:(NSString *)preferredID
                 className:(NSString *)className
                attributes:(NSDictionary *)attributes;
{
    NSString *result = [self pushPreferredIdName:preferredID];
    [self pushAttributes:attributes];
    [self startElement:tagName idName:result className:className];
    
    return result;
}

#pragma mark Graphics

- (void)writePagelet:(SVGraphic *)graphic
{
    // Pagelet
    [self startNewline];        // needed to simulate a call to -startElement:
    [self stopWritingInline];
    
    SVTemplate *template = [[graphic class] template];
    
    SVHTMLTemplateParser *parser =
    [[SVHTMLTemplateParser alloc] initWithTemplate:[template templateString]
                                         component:graphic];
    
    [parser parseIntoHTMLContext:self];
    [parser release];
}

- (void)writeGraphic:(id <SVGraphic>)graphic;
{
    // Update number of graphics
    _numberOfGraphics++;
    
    
    if ([graphic isPagelet])
    {
        [self writePagelet:(SVGraphic *)graphic];
    }
    else if ([graphic shouldWriteHTMLInline])
    {
        [graphic writeBody:self];
    }
    else
    {
        // Register dependencies that come into play regardless of the route writing takes
        [self addDependencyOnObject:graphic keyPath:@"showsCaption"];
        
        // <div class="graphic-container center">
        [(SVGraphic *)graphic buildClassName:self];
        [self startElement:@"div"];
        
        
        // <div class="graphic"> or <img class="graphic">
        [self pushClassName:@"graphic"];
        if (![graphic captionGraphic] && [graphic isKindOfClass:[SVMediaGraphic class]]) // special case for media
        {
            [graphic writeBody:self];
            [self endElement];
            return;
        }
        
        NSString *className = [(SVGraphic *)graphic inlineGraphicClassName];
        if (className) [self pushClassName:className];
        
        if (![graphic isExplicitlySized])
        {
            NSNumber *width = [graphic containerWidth];
            if (width)
            {
                NSString *style = [NSString stringWithFormat:@"width:%upx", [width unsignedIntValue]];
                [self pushAttribute:@"style" value:style];
            }
        }
        
        [self writeGraphicBody:graphic];    // starts the element
        [self endElement];                  // and then closes it
        
        
        // Caption if requested
        id <SVGraphic> caption = [graphic captionGraphic];
        if (caption) // was registered as dependecy at start of if block
        {
            [self writeGraphic:caption];
        }
        
        
        // Finish up
        [self endElement];

    }
}

- (void)writeGraphicBody:(id <SVGraphic>)graphic;
{
    // Graphic body
    if (![graphic isPagelet])
    {
        [self startElement:@"div"]; // <div class="graphic">, will be closed by caller
        
        
        [self pushClassName:@"figure-content"];  // identifies for #84956
    }
    
    if ([graphic isKindOfClass:[SVMediaGraphic class]] || [graphic isKindOfClass:[SVTextBox class]])
    {
        // It's almost certainly media, generate DOM controller to match
        [graphic writeBody:self];
    }
    else
    {
        @try
        {
            [[self writeElement:@"div" contentsInvocationTarget:graphic]
             writeBody:self];
        }
        @catch (NSException *exception)
        {
            // Was probably caused by a plug-in. Log and soldier on. #88083
            NSLog(@"Writing graphic body raised exception, probably due to incorrect use of HTML Writer");
        }
    }
}

- (void)writeGraphics:(NSArray *)graphics;  // convenience
{
    if ([graphics count]) [self beginIteratingWithCount:[graphics count]];
    
    for (SVGraphic *anObject in graphics)
    {
        [self writeGraphic:anObject];
        
        [self nextIteration];
    }
}

- (NSUInteger)numberOfGraphicsOnPage; { return _numberOfGraphics; }

- (BOOL)isWritingCallout;
{
    return (_calloutAlignment != nil);
}

@synthesize calloutBuffer = _calloutBuffer;

- (void)megaBufferedWriterWillFlush:(KSMegaBufferedWriter *)buffer;
{
    OBASSERT(buffer == _calloutBuffer);
    [_calloutAlignment release]; _calloutAlignment = nil;
}

#pragma mark Metrics

- (void)startElement:(NSString *)elementName bindSizeToObject:(NSObject *)object;
{
    [self buildAttributesForElement:elementName bindSizeToObject:object DOMControllerClass:nil  sizeDelta:NSZeroSize];
    [self startElement:elementName];
}

- (void)buildAttributesForElement:(NSString *)elementName bindSizeToObject:(NSObject *)object DOMControllerClass:(Class)controllerClass  sizeDelta:(NSSize)sizeDelta;
{
	int w = [object integerForKey:@"width"];
	int h = [object integerForKey:@"height"];
    NSNumber *width  = (w+sizeDelta.width <= 0) ? nil : [NSNumber numberWithInt:w+sizeDelta.width];
	NSNumber *height = (h+sizeDelta.height <= 0) ? nil : [NSNumber numberWithInt:h+sizeDelta.height];
    
    // Only some elements support directly sizing. Others have to use CSS
    if ([elementName isEqualToString:@"img"] ||
        [elementName isEqualToString:@"video"] ||
        [elementName isEqualToString:@"object"] ||
        [elementName isEqualToString:@"embed"] ||
        [elementName isEqualToString:@"iframe"])
    {
        if (width) [self pushAttribute:@"width" value:[width description]];
        if (height) [self pushAttribute:@"height" value:[height description]];
    }
    else
    {
		NSMutableString *style = [NSMutableString string];
		if (width)  [style appendFormat:@"width:%@px;",  width];
		if (width && height) [style appendString:@" "];	// space between if both set
		if (height) [style appendFormat:@"height:%@px;", height];
        [self pushAttribute:@"style" value:style];
    }
}

- (void)startElement:(NSString *)elementName
    bindSizeToPlugIn:(SVPlugIn *)plugIn
          attributes:(NSDictionary *)attributes;
{
    // Push the extra attributes
    [self pushAttributes:attributes];
    
    [self buildAttributesForElement:elementName
                   bindSizeToObject:[plugIn performSelector:@selector(container)]
                 DOMControllerClass:nil
                          sizeDelta:NSMakeSize([[plugIn elementWidthPadding] unsignedIntegerValue],
                                               [[plugIn elementHeightPadding] unsignedIntegerValue])];
    
    [self startElement:elementName];
}

#pragma mark Text Blocks

- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)sidebar; { }
- (void)didEndWritingHTMLTextBlock; { }
- (void)willWriteSummaryOfPage:(SVSiteItem *)page; { }

#pragma mark URLs/Paths

- (NSString *)relativeURLStringOfURL:(NSURL *)URL;
{
    OBPRECONDITION(URL);
    
    NSString *result;
    
    switch ([self generationPurpose])
    {
        case kSVHTMLGenerationPurposeEditing:
            result = [URL webEditorPreviewPath];
            if (!result) result = [URL absoluteString];
            break;
            
        default:
            result = [URL ks_stringRelativeToURL:[self baseURL]];
            break;
    }
    
    return result;
}

- (NSString *)relativeURLStringOfSiteItem:(SVSiteItem *)page;
{
    OBPRECONDITION(page);
    
    NSString *result = nil;
    
    if ([self isForQuickLookPreview])
    {
        result = @"javascript:void(0)";
    }
    else if ([self isForEditing])
    {
        result = [page previewPath];
    }
    else
    {
        NSURL *URL = [page URL];
        if (URL) result = [self relativeURLStringOfURL:URL];
    }
    
    return result;
}

/*	Generates the path to the specified file with the current page's design.
 *	Takes into account the HTML Generation Purpose to handle Quick Look etc.
 */
- (NSURL *)URLOfDesignFile:(NSString *)whichFileName;
{
	NSURL *result = nil;
	
	// Return nil if the file doesn't actually exist
	
	KTDesign *design = [[[self page] master] design];
	NSString *localPath = [[[design bundle] bundlePath] stringByAppendingPathComponent:whichFileName];
	if ([[NSFileManager defaultManager] fileExistsAtPath:localPath])
	{
		if ([self isForEditing] && ![self baseURL])
        {
            result = [NSURL fileURLWithPath:localPath];
			
			// Append variation index as fragment, so that we can switch among variations and see a different URL
			if (NSNotFound != design.variationIndex)
			{
				result = [NSURL URLWithString:
                          [[result absoluteString]
                           stringByAppendingFormat:@"#var%d", design.variationIndex]];
			}
        }
        else
        {
            KTMaster *master = [[self page] master];
            result = [NSURL URLWithString:whichFileName relativeToURL:[master designDirectoryURL]];
        }
	}
	
	return result;
}

#pragma mark Media

- (NSURL *)addMedia:(id <SVMedia>)media;
{
    OBPRECONDITION(media);
    
    NSURL *result = [media mediaURL];
    return result;
}

- (NSURL *)addImageMedia:(id <SVMedia>)media
                   width:(NSNumber *)width
                  height:(NSNumber *)height
                    type:(NSString *)type
       preferredFilename:(NSString *)preferredFilename;
{
    return [self addMedia:media];
}

- (void)writeImageWithSourceMedia:(id <SVMedia>)media
                              alt:(NSString *)altText
                            width:(NSNumber *)width
                           height:(NSNumber *)height
                             type:(NSString *)type
                preferredFilename:(NSString *)filename;
{
    NSURL *URL = [self addImageMedia:media width:width height:height type:type preferredFilename:filename];
    NSString *src = (URL ? [self relativeURLStringOfURL:URL] : @"");
    
    [self writeImageWithSrc:src
                        alt:altText
                      width:width
                     height:height];
}

#pragma mark Resource Files

- (NSURL *)addResourceWithURL:(NSURL *)resourceURL;
{
    return resourceURL; // subclasses will correct for publishing
}

#pragma mark Design

- (NSURL *)addBannerWithURL:(NSURL *)sourceURL;
{
    return sourceURL;
}

- (NSURL *)addGraphicalTextData:(NSData *)imageData idName:(NSString *)idName;
{
    NSString *filename = [[idName legalizedWebPublishingFileName]
                          stringByAppendingPathExtension:@"png"];
    
    NSURL *result = [NSURL URLWithString:filename relativeToURL:[self mainCSSURL]];
    return result;
}

#pragma mark Iterations

- (NSUInteger)currentIteration; { return [[self currentIterator] iteration]; }

- (NSUInteger)currentIterationsCount; { return [[self currentIterator] count]; }

- (void)nextIteration;  // increments -currentIteration. Pops the iterators stack if this was the last one.
{
    if ([[self currentIterator] nextIteration] == NSNotFound)
    {
        [self popIterator];
    }
}

- (SVHTMLIterator *)currentIterator { return [_iteratorsStack lastObject]; }

- (void)beginIteratingWithCount:(NSUInteger)count;  // Pushes a new iterator on the stack
{
    OBPRECONDITION(count > 0);
    
    SVHTMLIterator *iterator = [[SVHTMLIterator alloc] initWithCount:count];
    [_iteratorsStack addObject:iterator];
    [iterator release];
}

- (void)popIterator;  // Pops the iterators stack early
{
    [_iteratorsStack removeLastObject];
}

- (NSString *)currentIterationCSSClassName;
{
    unsigned int index = [self currentIteration];
    int count = [self currentIterationsCount];
    
    NSMutableArray *classes = [NSMutableArray arrayWithObject:@"article"];
    if (index != NSNotFound)
    {
        NSString *indexClass = [NSString stringWithFormat:@"i%i", index + 1];
        [classes addObject:indexClass];
        
        NSString *eoClass = (0 == ((index + 1) % 2)) ? @"e" : @"o";
        [classes addObject:eoClass];
        
        if (index == (count - 1))
        {
            [classes addObject:@"last-item"];
        }
    }
    
    NSString *result = [classes componentsJoinedByString:@" "];
    return result;
}

#pragma mark Extra markup

- (void)addMarkupToEndOfBody:(NSString *)markup;
{
    if ([[self endBodyMarkup] rangeOfString:markup].location == NSNotFound)
    {
        [[self endBodyMarkup] appendString:markup];
    }
}

- (NSMutableString *)extraHeaderMarkup; // can append to, query, as you like while parsing
{
    return _headerMarkup;
}

- (void)writeExtraHeaders;  // writes any code plug-ins etc. have requested should inside the <head> element
{
    // Record where to make the insert
    _headerMarkupIndex = [[self outputStringWriter] length];
}

- (NSMutableString *)endBodyMarkup; // can append to, query, as you like while parsing
{
    return _endBodyMarkup;
}

- (void)writeEndBodyString; // writes any code plug-ins etc. have requested should go at the end of the page, before </body>
{
    // Finish buffering extra header
    [[self outputStringWriter] insertString:[self extraHeaderMarkup]
                                    atIndex:_headerMarkupIndex];
    
    // Write the end body markup
    [self writeString:[self endBodyMarkup]];
}

#pragma mark Content

// Two methods do the same thing. Need to ditch -addDependencyOnObject:keyPath: at some point
- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath { }
- (void)addDependencyForKeyPath:(NSString *)keyPath ofObject:(NSObject *)object;
{
    [self addDependencyOnObject:object keyPath:keyPath];
}

- (void)writeElement:(NSString *)elementName
     withTitleOfPage:(id <SVPage>)page
         asPlainText:(BOOL)plainText
          attributes:(NSDictionary *)attributes;
{
    [self startElement:elementName attributes:attributes];
    
    if (plainText)
    {
        [self writeText:[page title]];
    }
    else
    {
        [(SVSiteItem *)page writeTitle:self];
    }
    
    [self endElement];
}

#pragma mark Rich Text

- (void)writeCalloutWithGraphics:(NSArray *)pagelets;
{
    NSString *alignment = @"";  // placeholder until we support callouts on both sides
    
    
    BOOL isSameCallout = [self isWritingCallout];
    if (isSameCallout)
    {
        // Suitable div is already open, so cancel the buffer…
        [_calloutBuffer discardBuffer];
        
        // …open elements as usual, but throw away too
        [_calloutBuffer beginBuffering];
    }
    else
    {
        OBASSERT(!_calloutAlignment);
        _calloutAlignment = [alignment copy];
    }
    
    
    // Write the opening tags
    [self startElement:@"div"
                idName:[[self currentDOMController] elementIdName]
             className:[@"callout-container " stringByAppendingString:alignment]];
    
    [self startElement:@"div" className:@"callout"];
    
    [self startElement:@"div" className:@"callout-content"];
    
    
    // throw away buffered writing from before
    if (isSameCallout)
    {
        [self flush];
        [_calloutBuffer discardBuffer];
    }
    
    
    
    
    
    [self writeGraphics:pagelets];    
    
    
    
    
    // Buffer this call so consecutive matching callouts can be blended into one
    [_calloutBuffer beginBuffering];
    
    [self endElement]; // callout-content
    [self endElement]; // callout
    [self endElement]; // callout-container
    
    [_calloutBuffer flushOnNextWrite];
}

- (void)writeAttributedHTMLString:(NSAttributedString *)attributedHTML;
{
    //  Pretty similar to -[SVRichText richText]. Perhaps we can merge the two eventually?
    
    
    NSRange range = NSMakeRange(0, [attributedHTML length]);
    NSUInteger location = 0;
    
    BOOL firstItem = YES;
    
    while (location < range.length)
    {
        NSRange effectiveRange;
        SVTextAttachment *attachment = [attributedHTML attribute:@"SVAttachment"
                                                         atIndex:location
                                           longestEffectiveRange:&effectiveRange
                                                         inRange:range];
        
        if (attachment)
        {
            // Write the graphic
            [self pushClassName:(firstItem ? @"first" : @"not-first-item")];
            
            SVGraphic *graphic = [attachment graphic];
            
            
            
            // If the placement changes, want whole Text Area to update
            [self addDependencyForKeyPath:@"textAttachment.placement" ofObject:graphic];
            if ([graphic isPagelet])    // #83929
            {
                [self addDependencyForKeyPath:@"showsTitle" ofObject:graphic];
                [self addDependencyForKeyPath:@"showsIntroduction" ofObject:graphic];
            }
            [self addDependencyForKeyPath:@"showsCaption" ofObject:graphic];
            
            
            // Possible callout.
            BOOL callout = [graphic isCallout];
            if (callout)
            {
                // Look for other graphics that are part of the same callout
                NSMutableArray *pagelets = [NSMutableArray arrayWithObject:graphic];
                
                NSScanner *scanner = [[NSScanner alloc] initWithString:[attributedHTML string]];
                
                while (attachment)
                {
                    [scanner setScanLocation:(effectiveRange.location + effectiveRange.length)];
                    [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
                                        intoString:NULL];
                    
                    attachment = [attributedHTML attribute:@"SVAttachment"
                                                   atIndex:[scanner scanLocation]
                                     longestEffectiveRange:&effectiveRange
                                                   inRange:range];
                    
                    if (attachment)
                    {
                        if ([[attachment placement] intValue] == SVGraphicPlacementCallout)
                        {
                            [pagelets addObject:[attachment graphic]];
                        }
                        else
                        {
                            attachment = nil;
                        }
                    }
                    
                    if (!attachment) effectiveRange.length = 0; // reset search
                }
                [scanner release];
                
                [self writeCalloutWithGraphics:pagelets];
            }
            else
            {
                [self writeGraphic:graphic];
            }
            
            
            // Having written the first bit of content, it's time to start marking that
            firstItem = NO;
        }
        else
        {
            NSString *html = [[attributedHTML string] substringWithRange:effectiveRange];
            [self writeHTMLString:html];
        }
        
        // Advance the search
        location = effectiveRange.location + effectiveRange.length;
    }
}

- (void)writeString:(NSString *)string;
{
    [super writeString:string];
    _charactersWritten += [string length];
}

- (void)close;
{
    [super close];
    
    [_calloutBuffer release]; _calloutBuffer = nil;
    [_output release]; _output = nil;
}

#pragma mark Legacy

@synthesize page = _currentPage;

#pragma mark RSS

- (void)writeEnclosure:(id <SVEnclosure>)enclosure;
{
    // Figure out the URL when published. Ideally this is from some media, but if not the published URL
    NSURL *URL = nil;
    
    id <SVMedia> media = [enclosure media];
    if (media)
    {
        URL = [self addMedia:media];
    }
    else
    {
        URL = [enclosure URL];
    }
    
    
    // Write
    if (URL)
    {
        [self pushAttribute:@"url" value:[self relativeURLStringOfURL:URL]];
        
        if ([enclosure length])
        {
            [self pushAttribute:@"length"
                          value:[[NSNumber numberWithLongLong:[enclosure length]] description]];
        }
        
        if ([enclosure MIMEType]) [self pushAttribute:@"type" value:[enclosure MIMEType]];
        
        [self startElement:@"enclosure"];
        [self endElement];
    }
}

#pragma mark SVPlugInContext

- (id)objectForCurrentTemplateIteration;
{
    SVHTMLTemplateParser *parser = [SVHTMLTemplateParser currentTemplateParser];
    return [parser currentIterationObject];
}

- (NSString *)visibleSiteTitle;
{
    KTMaster *master = [[self page] master];
    if (![[[master siteTitle] hidden] boolValue])
    {
        return [[master siteTitle] text];
    }
    return nil;
}

- (void)startAnchorElementWithPage:(id <SVPage>)page;
{
    NSString *href = [self relativeURLStringOfSiteItem:(SVSiteItem *)page];
    if (!href) href = @"";  // happens for a site with no -siteURL set yet
    
    NSString *target = ([[(SVSiteItem *)page openInNewWindow] boolValue] ? @"_blank" : nil);
    
    [self startAnchorElementWithHref:href 
                               title:[page title]
                              target:target
                                 rel:nil];
    
}

@end


#pragma mark -



@implementation SVHTMLIterator

- (id)initWithCount:(NSUInteger)count;
{
    [self init];
    _count = count;
    return self;
}

@synthesize count = _count;

@synthesize iteration = _iteration;

- (NSUInteger)nextIteration;
{
    _iteration = [self iteration] + 1;
    if (_iteration == [self count]) _iteration = NSNotFound;
    return _iteration;
}

@end


#pragma mark -


@implementation KSHTMLWriter (SVHTMLContext)

- (void)writeEndTagWithComment:(NSString *)comment;
{
    [self endElement];
    
    [self writeString:@" "];
    
    [self openComment];
    [self writeString:@" "];
    [self writeText:comment];
    [self writeString:@" "];
    [self closeComment];
}

@end


