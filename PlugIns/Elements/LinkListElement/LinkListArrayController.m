//
//  LinkListArrayController.m
//  Sandvox SDK
//
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
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
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "LinkListArrayController.h"
#import "LinkListPlugIn.h"

#define LocalizedStringInThisBundle(key, comment) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]


@implementation LinkListArrayController

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [tableView setDataSource:self];
    [tableView setDelegate:self];
}

/*!	Create a new "template" object.  Try to pick up default from frontmost Safari doc.
*/
- (id)newObject	// must return object with a retain count of one
{
    id<SVWebLocation> location = [[NSWorkspace sharedWorkspace] fetchBrowserWebLocation];
    NSMutableDictionary *result = [[LinkListPlugIn displayableLinkFromLocation:location] retain];
    
    if ( !result )
    {
        NSString *theTitle = LocalizedStringInThisBundle(@"Name",@"Initial title of an item in a list of web links");

        NSURL *theURL = [location URL];
        if ( theURL )
        {
            theTitle = [location title];
        }
        else
        {
            theURL = [NSURL URLWithString:@"http://www.example.com/"];
        }

        
        result = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                  theTitle, @"title",
                  theURL, @"url",
                  nil];
    }
    
	return result;
}

/*!	Also accept drag URL drag.  
*/
- (NSArray *)urlTypes { return SVWebLocationGetReadablePasteboardTypes(nil); }

- (NSArray *)dragTypesToRegister
{
	return [[super dragTypesToRegister] arrayByAddingObjectsFromArray:[self urlTypes]];
}

- (NSDragOperation)tableView:(NSTableView *)tv 
                validateDrop:(id < NSDraggingInfo >)info 
                 proposedRow:(NSInteger)row 
       proposedDropOperation:(NSTableViewDropOperation)operation
{
    BOOL result = NSDragOperationNone;
    
    // Get the URLs and titles from the pasteboard
	NSPasteboard *pasteboard = [info draggingPasteboard];
	NSArray *webLocations = [pasteboard readWebLocations];
	
	// Run through the URLs looking for something we can use
    for ( id<SVWebLocation> location in webLocations )
	{
        NSMutableDictionary *link = [LinkListPlugIn displayableLinkFromLocation:location];
        if ( link )
        {
            result = NSDragOperationPrivate;
            break;
        }
	}
    
    return result;
}

- (BOOL)tableView:(NSTableView*)tv
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(int)row
	dropOperation:(NSTableViewDropOperation)op
{
    BOOL didInsert = NO;
	
	if (row < 0) {	// Handle inserting at the very top of the list
		row = 0;
	}
	
	// Let our superclass try before we get a crack at it
	if ([super tableView:tv acceptDrop:info row:row dropOperation:op]) {
		return YES;	// super handled it
	}
	
	// Get the URLs and titles from the pasteboard
	NSPasteboard *pasteboard = [info draggingPasteboard];
	NSArray *webLocations = [pasteboard readWebLocations];
	
	// Run through the URLs, adding them to the table
    for ( id<SVWebLocation> location in webLocations )
	{
        NSMutableDictionary *link = [LinkListPlugIn displayableLinkFromLocation:location];
        if ( link )
        {
            [self insertObject:link atArrangedObjectIndex:row];
            [self setSelectionIndex:row];
            row++;
            didInsert = YES;
        }
	}
	
	return didInsert;		// only return YES if we actually inserted something
}

@end
