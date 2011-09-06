//
//  ContactElementInspectorController.m
//  ContactElement
//
//  Copyright 2007-2011 Karelia Software. All rights reserved.
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
//  Community Note: This code is distributed under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "ContactInspector.h"

#import <Sandvox.h>
#import "KSEmailAddressComboBox.h"
#import "KSIsEqualValueTransformer.h"
#import "NSData+Karelia.h"


@implementation ContactInspector

+ (void)initialize
{
	// Register value transformers
	KSIsEqualValueTransformer *transformer = nil;
	
// TODO: when we can mess with the nib, just take out this transformer binding.
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:             @"email___"];	// HACK -- "DISABLE" THIS SO EMAIL PLACEHOLDER IS ALWAYS ENABLED.  COMPARISON WILL NEVER SUCCEED.
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotEmail"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:@"visitorName"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotName"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:@"subject"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotSubject"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:@"message"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotMessage"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:@"send"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotSend"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
}

- (void)awakeFromNib
{
    // set up address combobox 
	[KSEmailAddressComboBox setWillAddAnonymousEntry:NO];
	[KSEmailAddressComboBox setWillIncludeNames:NO];
    
    [oAddressComboBox setStringValue:@""];
    [oAddressComboBox selectItemWithObjectValue:@""];
    [[oAddressComboBox cell] setPlaceholderString:@""];

    
	// Correct the spacing of the custom labels form
	NSSize spacing = [oCustomLabelsForm intercellSpacing];
	spacing.height = 4;
	[oCustomLabelsForm setIntercellSpacing:spacing];
    
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(focusMessageField:)
												 name:@"AddedMessageField"
											   object:oArrayController];
}

// For the subjects text field, allow return to insert a newline.

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    BOOL retval = NO;
    if ( (control == oSubjects)
		&& (commandSelector == @selector(insertNewline:) ) )
	{
        retval = YES;
        [textView insertNewlineIgnoringFieldEditor:nil];
    }
    return retval;
}

- (void)focusMessageField:(NSNotification *)aNotification	// AddedMessageField notification
{
	[[oLabel window] makeFirstResponder:oLabel];
}

- (IBAction) unsecureHelp:(id)sender;
{
	[NSHelpManager gotoHelpAnchor:@"Contact Form"];	// HELPSTRING
}

@end
