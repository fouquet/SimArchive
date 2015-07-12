//
//  SAAManager.m
//  Simulator App Archiver
//
//  Created by René Fouquet on 29/01/15.
//  Copyright (c) 2015 René Fouquet. All rights reserved.
//

#import "SAAManager.h"
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#include <assert.h>
#import "DSWVerticallyCenteredTextField.h"
#import "DCOAboutWindowController.h"

static const NSString *simulatorDir = @"/Library/Developer/CoreSimulator";

@implementation SAAManager

- (id)init {
    self = [super init];
    if (self) {
        _listOfSimulatorDevices = [NSMutableArray new];
        _appsArray = [NSMutableArray new];
    }
    return self;
}

#pragma mark - Methods

NSString *RealHomeDirectory() {
    struct passwd *pw = getpwuid(getuid());
    assert(pw);
    return [NSString stringWithUTF8String:pw->pw_dir];
}

- (NSString *)pathOfSimulator {
    return [NSString stringWithFormat:@"%@%@/Devices",RealHomeDirectory(),simulatorDir];
}

- (void)getDevices {
    if (!([[self XcodeVersion] compare:@"6.0" options:NSNumericSearch] != NSOrderedAscending)) {
        NSAlert *noSimulatorAlert = [NSAlert new];
        [noSimulatorAlert addButtonWithTitle:@"Quit"];
        [noSimulatorAlert setMessageText:@"Xcode too old"];
        [noSimulatorAlert setInformativeText:[NSString stringWithFormat:@"SimArchive requires at least version 6.0 of Xcode. You have version %@ installed",[self XcodeVersion]]];
        [noSimulatorAlert setAlertStyle:NSCriticalAlertStyle];
        [noSimulatorAlert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            [[NSApplication sharedApplication] terminate:self];
        }];
        return;
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self pathOfSimulator]]) {
        NSAlert *noSimulatorAlert = [NSAlert new];
        [noSimulatorAlert addButtonWithTitle:@"Quit"];
        [noSimulatorAlert setMessageText:@"iOS Simulator not found"];
        [noSimulatorAlert setInformativeText:@"There appears to be no iOS Simulator installed on this machine. Please install Xcode (Version 6.0 and larger) and start it at least once."];
        [noSimulatorAlert setAlertStyle:NSCriticalAlertStyle];
        [noSimulatorAlert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            [[NSApplication sharedApplication] terminate:self];
        }];
        return;
    }
    
    [self getValidPlatforms];
    
    NSArray *devices = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self pathOfSimulator] error:nil];
    
    self.listOfVersions = [NSMutableArray new];
    
    NSInteger index = 0;
    
    for (NSString *device in devices) {
        BOOL isDir;
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@",[self pathOfSimulator],device] isDirectory:&isDir] && isDir) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@/device.plist",[self pathOfSimulator],device]]) {
                NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/%@/device.plist",[self pathOfSimulator],device]];
                
                NSString *version = @"?";
                if ([self string:dict[@"runtime"] matchesRegularExpression:@"(com.apple.CoreSimulator.SimRuntime.)((?:[a-z][a-z]+))(-)(\\d+)(-)(\\d+)"]) {
                    NSString *platform = [self matchingSubstringOfString:dict[@"runtime"] forRegularExpression:@"((?:[a-z][a-z]+))(-)(\\d+)(-)(\\d+)"];
                    version = [platform stringByReplacingOccurrencesOfString:@"iOS-" withString:@"iOS "];
                    version = [version stringByReplacingOccurrencesOfString:@"-" withString:@"."];
                }
                
                BOOL isiOS7 = NO;
                if ([self string:dict[@"runtime"] matchesRegularExpression:@"(com)(\\.)(apple)(\\.)(CoreSimulator)(\\.)(SimRuntime)(\\.)(iOS)(-)(7)(-)(\\d+)"]) {
                    isiOS7 = YES;
                }
                BOOL validPlatform = NO;
                if ([self.listOfValidPlatforms containsObject:dict[@"runtime"]]) validPlatform = YES;
                
                if (!isiOS7 && validPlatform) [self.listOfSimulatorDevices addObject:@{@"UDID":dict[@"UDID"],@"name":dict[@"name"],@"runtime":dict[@"runtime"],@"version":version,@"index":@(index),@"iOS7":@(isiOS7)}];
                
                if (![self.listOfVersions containsObject:version] && !isiOS7 && validPlatform) [self.listOfVersions addObject:version];
            }
            index++;
        }
    }
    
    if (self.listOfVersions.count == 0) {
        NSAlert *alert = [NSAlert new];
        [alert addButtonWithTitle:@"Quit"];
        [alert setMessageText:@"No valid platforms found"];
        [alert setInformativeText:@"There are no valid platforms available for the Simulator. Please make sure that at least one iOS SDK is available."];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            [[NSApplication sharedApplication] terminate:self];
        }];
        return;
    }
    
    [self buildVersionMenu];
    
    NSString *version = self.listOfVersions[0];
    
    self.listOfSimulatorDevicesInCurrentVersion = [NSMutableArray new];
    
    for (NSDictionary *dict in self.listOfSimulatorDevices) {
        if ([dict[@"version"] isEqualToString:version]) [self.listOfSimulatorDevicesInCurrentVersion addObject:dict];
    }
    
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:NO];
    NSArray *sortDescriptors = [NSArray arrayWithObject:descriptor];
    self.listOfSimulatorDevicesInCurrentVersion = [[self.listOfSimulatorDevicesInCurrentVersion sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];
    
    
    [self buildDeviceMenuForIndex:0];
    self.currentDeviceIndex = 0;
    
    [self refreshApps:nil];
}

