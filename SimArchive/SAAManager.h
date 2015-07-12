//
//  SAAManager.h
//  Simulator App Archiver
//
//  Created by René Fouquet on 29/01/15.
//  Copyright (c) 2015 René Fouquet. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "NSTableView+ContextualMenu.h"
#import "VDKQueue.h"

@class DCOAboutWindowController;

@interface SAAManager : NSObject <NSTableViewDataSource, NSTableViewDelegate, ContextualMenuDelegate, VDKQueueDelegate>

@property (nonatomic, strong) NSMutableArray *listOfSimulatorDevices;
@property (nonatomic, strong) NSMutableArray *listOfSimulatorDevicesInCurrentVersion;
@property (nonatomic, strong) NSMutableArray *listOfVersions;
@property (nonatomic, strong) NSMutableArray *listOfValidPlatforms;
@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) DCOAboutWindowController *aboutWindowController;

@property (nonatomic) BOOL includeDocumentsDirectory;
@property (weak) IBOutlet NSPopUpButton *versionButton;
@property (weak) IBOutlet NSPopUpButton *deviceButton;

@property (nonatomic) IBOutlet NSMutableArray *appsArray;
@property (weak) IBOutlet NSButton *exportButton;

@property (nonatomic) NSString *currentDeviceDirectory;
@property (nonatomic) NSString *currentDeviceUDID;

@property (nonatomic) NSInteger currentDeviceIndex;
@property (weak) IBOutlet NSMenuItem *exportMenuItem;

@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSTableColumn *nameColumn;
@property (weak) IBOutlet NSTableColumn *versionColumn;
@property (weak) IBOutlet NSTableColumn *bundleIdentifierColumn;
@property (weak) IBOutlet NSTableColumn *buildColumn;

@property (nonatomic) VDKQueue *fileQueue;

- (void)getDevices;
- (IBAction)refreshApps:(id)sender;
- (void)setupManager;
- (IBAction)relaunchSimulator:(id)sender;
- (IBAction)exportApp:(id)sender;
- (IBAction)rowSelected:(id)sender;
- (IBAction)importApp:(id)sender;
- (IBAction)openAboutWindow:(id)sender;
- (NSString *)developerDirectory;
- (NSString *)XcodeVersion;

- (BOOL)importAppToCurrentDevice:(NSURL *)fileURL withDocuments:(BOOL)documents askForDocs:(BOOL)askForDocs;

@end
