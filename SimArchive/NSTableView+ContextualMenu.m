//
//  NSTableView+ContextualMenu.m
//  Simulator App Archiver
//
//  Created by René Fouquet on 30/01/15.
//  Copyright (c) 2015 René Fouquet. All rights reserved.
//

#import "NSTableView+ContextualMenu.h"

@implementation NSTableView (ContextualMenu)

- (NSMenu*)menuForEvent:(NSEvent*)event
{
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    NSInteger row = [self rowAtPoint:location];
    if (!(row >= 0) || ([event type] != NSRightMouseDown)) {
        return [super menuForEvent:event];
    }
    NSIndexSet *selected = [self selectedRowIndexes];
    if (![selected containsIndex:row]) {
        selected = [NSIndexSet indexSetWithIndex:row];
        [self selectRowIndexes:selected byExtendingSelection:NO];
    }
    if ([[self delegate] respondsToSelector:@selector(tableView:menuForRows:)]) {
        return [(id)[self delegate] tableView:self menuForRows:selected];
    }
    return [super menuForEvent:event];
}
@end