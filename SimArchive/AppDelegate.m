//
//  AppDelegate.m
//  Simulator App Archiver
//
//  Created by René Fouquet on 29/01/15.
//  Copyright (c) 2015 René Fouquet. All rights reserved.
//

#import "AppDelegate.h"
#import "SAAManager.h"
#import "PFMoveApplication.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    PFMoveToApplicationsFolderIfNecessary();
    
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%@/Applications/iOS Simulator.app",[self.manager developerDirectory]] forKey:@"simulatorPath"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.manager getDevices];
    [self.manager setupManager];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    return [self processFile:filename];
}

- (BOOL)processFile:(NSString *)file {
    return [self.manager importAppToCurrentDevice:[NSURL fileURLWithPath:file] withDocuments:NO askForDocs:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