- (void)buildVersionMenu {
    NSInteger tag = 0;
    for (NSString *thisVersion in self.listOfVersions) {
        NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:thisVersion action:@selector(selectVersion:) keyEquivalent:@""];
        [newItem setTarget:self];
        newItem.tag = tag;
        [self.versionButton.menu addItem:newItem];
        
        tag++;
    }
}

- (void)buildDeviceMenuForIndex:(NSInteger)index {
    NSString *thisVersion = self.listOfVersions[index];

    [self.deviceButton.menu removeAllItems];
    
    NSInteger tag = 0;
    for (NSDictionary *device in self.listOfSimulatorDevicesInCurrentVersion) {
        if ([device[@"version"] isEqualToString:thisVersion]) {
            NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:device[@"name"] action:@selector(refreshApps:) keyEquivalent:@""];
            [newItem setTarget:self];
            newItem.tag = tag;
            [self.deviceButton.menu addItem:newItem];
            
            tag++;
        }
    }
}

- (IBAction)selectVersion:(NSMenuItem *)sender {
    NSString *version = self.listOfVersions[sender.tag];
    
    self.listOfSimulatorDevicesInCurrentVersion = [NSMutableArray new];
    
    for (NSDictionary *dict in self.listOfSimulatorDevices) {
        if ([dict[@"version"] isEqualToString:version]) [self.listOfSimulatorDevicesInCurrentVersion addObject:dict];
    }
    
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:NO];
    NSArray *sortDescriptors = [NSArray arrayWithObject:descriptor];
    self.listOfSimulatorDevicesInCurrentVersion = [[self.listOfSimulatorDevicesInCurrentVersion sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];
    
    [self buildDeviceMenuForIndex:sender.tag];
    self.currentDeviceIndex = 0;

    [self refreshApps:nil];
}

