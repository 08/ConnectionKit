//
//  KTHTMLEditorController.h




//  originally
//  Created by Uli Kusterer on Tue May 27 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//


#import <Cocoa/Cocoa.h>

#import "SVOffscreenWebViewController.h"
#import "SVHTMLValidator.h"
#import "KSNoCascadeWindow.h"


@class KTAbstractElement, SVRawHTMLGraphic;

// Syntax-colored text file viewer:
@interface KTHTMLEditorController : NSWindowController <SVOffscreenWebViewControllerDelegate>
{
	IBOutlet NSTextView*			textView;				// The text view used for editing code.
	
	// Not really hooked up!
	IBOutlet NSProgressIndicator*	progress;				// Progress indicator while coloring syntax.
	IBOutlet NSTextField*			status;					// Status display for things like syntax coloring or background syntax checks.
	IBOutlet NSPopUpButton*			docTypePopUp;
	IBOutlet NSMenuItem*			previewMenuItem;
	
@private	
    NSUndoManager                   *_undoManager;
	BOOL							_autoSyntaxColoring;		// Automatically refresh syntax coloring when text is changed?
	BOOL							_maintainIndentation;	// Keep new lines indented at same depth as their predecessor?
	NSTimer							*_recolorTimer;			// Timer used to do the actual recoloring a little while after the last keypress.
	BOOL							_syntaxColoringBusy;		// Set while recolorRange is busy, so we don't recursively call recolorRange.
	NSRange							_affectedCharRange;
	NSString						*_replacementString;
	BOOL							_hasRemoteLoads;

	// ivar of what to send the information back to
	SVRawHTMLGraphic				*_HTMLSourceObject;
	SEL								_completionSelector;
	
	NSString						*_sourceCodeTemp;				// Temp. storage for data from file until NIB has been read.
	NSString						*_title;
	
	SVOffscreenWebViewController *_asyncOffscreenWebViewController;

		
	// Bound Properties
	KTDocType						_docType;
	NSString						*_cachedLocalPrelude;
	NSString						*_cachedRemotePrelude;
	ValidationState					_validationState;
	BOOL							_preventPreview;
	NSData							*_hashOfLastValidation;
}

- (IBAction) windowHelp:(id)sender;
- (IBAction) applyChanges:(id)sender;
- (IBAction) validate:(id)sender;
- (IBAction) docTypePopUpChanged:(id)sender;

- (BOOL) canValidate;	// for bindings

@property (nonatomic, retain) SVRawHTMLGraphic *HTMLSourceObject;
@property (assign) SEL completionSelector;  // TODO: appears to be unused

@property (nonatomic) BOOL hasRemoteLoads;
@property (nonatomic, retain) NSUndoManager *undoManager;
@property (nonatomic) BOOL autoSyntaxColoring;
@property (nonatomic) BOOL maintainIndentation;
@property (nonatomic, retain) NSTimer *recolorTimer;
@property (nonatomic) BOOL syntaxColoringBusy;
@property (nonatomic) NSRange affectedCharRange;
@property (nonatomic, copy) NSString *replacementString;
@property (nonatomic, copy) NSString *sourceCodeTemp;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) KTDocType docType;
@property (nonatomic, copy) NSString *cachedLocalPrelude;
@property (nonatomic, copy) NSString *cachedRemotePrelude;
@property (nonatomic) ValidationState validationState;
@property (nonatomic) BOOL preventPreview;
@property (nonatomic, copy) NSData *hashOfLastValidation;
@property (nonatomic, retain) SVOffscreenWebViewController *asyncOffscreenWebViewController;

@end



// Support for external editor interface:
//	(Doesn't really work yet ... *sigh*)

#pragma options align=mac68k

struct SelectionRange
{
	short   unused1;	// 0 (not used)
	short   lineNum;	// line to select (< 0 to specify range)
	long	startRange; // start of selection range (if line < 0)
	long	endRange;   // end of selection range (if line < 0)
	long	unused2;	// 0 (not used)
	long	theDate;	// modification date/time
};

#pragma options align=reset


@interface KTHTMLEditorWindow : KSNoCascadeWindow

@end


