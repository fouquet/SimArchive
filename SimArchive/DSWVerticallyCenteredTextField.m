//
//  DSWVerticallyCenteredTextField.m
//  DictationSwitcher
//
//  Created by René Fouquet on 27/01/15.
//  Copyright (c) 2015 René Fouquet. All rights reserved.
//

#import "DSWVerticallyCenteredTextField.h"

@implementation DSWVerticallyCenteredTextField

- (NSRect)adjustedFrameToVerticallyCenterText:(NSRect)frame {
    NSInteger offset = floor((NSHeight(frame) -
                              ([[self font] ascender] - [[self font] descender])) / 2);
    return NSInsetRect(frame, 0.0, offset);
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView
               editor:(NSText *)editor delegate:(id)delegate event:(NSEvent *)event {
    [super editWithFrame:[self adjustedFrameToVerticallyCenterText:aRect]
                  inView:controlView editor:editor delegate:delegate event:event];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView
                 editor:(NSText *)editor delegate:(id)delegate
                  start:(NSInteger)start length:(NSInteger)length {
    
    [super selectWithFrame:[self adjustedFrameToVerticallyCenterText:aRect]
                    inView:controlView editor:editor delegate:delegate
                     start:start length:length];
}

- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)view {
    [super drawInteriorWithFrame:
     [self adjustedFrameToVerticallyCenterText:frame] inView:view];
}

@end