- (IBAction)refreshApps:(id)sender {

    NSInteger index = 0;
    
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        index = [(NSMenuItem *)sender tag];
        self.currentDeviceIndex = index;
    }
    
    [self.appsArray removeAllObjects];
    
    NSDictionary *device = self.listOfSimulatorDevicesInCurrentVersion[self.currentDeviceIndex];
    self.currentDeviceUDID = device[@"UDID"];
    
    NSString *appDataDir = [NSString stringWithFormat:@"%@/%@/data/Containers/Data/Application",[self pathOfSimulator],device[@"UDID"]];

    if ([device[@"iOS7"] boolValue]) {
        appDataDir = [NSString stringWithFormat:@"%@/%@/data/Applications",[self pathOfSimulator],device[@"UDID"]];
    }
    
    NSError *error;
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:appDataDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:appDataDir withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    NSMutableDictionary *appData = [NSMutableDictionary new];
    
    for (NSString *thisAppData in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appDataDir error:nil]) {
        BOOL isDir;

        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@",appDataDir,thisAppData] isDirectory:&isDir] && isDir) {
            NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/%@/.com.apple.mobile_container_manager.metadata.plist",appDataDir,thisAppData]];
            if (metadata[@"MCMMetadataIdentifier"]) {
                [appData setValue:thisAppData forKey:metadata[@"MCMMetadataIdentifier"]];
            }
        }
    }
    
    self.currentDeviceDirectory = [NSString stringWithFormat:@"%@/%@/data/Containers/Bundle/Application",[self pathOfSimulator],device[@"UDID"]];
    
    [self.fileQueue removeAllPaths];
    [self.fileQueue addPath:self.currentDeviceDirectory];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.currentDeviceDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:self.currentDeviceDirectory withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    // Get installed apps
    NSArray *apps = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.currentDeviceDirectory error:nil];
    
    for (NSString *theApp in apps) {
        BOOL isDir;
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@",self.currentDeviceDirectory,theApp] isDirectory:&isDir] && isDir) {
            NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/%@",self.currentDeviceDirectory,theApp] error:nil];
            for (NSString *file in dirContents) {
                if ([file hasSuffix:@".app"]) {
                    NSDictionary *appDict = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/%@/%@/Info.plist",self.currentDeviceDirectory,theApp,file]];
                    NSString *appname = appDict[@"CFBundleDisplayName"];
                    if (!appname) appname = appDict[@"CFBundleName"];
                    if (!appname) appname = @"Unknown";
                    NSString *version = appDict[@"CFBundleShortVersionString"];
                    if (!version) version = @"?";
                    NSString *bundleIdentifier = appDict[@"CFBundleIdentifier"];
                    if (!bundleIdentifier) bundleIdentifier = @"?";
                    NSString *build = appDict[@"CFBundleVersion"];
                    if (!build) build = @"?";
                    NSString *dataDir = @"none";
                    if (appData[bundleIdentifier]) {
                        dataDir = appData[bundleIdentifier];
                    }
                    
                    NSDictionary *thisApp = @{@"displayName":appname,@"version":version,@"build":build,@"bundleID":bundleIdentifier,@"udid":theApp,@"udid_data":dataDir,@"filename":file};
                    [self.appsArray addObject:thisApp];
                }
            }
        }
    }
    [self.tableView reloadData];
}

- (void)setupManager {
    [[self tableView] registerForDraggedTypes:[NSArray arrayWithObject:(NSString*)kUTTypeFileURL]];
    [self.tableView setTarget:self];
    [self.tableView setDoubleAction:@selector(doubleClick:)];
    self.fileQueue = [VDKQueue new];
    self.fileQueue.delegate = self;
}

- (IBAction)relaunchSimulator:(id)sender {
    NSArray *simulator = [NSRunningApplication runningApplicationsWithBundleIdentifier: @"com.apple.iphonesimulator"];
    
    if (simulator && simulator.count > 0) {
        int pid = [simulator[0] processIdentifier];
        
        // Kill it with fire:
        [[NSTask launchedTaskWithLaunchPath:@"/bin/kill" arguments:[NSArray arrayWithObjects:@"-hup",[NSString stringWithFormat:@"%i",pid], nil]] waitUntilExit];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (![[NSWorkspace sharedWorkspace] launchApplication:[[NSUserDefaults standardUserDefaults] objectForKey:@"simulatorPath"]]) NSLog(@"iOS Simulator failed to launch");
        });
    } else {
        if (![[NSWorkspace sharedWorkspace] launchApplication:[[NSUserDefaults standardUserDefaults] objectForKey:@"simulatorPath"]]) NSLog(@"iOS Simulator failed to launch");
    }
}

