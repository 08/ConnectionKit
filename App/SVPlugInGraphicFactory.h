//
//  SVPlugInGraphicFactory.h
//  Sandvox
//
//  Created by Mike on 15/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphicFactory.h"


@interface SVPlugInGraphicFactory : SVGraphicFactory
{
  @private
    Class       _class;
    NSBundle    *_bundle;
    NSImage     *_icon;
}

- (id)initWithBundle:(NSBundle *)bundle;    // assume -principalClass is the plug-in

@property(nonatomic, retain, readonly) NSBundle *plugInBundle;

@end
