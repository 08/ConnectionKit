//
//  NSImage+KTApplication.h
//  Marvel
//
//  Created by Dan Wood on 5/10/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "CIImage+Karelia.h"


@class KTImageScalingSettings, KTMedia;


@interface NSImage ( KTApplication )

- (NSImage *)imageWithCompositedAddBadge;

- (NSBitmapImageRep *)bitmapByScalingWithBehavior:(KTImageScalingSettings *)settings;

+ (float)preferredJPEGQuality;

- (NSData *)faviconRepresentation;

/*! returns UTI but also checks alpha */
- (NSString *)preferredFormatUTI;

- (NSData *)preferredRepresentation;
- (NSData *)preferredRepresentationWithOriginalMedia:(KTMedia *)parentMedia;

// assumes kFitWithinRect, NSImageAlignCenter
- (NSImage *)imageWithMaxPixels:(int)aPixels;

// assumes kFitWithinRect, NSImageAlignCenter
- (NSImage *)imageWithMaxWidth:(int)aWidth height:(int)aHeight;

// assumes NSImageAlignCenter
- (NSImage *)imageWithMaxWidth:(int)aWidth height:(int)aHeight behavior:(CIScalingBehavior)aBehavior;

- (NSImage *)imageWithMaxWidth:(int)aWidth 
						height:(int)aHeight 
					  behavior:(CIScalingBehavior)aBehavior 
					 alignment:(NSImageAlignment)anAlignment;

- (NSData *)representationForMIMEType:(NSString *)aMimeType;
- (NSData *)representationForUTI:(NSString *)aUTI;

- (NSData *)PNGRepresentation;
- (NSData *)PNGRepresentationWithOriginalMedia:(KTMedia *)parentMedia;
- (NSData *)JPEGRepresentationWithQuality:(float)aQuality;
- (NSData *)JPEGRepresentationWithQuality:(float)aQuality originalMedia:(KTMedia *)parentMedia;


@end