- (IBAction)exportApp:(id)sender {
    
    NSInteger selectedRow = [self.tableView selectedRow];
    
    if (selectedRow == -1) {
        NSAlert *noRowSelectedAlert = [NSAlert new];
        [noRowSelectedAlert addButtonWithTitle:@"OK"];
        [noRowSelectedAlert setMessageText:@"No app selected"];
        [noRowSelectedAlert setInformativeText:@"Please select an app to export."];
        [noRowSelectedAlert setAlertStyle:NSInformationalAlertStyle];
        [noRowSelectedAlert beginSheetModalForWindow:self.window completionHandler:nil];

        return;
    }

    
    NSDictionary *appDict = self.appsArray[self.tableView.selectedRow];
    
    // create the save panel
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setNameFieldStringValue:[NSString stringWithFormat:@"%@.simarchive",appDict[@"displayName"]]];
    NSButton *button = [[NSButton alloc] init];
    [button setButtonType:NSSwitchButton];
    button.title = @"Include the App's Document directory";
    [button sizeToFit];
    [panel setAccessoryView:button];
    button.state = NSOffState;
    self.includeDocumentsDirectory = NO;
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *saveURL = [panel URL];
            
            NSURL *directoryURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]] isDirectory:YES];
            
            NSString *appDataDir = [NSString stringWithFormat:@"%@/%@/data/Containers/Data/Application",[self pathOfSimulator],self.currentDeviceUDID];
            
            NSError *error = nil;

            NSURL *tempTarget = [directoryURL URLByAppendingPathComponent:@"files"];
            
            [[NSFileManager defaultManager] createDirectoryAtURL:tempTarget withIntermediateDirectories:YES attributes:nil error:&error];
            
            if (error) {
                [self showErrorMessageWithTitle:@"An error occured" andMessage:error.description];
                return;
            }
            
            NSURL *bundleURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",self.currentDeviceDirectory,appDict[@"udid"]]];
            
            [[NSFileManager defaultManager] copyItemAtURL:bundleURL toURL:[tempTarget URLByAppendingPathComponent:appDict[@"udid"]] error:&error];
            
            if (error) {
                [self showErrorMessageWithTitle:@"An error occured" andMessage:error.description];
                return;
            }
            
            NSString *appdata = @"none";
            
            if (button.state == NSOnState) {
                if (![appDict[@"udid_data"] isEqualToString:@"none"]) {
                    // include docs
                    NSURL *docsURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",appDataDir,appDict[@"udid_data"]]];
                    
                    [[NSFileManager defaultManager] copyItemAtURL:docsURL toURL:[tempTarget URLByAppendingPathComponent:appDict[@"udid_data"]] error:&error];
                    
                    if (error) {
                        [self showErrorMessageWithTitle:@"An error occured" andMessage:error.description];
                        return;
                    }
                    appdata = appDict[@"udid_data"];
                }
            }
            
            NSDictionary *dataDict = @{@"displayName":appDict[@"displayName"],
                                       @"udid":appDict[@"udid"],
                                       @"udid_data":appdata,
                                       @"version":appDict[@"version"],
                                       @"build":appDict[@"build"],
                                       @"bundleID":appDict[@"bundleID"]
                                       };
            
            [dataDict writeToURL:[tempTarget URLByAppendingPathComponent:@"data.plist"] atomically:NO];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:[saveURL path]]) {
                [[NSFileManager defaultManager] removeItemAtURL:saveURL error:&error];
            }
            
            if (error) {
                [self showErrorMessageWithTitle:@"An error occured" andMessage:error.description];
                return;
            }
            
            NSURL *tmpFile = [directoryURL URLByAppendingPathComponent:panel.URL.lastPathComponent];
            
            [self zipFilesInDirectory:[tempTarget path] withTargetFile:[tmpFile path]];
            
            if (![[NSFileManager defaultManager] fileExistsAtPath:[tmpFile path]]) {
                // Something went wrong
                
                [[NSFileManager defaultManager] removeItemAtURL:directoryURL error:nil];
                
                NSAlert *alert = [NSAlert new];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Export unsuccessful"];
                [alert setInformativeText:@"There was an error exporting the app. Please make sure that you have enough disk space on your Mac (at least twice the amount of the app you're trying to export)"];
                [alert setAlertStyle:NSCriticalAlertStyle];
                [alert beginSheetModalForWindow:self.window completionHandler:nil];
                return;
            }
            
            [[NSFileManager defaultManager] moveItemAtURL:tmpFile toURL:saveURL error:&error];
            if (error) {
                [self showErrorMessageWithTitle:@"An error occured" andMessage:error.description];
                return;
            }
            // cleanup
            
            [[NSFileManager defaultManager] removeItemAtURL:directoryURL error:&error];
        }
    }];
}

- (BOOL)zipFilesInDirectory:(NSString *)dir withTargetFile:(NSString *)targetFile {
    
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/ditto";
    task.arguments = @[@"-c", @"-k", @"--sequesterRsrc", @"--keepParent", dir, targetFile];
    task.standardOutput = pipe;
    
    [task launch];
    
    return YES;
}

- (BOOL)unzipFilesInDirectory:(NSString *)file toDirectory:(NSString *)targetDir {
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/unzip";
    task.arguments = @[@"-d", targetDir, file];
    task.standardOutput = pipe;
    
    [task launch];

    return YES;
}

- (IBAction)rowSelected:(id)sender {
    NSInteger selectedRow = [sender selectedRow];
    
    if (selectedRow != -1) {
        self.exportButton.enabled = YES;
        self.exportMenuItem.enabled = YES;
    }
    else {
        self.exportButton.enabled = NO;
        self.exportMenuItem.enabled = NO;
    }
}

- (IBAction)importApp:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.allowedFileTypes = @[@"simarchive"];
    NSButton *button = [[NSButton alloc] init];
    [button setButtonType:NSSwitchButton];
    button.title = @"Include the App's Document directory";
    [button sizeToFit];
    [panel setAccessoryView:button];
    button.state = NSOffState;
    self.includeDocumentsDirectory = NO;
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            BOOL copyData = NO;
            if (button.state == NSOnState) copyData = YES;
            
            [self importAppToCurrentDevice:[panel URL] withDocuments:copyData askForDocs:NO];
        }
    }];
}

