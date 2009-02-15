//
//  KTPluginInstaller.m
//  Marvel
//
//  Created by Dan Wood on 3/9/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//
//
// THIS IS A PSEUDO-DOCUMENT TO HANDLE OPENING OF PLUGINS.... IT COPIES THEM TO THE APP SUPPORT DIR.

#import "KTPluginInstaller.h"

#import "Debug.h"
#import "NSApplication+Karelia.h"
#import "NSHelpManager+Karelia.h"
#import "NSError+Karelia.h"
#import "KSAppDelegate.h"
#import "KSPlugin.h"
#import "KSProgressPanel.h"

#import "NSObject+Karelia.h"


static KTPluginInstaller *sSharedPluginInstaller = nil;

@implementation KTPluginInstaller

+ (KTPluginInstaller *)sharedPluginInstaller		// the one instance of this which actually does the work
{
	if (!sSharedPluginInstaller)
	{
		sSharedPluginInstaller = [[KTPluginInstaller alloc] init];
	}
	return sSharedPluginInstaller;
}

- (id)init
{
	if ((self = [super init]) != nil) {
		myURLs = [[NSMutableArray alloc] init];		// list of URLs to install
	}
	return self;
}

- (void)dealloc
{
	[myURLs release];
    [myProgressPanel release];
    
	[super dealloc];
}

- (void)queueURL:(NSURL *)aURL		// cancel queued requests and queue up another one.
{
	if (0 == [myURLs count] && !myProgressPanel)
	{
        myProgressPanel = [[KSProgressPanel alloc] init];
        [myProgressPanel setMessageText:@"Installing Plugins..."];
        [myProgressPanel setInformativeText:nil];
        [myProgressPanel setIcon:[[NSWorkspace sharedWorkspace] iconForFile:[aURL path]]];
        
        [myProgressPanel makeKeyAndOrderFront:self];
	}
	
	[myURLs addObject:aURL];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(finishInstalling) object:nil];
	[self performSelector:@selector(finishInstalling) withObject:nil afterDelay:1.5];
}

- (void) finishInstalling	// finally called when they are all done opening
{
	NSString *destFolder = [[[NSApplication applicationSupportPath] stringByResolvingSymlinksInPath] stringByStandardizingPath];
		// we are going to copy directly into the app's app support folder, but if the file already
		// exists there, or in a subfolder of this app support folder, then we won't.
	
	NSEnumerator *enumerator = [myURLs objectEnumerator];
	NSURL *url;
	NSMutableArray *errorURLs   = [NSMutableArray array];		// queue up BAD copies
	NSMutableArray *successURLs = [NSMutableArray array];		// queue up GOOD copies

	while ((url = [enumerator nextObject]) != nil)
	{
		NSString *urlPath = [url path];
		NSString *extension = [urlPath pathExtension];
		Class pluginClass = [KSPlugin registeredPluginClassForFileExtension:extension];
		NSString *pluginSubfolder = [pluginClass pluginSubfolder];
		NSString *altDestFolder = [[[[NSApplication applicationSupportPath] stringByAppendingPathComponent:pluginSubfolder]
								  stringByResolvingSymlinksInPath] stringByStandardizingPath];
		NSString *sourcePath = [[[url path] stringByResolvingSymlinksInPath] stringByStandardizingPath];
		NSString *destPath = [destFolder stringByAppendingPathComponent:[sourcePath lastPathComponent]];
		NSString *altDestPath = [altDestFolder stringByAppendingPathComponent:[sourcePath lastPathComponent]];

		if ([sourcePath isEqualToString:destPath] || [sourcePath isEqualToString:altDestPath])
		{
			NSLog(@"Not copying; already %@ is already installed.", sourcePath);
			[errorURLs addObject:url];
		}
		else if ([sourcePath hasPrefix:destFolder])
		{
			NSLog(@"Not copying; %@ is already living in %@", sourcePath, destFolder);
		}
		else
		{
			NSFileManager *fm = [NSFileManager defaultManager];
			if ([fm fileExistsAtPath:destPath] && ![sourcePath isEqualToString:destPath])
			{
				(void) [fm removeFileAtPath:destPath handler:nil];
			}
			BOOL copied = [fm copyPath:sourcePath toPath:destPath handler:nil];
			if (copied)
			{
				[successURLs addObject:url];
			}
			else
			{
				NSLog(@"Unable to copy %@ to %@", sourcePath, destPath);
				[errorURLs addObject:url];
			}
		}
	}
	[myURLs removeAllObjects];
	
    [myProgressPanel performClose:self];
    [myProgressPanel release];  myProgressPanel = nil;
	
	// First, announce what was installed.
	if ([successURLs count])
	{
		NSString *message = nil;
		if ([successURLs count] > 1)
		{
			message = NSLocalizedString(@"Plugins Installed",@"Alert Message Title, multiple plugins were installed");
		}
		else
		{
			message = NSLocalizedString(@"Plugin Installed",@"Alert Message Title, only one plugin was installed");

		}
		NSMutableString *pluginList = [NSMutableString string];
		NSEnumerator *successEnum = [successURLs objectEnumerator];
		NSURL *url;

		while ((url = [successEnum nextObject]) != nil)
		{
			[pluginList appendFormat:@"\t%@\n", [[url path] lastPathComponent]];
		}
		NSString *information = [NSString stringWithFormat:NSLocalizedString(@"The following plugins were installed:\n\n%@\nPlease re-launch Sandvox to make use of newly installed plugins.",@"result of installation"), pluginList];
			
		NSAlert *alert = [NSAlert alertWithMessageText:message defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:information];
		
		[alert setShowsHelp:YES];
		[alert setDelegate:self];
		
		[alert setIcon:[[NSWorkspace sharedWorkspace] iconForFile:[[successURLs lastObject] path]]];
		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert runModal];
	}
	
	// Then, announce what what failed.
	if ([errorURLs count])
	{
		NSString *message = nil;
		if ([errorURLs count] > 1)
		{
			message = NSLocalizedString(@"Error Installing Plugins",@"Alert Message Title, error installing multiple plugins");
		}
		else
		{
			message = NSLocalizedString(@"Error Installing Plugin",@"Alert Message Title, error installing one plugin");
			
		}
		NSMutableString *pluginList = [NSMutableString string];
		NSEnumerator *errorEnum = [errorURLs objectEnumerator];
		NSURL *url;
		
		while ((url = [errorEnum nextObject]) != nil)
		{
			[pluginList appendFormat:@"\t%@\n", [[url path] lastPathComponent]];
		}
		NSString *information = [NSString stringWithFormat:NSLocalizedString(@"The following plugins could not be installed:\n\n%@",@"result of installation"), pluginList];
		
		NSAlert *alert = [NSAlert alertWithMessageText:message defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:information];
		
		[alert setShowsHelp:YES];
		[alert setDelegate:self];
		
		[alert setIcon:[[NSWorkspace sharedWorkspace] iconForFile:[[errorURLs lastObject] path]]];
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
	}
}

- (NSString *)windowNibName
{
    return nil;
}

- (BOOL)alertShowHelp:(NSAlert *)alert
{
	NSString *helpString = @"Installing_Sandvox_Plugins_and_Designs";		// HELPSTRING
	return [NSHelpManager gotoHelpAnchor:helpString];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	[[KTPluginInstaller sharedPluginInstaller] queueURL:absoluteURL];
	return YES;		// assume OK
}

/// adding this here just in case this "document" ends up in the shared document list
- (NSManagedObjectContext *)managedObjectContext
{
	return nil;
}


@end
