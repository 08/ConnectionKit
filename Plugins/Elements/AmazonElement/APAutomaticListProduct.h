//
//  APAutomaticListProduct.h
//  Amazon List
//
//  Created by Mike on 09/02/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//
//	A simple subclass of APAmazonProduct that adds the knowledge of the quantity
//	desired and received of a product. Created by APAmazonList objects.


#import <Cocoa/Cocoa.h>
#import "APAmazonProduct.h"


@interface APAutomaticListProduct : APAmazonProduct
{
	unsigned	myQuantityDesired;
	unsigned	myQuantityReceived;
}

- (unsigned)quantityDesired;
- (void)setQuantityDesired:(unsigned)quantity;

- (unsigned)quantityReceived;
- (void)setQuantityReceived:(unsigned)quantity;

- (BOOL)desiredQuantityHasBeenReceived;

@end