- (BOOL)importAppToCurrentDevice:(NSURL *)fileURL withDocuments:(BOOL)documents askForDocs:(BOOL)askForDocs {
    
    NSError *error;
    
    NSURL *directoryURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]] isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&error];
    NSURL *tempTarget = [directoryURL URLByAppendingPathComponent:@"files"];
    
    [self unzipFilesInDirectory:[fileURL path] toDirectory:[directoryURL path]];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:[tempTarget path]] || ![[NSFileManager defaultManager] fileExistsAtPath:[[tempTarget URLByAppendingPathComponent:@"data.plist"] path]]) {
        // Something went wrong
        
        [[NSFileManager defaultManager] removeItemAtURL:directoryURL error:nil];
        
        NSAlert *alert = [NSAlert new];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Import unsuccessful"];
        [alert setInformativeText:@"There was an error importing the app. Please make sure that the file is a SimArchive file and that you have enough disk space on your Mac (at least twice the amount of the archive you're trying to import)."];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
        return NO;
    }
    
    NSDictionary *appDict = [NSDictionary dictionaryWithContentsOfURL:[tempTarget URLByAppendingPathComponent:@"data.plist"]];
    NSString *bundleIdentifier = appDict[@"bundleID"];
    
    BOOL sameBundleID = NO;
    NSDictionary *sameBundleDict = [NSDictionary new];
    
    for (NSDictionary *otherAppDict in self.appsArray) {
        if ([otherAppDict[@"bundleID"] isEqualToString:bundleIdentifier]) {
            sameBundleID = YES;
            sameBundleDict = otherAppDict;
        }
    }
    
    if (sameBundleID) {
        [[NSFileManager defaultManager] removeItemAtURL:directoryURL error:nil];

        NSAlert *samebundleIDAlert = [NSAlert new];
        [samebundleIDAlert addButtonWithTitle:@"Move to Trash"];
        [samebundleIDAlert addButtonWithTitle:@"Cancel"];
        [samebundleIDAlert setMessageText:@"Duplicate bundle identifier"];
        [samebundleIDAlert setInformativeText:[NSString stringWithFormat:@"An app with the bundle identifier '%@' is already present on this simulator device. Would you like to move the existing app to the Trash and import the new app?",bundleIdentifier]];
        [samebundleIDAlert setAlertStyle:NSCriticalAlertStyle];
        [samebundleIDAlert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == 1000) {
                // Overwrite
                [self deleteAppWithDict:sameBundleDict];
                [self importAppToCurrentDevice:fileURL withDocuments:documents askForDocs:askForDocs];
            }
        }];
        return NO;
    }
    
    if (askForDocs) {
        if (![appDict[@"udid_data"] isEqualToString:@"none"]) {
            NSAlert *askForDocs = [NSAlert new];
            [askForDocs addButtonWithTitle:@"Yes, import"];
            [askForDocs addButtonWithTitle:@"No, ignore"];
            [askForDocs setMessageText:@"Import Documents directory?"];
            [askForDocs setInformativeText:@"This app archive includes a Documents directory. Do you want to import it as well?"];
            [askForDocs setAlertStyle:NSInformationalAlertStyle];
            [askForDocs beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                NSError *error;
                
                NSURL *targetAppDir = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",self.currentDeviceDirectory,appDict[@"udid"]]];
                NSURL *targetDataDir =  [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@/data/Containers/Data/Application/%@",[self pathOfSimulator],self.currentDeviceUDID,appDict[@"udid_data"]]];
                
                [[NSFileManager defaultManager] moveItemAtURL:[tempTarget URLByAppendingPathComponent:appDict[@"udid"]] toURL:targetAppDir error:&error];
                if (error) {
                    [self showErrorMessageWithTitle:@"An error occured" andMessage:error.description];
                    return;
                }
                if (returnCode == 1000) {
                    [[NSFileManager defaultManager] moveItemAtURL:[tempTarget URLByAppendingPathComponent:appDict[@"udid_data"]] toURL:targetDataDir error:&error];
                }
                [self refreshApps:nil];
                // cleanup
                
                [[NSFileManager defaultManager] removeItemAtURL:directoryURL error:&error];
            }];
        } else {
            NSError *error;
            
            NSURL *targetAppDir = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",self.currentDeviceDirectory,appDict[@"udid"]]];
            NSURL *targetDataDir =  [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@/data/Containers/Data/Application/%@",[self pathOfSimulator],self.currentDeviceUDID,appDict[@"udid_data"]]];
            
            [[NSFileManager defaultManager] moveItemAtURL:[tempTarget URLByAppendingPathComponent:appDict[@"udid"]] toURL:targetAppDir error:&error];
            
            if (error) {
                [self showErrorMessageWithTitle:@"An error occured" andMessage:error.description];
            } else {
                if (documents) {
                    if (![appDict[@"udid_data"] isEqualToString:@"none"]) {
                        [[NSFileManager defaultManager] moveItemAtURL:[tempTarget URLByAppendingPathComponent:appDict[@"udid_data"]] toURL:targetDataDir error:&error];
                    
                        if (error) [self showErrorMessageWithTitle:@"An error occured" andMessage:error.description];
                    }
                }
                [self refreshApps:nil];
            }
            // cleanup
            
            [[NSFileManager defaultManager] removeItemAtURL:directoryURL error:&error];
        }
    } else {
        NSError *error;
        
        NSURL *targetAppDir = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",self.currentDeviceDirectory,appDict[@"udid"]]];
        NSURL *targetDataDir =  [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@/data/Containers/Data/Application/%@",[self pathOfSimulator],self.currentDeviceUDID,appDict[@"udid_data"]]];
        
        [[NSFileManager defaultManager] moveItemAtURL:[tempTarget URLByAppendingPathComponent:appDict[@"udid"]] toURL:targetAppDir error:&error];
        
        if (error) {
            [self showErrorMessageWithTitle:@"An error occured" andMessage:error.description];
        } else {
            if (documents) {
                if (![appDict[@"udid_data"] isEqualToString:@"none"]) {
                    [[NSFileManager defaultManager] moveItemAtURL:[tempTarget URLByAppendingPathComponent:appDict[@"udid_data"]] toURL:targetDataDir error:&error];
                    
                    if (error) [self showErrorMessageWithTitle:@"An error occured" andMessage:error.description];
                    
                }
            }
            [self refreshApps:nil];

        }
        // cleanup
        
        [[NSFileManager defaultManager] removeItemAtURL:directoryURL error:&error];
    }
    
    return YES;
}

- (BOOL)fileIsAcceptedFileType:(NSURL *)fileURL {
    NSURL *directoryURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]] isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:nil];

    if ([[fileURL pathExtension] isEqualToString:@"simarchive"]) {
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/bin/unzip";
        task.arguments = @[fileURL, @"\"files/data.plist\"", @"-d", directoryURL];
        
        [task launch];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[[directoryURL URLByAppendingPathComponent:@"files/data.plist"] path]]) return YES;
    }
    [[NSFileManager defaultManager] removeItemAtURL:directoryURL error:nil];
    return NO;
}

