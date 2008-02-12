//
//  iMBAmazonBrowseNodesParser.h
//  iMediaAmazon
//
//  Created by Dan Wood on 4/5/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <iMediaBrowser/iMedia.h>


@interface iMBAmazonBrowseNodesParser : NSObject  <iMBParser>
{
	iMBLibraryNode		*myCachedLibrary;
	iMBLibraryNode		*myPlaceholderChild;

}

@end
