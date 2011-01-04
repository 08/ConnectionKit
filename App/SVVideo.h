//
//  SVVideo.h
//  Sandvox
//
//  Created by Mike on 05/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVAudioVisualPlugIn.h"
#import "SVEnclosure.h"
#import <QTKit/QTKit.h>

@class SVMediaRecord, KSSimpleURLConnection;

typedef enum { kPosterFrameTypeUndefined = 0, kPosterFrameTypeNone, kPosterFrameTypeAutomatic, kPosterTypeChoose } PosterFrameType;


@interface SVVideo : SVAudioVisualPlugIn
{
	QTMovie *_dimensionCalculationMovie;
	KSSimpleURLConnection *_dimensionCalculationConnection;	// load some remote data if we can't load as a QTMovie
	PosterFrameType _posterFrameType;
}

+ (void)writeFallbackScriptOnce:(SVHTMLContext *)context;

@property (retain) QTMovie *dimensionCalculationMovie;
@property (retain) KSSimpleURLConnection *dimensionCalculationConnection;

@property  PosterFrameType posterFrameType;

#pragma mark Publishing



@end