#pragma mark - TableView delegate & data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.appsArray.count;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    
    NSView *result;
    
    if (result == nil) {
        result = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 30)];
        //result.identifier = @"resultCell";
    }
    
    NSDictionary *thisApp = self.appsArray[row];
    DSWVerticallyCenteredTextField *textFieldCell = [DSWVerticallyCenteredTextField new];
    
    NSTextField *name = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 30)];
    [result addSubview:name];
    name.bezelStyle = 0;
    name.cell = textFieldCell;
    name.bordered = NO;
    name.backgroundColor = [NSColor clearColor];
    name.editable = NO;
    name.selectable = NO;
    
    if (tableColumn == self.nameColumn) {
        name.stringValue = thisApp[@"displayName"];
    } else if (tableColumn == self.versionColumn) {
        name.stringValue = thisApp[@"version"];
    } else if (tableColumn == self.buildColumn) {
            name.stringValue = thisApp[@"build"];
    } else if (tableColumn == self.bundleIdentifierColumn) {
        name.stringValue = thisApp[@"bundleID"];
    }
    return result;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    return 30.0f;
}

#pragma mark - Drag & Drop

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
    //get the file URLs from the pasteboard
    NSPasteboard *pasteBoard = info.draggingPasteboard;
    
    //list the file type UTIs we want to accept
    NSArray *acceptedType = [NSArray arrayWithObject:(NSString*)kUTTypeItem];
    
    NSArray *urls = [pasteBoard readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],NSPasteboardURLReadingFileURLsOnlyKey,acceptedType, NSPasteboardURLReadingContentsConformToTypesKey,
                                               nil]];
    
    //only allow drag if there is exactly one file
    if (urls.count != 1) return NSDragOperationNone;
   // if (![self fileIsAcceptedFileType:urls[0]]) return NSDragOperationNone;
    
    return NSDragOperationCopy;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    NSPasteboard *pboard = [info draggingPasteboard];
    
    if ( [[pboard types] containsObject:NSURLPboardType] ) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        
        [self importAppToCurrentDevice:[NSURL fileURLWithPath:files[0]] withDocuments:NO askForDocs:YES];
    }

    return YES;
}



