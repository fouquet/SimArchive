//
//  NSTableView+ContextualMenu.h
//  Simulator App Archiver
//
//  Created by René Fouquet on 30/01/15.
//  Copyright (c) 2015 René Fouquet. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol ContextualMenuDelegate <NSObject>
- (NSMenu*)tableView:(NSTableView*)aTableView menuForRows:(NSIndexSet*)rows;
@end

@interface NSTableView (ContextualMenu)

@end