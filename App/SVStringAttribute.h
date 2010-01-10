//
//  SVStringAttribute.h
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@class SVBodyParagraph;

@interface SVStringAttribute :  NSManagedObject  
{
}

//  An attribute may write pretty much whatever it likes.
//  For example, an inline graphic should just ask its graphic to write. Other attributes could write some start tags, then the usual string content, then end tags.
//  Default implementation writes nothing but the usual string content, so you can call super if that behaviour is desired.
- (void)writeHTML;

- (NSRange)range;
@property(nonatomic, retain) NSNumber *length;
@property(nonatomic, retain) NSNumber *location;

@property (nonatomic, retain) SVBodyParagraph * paragraph;

@end



