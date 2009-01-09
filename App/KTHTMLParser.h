//
//  KTHTMLParser.h
//  Sandvox
//
//  Copyright (c) 2005-2008, Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//


#import "KTTemplateParser.h"


// publishing mode
typedef enum {
	kGeneratingPreview = 0,
	kGeneratingLocal,
	kGeneratingRemote,
	kGeneratingRemoteExport,
	kGeneratingQuickLookPreview = 10,
} KTHTMLGenerationPurpose;


@class KTDocument, KTHTMLParserMasterCache, KTMediaFileUpload, KTHTMLTextBlock;
@class KTAbstractPage;
@class KTMediaContainer, KTMediaFile;


@interface KTHTMLParser : KTTemplateParser
{
	KTAbstractPage			*myCurrentPage;
	KTHTMLGenerationPurpose	myHTMLGenerationPurpose;
	BOOL					myIncludeStyling;
	NSNumber				*myLiveDataFeeds;
}

- (id)initWithPage:(KTAbstractPage *)page;	// Convenience method that parses the whole page

// Accessors
- (KTAbstractPage *)currentPage;
- (void)setCurrentPage:(KTAbstractPage *)page;

- (KTHTMLGenerationPurpose)HTMLGenerationPurpose;
- (void)setHTMLGenerationPurpose:(KTHTMLGenerationPurpose)purpose;
- (BOOL)includeStyling;
- (void)setIncludeStyling:(BOOL)includeStyling;

- (BOOL)liveDataFeeds;
- (void)setLiveDataFeeds:(BOOL)flag;

// Functions
- (NSString *)pathToObject:(id)anObject;

// Prebuilt templates
+ (NSString *)calloutContainerTemplateHTML;
- (NSString *)calloutContainerTemplateHTML;

@end


@interface KTHTMLParser (Media)

- (NSString *)info:(NSString *)infoString forMedia:(KTMediaContainer *)media scalingProperties:(NSDictionary *)scalingSettings;

- (NSString *)pathToMedia:(KTMediaFile *)media scalingProperties:(NSDictionary *)scalingProps;
- (NSString *)widthStringForMediaFile:(KTMediaFile *)mediaFile scalingProperties:(NSDictionary *)scalingProps;
- (NSString *)heightStringForMediaFile:(KTMediaFile *)mediaFile scalingProperties:(NSDictionary *)scalingProps;

@end


@interface KTHTMLParser (Text)
- (KTHTMLTextBlock *)textblockForKeyPath:(NSString *)keypath ofObject:(id)object
									  flags:(NSArray *)flags
								    HTMLTag:(NSString *)tag
						  graphicalTextCode:(NSString *)GTCode
								  hyperlink:(KTAbstractPage *)hyperlink;
@end


@interface NSObject (KTHTMLParserDelegate)
- (void)HTMLParser:(KTHTMLParser *)parser didEncounterResourceFile:(NSURL *)resourcePath;
- (void)HTMLParser:(KTHTMLParser *)parser didParseMediaFile:(KTMediaFile *)mediaFile upload:(KTMediaFileUpload *)upload;	
- (void)HTMLParser:(KTHTMLParser *)parser didParseTextBlock:(KTHTMLTextBlock *)textBlock;
@end
