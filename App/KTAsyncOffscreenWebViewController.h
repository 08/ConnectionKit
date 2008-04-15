//
//  KTAsyncOffscreenWebViewController.h
//  Marvel
//
//  Created by Dan Wood on 4/15/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/Webkit.h>


@interface KTAsyncOffscreenWebViewController : NSObject {

	WebView *myWebView;
	NSWindow *myWindow;
	
	id myDelegate;
}


- (id)delegate;
- (void)setDelegate:(id)aDelegate;



- (void)loadHTMLFragment:(NSString *)anHTMLFragment;
- (void) stopLoading;

@end
