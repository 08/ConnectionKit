//
//  AmazonIDFormatter.m
//  Amazon List
//
//  Created by Mike on 05/03/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "AmazonIDFormatter.h"

#import "SandvoxPlugin.h"

#import "NSURL+AmazonPagelet.h"


@implementation AmazonIDFormatter

- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error
{
	BOOL result = YES;
	
	// Let our superclass at it
	result = [super getObjectValue: anObject forString: string errorDescription: error];
	
	if (result)
	{
		// If a URL was entered, leave it intact
		NSURL *URL = [SVURLFormatter URLFromString:*anObject];
		if (!([[URL scheme] length] && [[URL resourceSpecifier] length]))
		{
			// Convert to uppercase and remove unwanted characters
			NSCharacterSet *characters = [AmazonIDFormatter legalAmazonIDCharacters];
			*anObject = [[string amazonList_stringByRemovingCharactersNotInSet:characters] uppercaseString];
			
			// The user may have mistakenly entered ISBN, ISBN10 or ISBN13 at the start
			// If so, and the remainder is a valid ISBN number, remove it
			NSString *shortenedString = nil;
			
			shortenedString = [*anObject substringFromPrefix:@"ISBN10"];
			if (shortenedString && [shortenedString isValidISBN10Number]) {
				*anObject = shortenedString;
			}
			
			if (!shortenedString)
			{
				shortenedString = [*anObject substringFromPrefix:@"ISBN13"];
				if (shortenedString && [shortenedString isValidISBN13Number]) {
					*anObject = shortenedString;
				}
			}
			
			if (!shortenedString)
			{
				shortenedString = [*anObject substringFromPrefix:@"ISBN"];
				if (shortenedString && [shortenedString isValidISBNNumber]) {
					*anObject = shortenedString;
				}
			}
		}
	}
	
	return result;
}

+ (NSCharacterSet *)legalAmazonIDCharacters;
{
    static NSCharacterSet *result;
	if (nil == result)
	{
		NSMutableCharacterSet *set = [[NSMutableCharacterSet alloc] init];
		
		[set addCharactersInRange:NSMakeRange('A', 26)];
		[set addCharactersInRange:NSMakeRange('a', 26)];
		[set addCharactersInRange:NSMakeRange('0', 10)];
        
		result = [set copy];		// retain a non-mutable copy
        [set release];
	}
	return result;
}

@end


@implementation NSString (AmazonList)

/*	A bunch of fairly simple checks for ISBN compliance
 *	In the future probably ought to expand this to check for valid characters only
 */
- (BOOL)isValidISBN10Number { return ([self length] == 10); }

- (BOOL)isValidISBN13Number { return ([self length] == 13); }

- (BOOL)isValidISBNNumber { return ([self isValidISBN10Number] || [self isValidISBN13Number]); }

/*	If the string has the specified prefix, the prefix is removed. If not, returns nil
 */
- (NSString *)substringFromPrefix:(NSString *)prefix
{
	NSString *result = nil;
	
	if ([self hasPrefix:prefix]) {
		result = [self substringFromIndex:[prefix length]];
	}
	
	return result;
}

@end