#pragma mark - DoubleClick

- (void)doubleClick:(id)sender {
    NSInteger rowNumber = [self.tableView clickedRow];

    NSString *appDataDir = [NSString stringWithFormat:@"%@/%@/data/Containers/Data/Application",[self pathOfSimulator],self.currentDeviceUDID];
   
    if (self.appsArray.count > 0 && rowNumber < self.appsArray.count) {
        NSDictionary *appDict = self.appsArray[rowNumber];
        
        if (appDict) {
            if (![appDict[@"udid_data"] isEqualToString:@"none"]) [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",appDataDir,appDict[@"udid_data"]]]]];
        }
    }
}

#pragma mark - Context Menu and methods

- (NSMenu *)tableView:(NSTableView *)aTableView menuForRows:(NSIndexSet *)rows {
    NSMenu *contextMenu = [NSMenu new];
    contextMenu.autoenablesItems = NO;
    
    NSMenuItem *showInFinderItem = [[NSMenuItem alloc] initWithTitle:@"Show in Finder" action:@selector(showInFinder:) keyEquivalent:@""];
    showInFinderItem.target = self;
    showInFinderItem.tag = rows.firstIndex;
    [contextMenu addItem:showInFinderItem];
    
    NSMenuItem *showDocumentsInFinderItem = [[NSMenuItem alloc] initWithTitle:@"Show Documents in Finder" action:@selector(showDocumentsInFinder:) keyEquivalent:@""];
    showDocumentsInFinderItem.target = self;
    showDocumentsInFinderItem.tag = rows.firstIndex;
    [contextMenu addItem:showDocumentsInFinderItem];
    
    [contextMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *deleteAppItem = [[NSMenuItem alloc] initWithTitle:@"Move to Trash" action:@selector(deleteApp:) keyEquivalent:@""];
    deleteAppItem.target = self;
    deleteAppItem.tag = rows.firstIndex;
    [contextMenu addItem:deleteAppItem];
    
    return contextMenu;
}

- (void)showInFinder:(NSMenuItem *)sender {

    if (self.appsArray.count > 0 && sender.tag < self.appsArray.count) {
        NSDictionary *appDict = self.appsArray[sender.tag];
        
        if (appDict) {
            if (![appDict[@"udid"] isEqualToString:@"none"]) [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@/%@",self.currentDeviceDirectory,appDict[@"udid"],appDict[@"filename"]]]]];
        }
    }
}

- (void)showDocumentsInFinder:(NSMenuItem *)sender {
    NSString *appDataDir = [NSString stringWithFormat:@"%@/%@/data/Containers/Data/Application",[self pathOfSimulator],self.currentDeviceUDID];
    
    if (self.appsArray.count > 0 && sender.tag < self.appsArray.count) {
        NSDictionary *appDict = self.appsArray[sender.tag];
        
        if (appDict) {
            if (![appDict[@"udid_data"] isEqualToString:@"none"]) [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",appDataDir,appDict[@"udid_data"]]]]];
        }
    }
}

- (void)deleteApp:(NSMenuItem *)sender {
    if (self.appsArray.count > 0 && sender.tag < self.appsArray.count) {
        NSDictionary *appDict = self.appsArray[sender.tag];
        
        [self deleteAppWithDict:appDict];
    }
}

- (void)deleteAppWithDict:(NSDictionary *)appDict {
    NSString *appDataDir = [NSString stringWithFormat:@"%@/%@/data/Containers/Data/Application",[self pathOfSimulator],self.currentDeviceUDID];

    if (appDict) {
        [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
                                                     source:self.currentDeviceDirectory
                                                destination:@""
                                                      files:@[appDict[@"udid"]]
                                                        tag:nil];
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"includeDocuments"]) {
            [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
                                                         source:appDataDir
                                                    destination:@""
                                                          files:@[appDict[@"udid_data"]]
                                                            tag:nil];
        }
    }
    [self refreshApps:nil];
}

- (IBAction)openAboutWindow:(id)sender {
    self.aboutWindowController = [DCOAboutWindowController new];
    self.aboutWindowController.appWebsiteURL = [NSURL URLWithString:@"http://fouquet.me/apps/simarchive"];
    self.aboutWindowController.useTextViewForAcknowledgments = YES;
    [self.aboutWindowController showWindow:nil];
}

- (void)showErrorMessageWithTitle:(NSString *)title andMessage:(NSString *)message {
    NSAlert *errorAlert = [NSAlert new];
    [errorAlert addButtonWithTitle:@"OK"];
    [errorAlert setMessageText:title];
    [errorAlert setInformativeText:message];
    [errorAlert setAlertStyle:NSCriticalAlertStyle];
    [errorAlert beginSheetModalForWindow:self.window completionHandler:nil];
}


#pragma mark - Regex helper methods
                    
- (BOOL)string:(NSString *)inputString matchesRegularExpression:(NSString *)regex {
    if (!inputString) return NO;
    
    return [[NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:nil] numberOfMatchesInString:inputString options:0 range:NSMakeRange(0, inputString.length)];
}

- (NSString *)matchingSubstringOfString:(NSString *)inputString forRegularExpression:(NSString *)regex {
    if (!inputString) return nil;
    
    NSRegularExpression *valueRegEx = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:nil];
    NSTextCheckingResult *match = [valueRegEx firstMatchInString:inputString options:0 range:NSMakeRange(0, inputString.length)];
    
    return [inputString substringWithRange:match.range];
}

#pragma mark - Other

- (NSString *)developerDirectory {
    NSDictionary* env = [[NSProcessInfo processInfo] environment];
    NSString* developerDir = [env objectForKey:@"DEVELOPER_DIR"];
    if ([developerDir length] > 0) {
        return developerDir;
    }
    
    // Go look for it via xcode-select.
    NSTask* xcodeSelectTask = [[NSTask alloc] init];
    [xcodeSelectTask setLaunchPath:@"/usr/bin/xcode-select"];
    [xcodeSelectTask setArguments:[NSArray arrayWithObject:@"-print-path"]];
    
    NSPipe* outputPipe = [NSPipe pipe];
    [xcodeSelectTask setStandardOutput:outputPipe];
    NSFileHandle* outputFile = [outputPipe fileHandleForReading];
    
    [xcodeSelectTask launch];
    NSData* outputData = [outputFile readDataToEndOfFile];
    [xcodeSelectTask terminate];
    
    NSString* output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
    output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([output length] == 0) {
        output = nil;
    }
    return output;
}

- (NSString *)XcodeVersion {
    // Go look for it via xcodebuild.
    NSTask* xcodeBuildTask = [[NSTask alloc] init];
    [xcodeBuildTask setLaunchPath:@"/usr/bin/xcodebuild"];
    [xcodeBuildTask setArguments:[NSArray arrayWithObject:@"-version"]];
    
    NSPipe* outputPipe = [NSPipe pipe];
    [xcodeBuildTask setStandardOutput:outputPipe];
    NSFileHandle* outputFile = [outputPipe fileHandleForReading];
    
    [xcodeBuildTask launch];
    NSData* outputData = [outputFile readDataToEndOfFile];
    [xcodeBuildTask terminate];
    
    NSString* output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
    output = [output stringByTrimmingCharactersInSet:
              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([output length] == 0) {
        output = nil;
    } else {
        NSArray* parts = [output componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([parts count] >= 2) {
            return parts[1];
        }
    }
    return output;
}

- (void)getValidPlatforms {
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [NSString stringWithFormat:@"%@/usr/bin/simctl",[self developerDirectory]];
    task.arguments = @[@"list", @"runtimes"];
    task.standardOutput = pipe;
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSMutableArray *fileLines = [[NSMutableArray alloc] initWithArray:[[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] componentsSeparatedByString:@"\n"] copyItems: YES];

    self.listOfValidPlatforms = [NSMutableArray new];
    
    for (NSString *line in fileLines) {
        if ([line containsString:@"com.apple.CoreSimulator.SimRuntime"] && ![line containsString:@"unavailable"]) {
            NSString *output = [self matchingSubstringOfString:line forRegularExpression:@"(com.apple.CoreSimulator.SimRuntime.)((?:[a-z][a-z]+))(-)(\\d+)(-)(\\d+)"];
            [self.listOfValidPlatforms addObject:output];
        }
    }
    
}

#pragma mark - Folder change notification

- (void)VDKQueue:(VDKQueue *)queue receivedNotification:(NSString *)noteName forPath:(NSString *)fpath {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshApps:nil];
    });
}
                    
@end
