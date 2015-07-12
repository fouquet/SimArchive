//
//  AppDelegate.h
//  Simulator App Archiver
//
//  Created by René Fouquet on 29/01/15.
//  Copyright (c) 2015 René Fouquet. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SAAManager.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet SAAManager *manager;

@end

