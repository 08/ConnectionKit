//
//  SVWebViewSelectionController.h
//  Sandvox
//
//  Created by Mike on 21/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVWebViewSelectionController : NSResponder
{
  @private
    DOMRange    *_selection;
}

// 0 for non-lists, 1+ for lists, NSMultipleValuesMarker for mixtures
@property(nonatomic, copy) NSNumber *listIndentLevel;
@property(nonatomic, readonly) NSNumber *shallowestListIndentLevel;
@property(nonatomic, readonly) NSNumber *deepestListIndentLevel;
- (NSUInteger)listIndentLevelForDOMNode:(DOMNode *)node;

@property(nonatomic, copy, readonly) NSNumber *listTypeTag;
- (NSNumber *)isOrderedList;
- (NSUInteger)listTypeTagForDOMNode:(DOMNode *)node;

@property(nonatomic, retain) DOMRange *selection;

- (void)insertIntoResponderChainAfterWebView:(WebView *)webView;

@end