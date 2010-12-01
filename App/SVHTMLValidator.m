//
//  SVHTMLValidator.m
//  Sandvox
//
//  Created by Mike on 30/11/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVHTMLValidator.h"

#import "KTPage.h"


@implementation SVHTMLValidator

+ (ValidationState)validateFragment:(NSString *)fragment docType:(KTDocType)docType error:(NSError **)outError;
{
    ValidationState result;
    
    
    NSString *wrappedPage = [self HTMLStringWithFragment:fragment docType:docType];
    
    // Use NSXMLDocument -- not useful for errors, but it's quick.
	NSError *err = nil;
    NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithXMLString:wrappedPage
                             // Don't try to actually validate HTML; it's not XML
                                                             options:(KTHTML401DocType == docType) ? NSXMLDocumentTidyHTML|NSXMLNodePreserveAll : NSXMLNodePreserveAll
                                                               error:&err];
    
    if (xmlDoc)
    {
        // Don't really try to validate if it's HTML 5.  Don't have a DTD!
        // Don't really validate if it's HTML  ... We were having problems loading the DTD.
        if (KTHTML5DocType != docType && KTHTML401DocType != docType)
        {
            // Further check for validation if we can
            BOOL valid = [xmlDoc validateAndReturnError:&err];
            result = valid ? kValidationStateLocallyValid : kValidationStateValidationError;
            
            if (!valid && err)	// This might a warning or diagnosis for HTML 4.01
            {
                NSLog(@"validation Error: %@", [err localizedDescription]);
            }
        }
        else	// no ability to validate further, so assume it's locally valid.
        {
            result = kValidationStateLocallyValid;
        }
        [xmlDoc release];
    }
    else
    {
        result = kValidationStateUnparseable;
        
        if (err)	// This might a warning or diagnosis for HTML 4.01
        {
            NSLog(@"validation Error: %@", [err localizedDescription]);
        }
    }
    
    
    return result;
}

+ (NSString *)HTMLStringWithFragment:(NSString *)fragment docType:(KTDocType)docType;
{
    NSString *title			= @"<title>This is a piece of HTML, wrapped in some markup to help the validator</title>";
	NSString *commentStart	= @"<!-- BELOW IS THE HTML THAT YOU SUBMITTED TO THE VALIDATOR -->";
	
	NSString *localDTD  = [KTPage stringFromDocType:docType local:YES];
    
	// Special adjustments for local validation on HTML4.
	// Don't use the DTD if It's HTML 4 ... I was getting an error on local validation.
	// With no DTD, validation seems OK in the local validation.
	// And close the meta tag, too.
	if (KTHTML401DocType == docType)
	{
		localDTD = @"";
	}
	// NOTE: If we change the line count of the prelude, we will have to adjust the start= value in -[SVValidatorWindowController validateSource:...]
    
	NSString *metaCharset = nil;
	NSString *htmlStart = nil;
	switch(docType)
	{
		case KTHTML401DocType:
			htmlStart	= @"<html lang=\"en\">";
			metaCharset = @"<meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\">";
			break;
		case KTHTML5DocType:
			htmlStart	= @"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">";	// same as XHTML ?
			metaCharset = @"<meta charset=\"UTF-8\" />";
			break;
		default:
			htmlStart	= @"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">";
			metaCharset = @"<meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\" />";
			break;
	}
	
	NSMutableString *result = [NSMutableString stringWithFormat:
                                            @"%@\n%@\n<head>\n%@\n%@\n</head>\n<body>\n%@\n",
                                            localDTD,
                                            htmlStart,
                                            metaCharset,
                                            title,
                                            commentStart];
	
    
    
	[result appendString:fragment];
	[result appendString:@"\n<!-- ABOVE IS THE HTML THAT YOU SUBMITTED TO THE VALIDATOR -->\n</body>\n</html>\n"];
	return result;
}

@end


#pragma mark -


@implementation SVRemoteHTMLValidator

+ (NSString *)HTMLStringWithFragment:(NSString *)fragment docType:(KTDocType)docType;
{
    NSString *title			= @"<title>This is a piece of HTML, wrapped in some markup to help the validator</title>";
	NSString *commentStart	= @"<!-- BELOW IS THE HTML THAT YOU SUBMITTED TO THE VALIDATOR -->";
	
	NSString *remoteDTD = [KTPage stringFromDocType:docType local:NO];
    
	// NOTE: If we change the line count of the prelude, we will have to adjust the start= value in -[SVValidatorWindowController validateSource:...]
    
	NSString *metaCharset = nil;
	NSString *htmlStart = nil;
	switch(docType)
	{
		case KTHTML401DocType:
			htmlStart	= @"<html lang=\"en\">";
			metaCharset = @"<meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\">";
			break;
		case KTHTML5DocType:
			htmlStart	= @"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">";	// same as XHTML ?
			metaCharset = @"<meta charset=\"UTF-8\" />";
			break;
		default:
			htmlStart	= @"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">";
			metaCharset = @"<meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\" />";
			break;
	}
	
	NSMutableString *result = [NSMutableString stringWithFormat:
                                @"%@\n%@\n<head>\n%@\n%@\n</head>\n<body>\n%@\n",
                                remoteDTD,
                                htmlStart,
                                metaCharset,
                                title,
                                commentStart];
    
    
    [result appendString:fragment];
	[result appendString:@"\n<!-- ABOVE IS THE HTML THAT YOU SUBMITTED TO THE VALIDATOR -->\n</body>\n</html>\n"];
	return result;
}

@end
