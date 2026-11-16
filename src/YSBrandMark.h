#import <Cocoa/Cocoa.h>
#import "YSLocalization.h"

// Approved D mark: two parallel, offset tracks. Shared by every brand surface.
static inline NSArray<NSBezierPath *> *YSBrandPaths(void) {
    NSBezierPath *longTrack = [NSBezierPath bezierPath];
    [longTrack moveToPoint:NSMakePoint(2.3, 16.7)];
    [longTrack lineToPoint:NSMakePoint(15, 4)];
    [longTrack lineToPoint:NSMakePoint(18, 7)];
    [longTrack lineToPoint:NSMakePoint(5.3, 19.7)];
    [longTrack closePath];
    NSBezierPath *shortTrack = [NSBezierPath bezierPath];
    [shortTrack moveToPoint:NSMakePoint(12, 16.8)];
    [shortTrack lineToPoint:NSMakePoint(19, 9.8)];
    [shortTrack lineToPoint:NSMakePoint(22, 12.8)];
    [shortTrack lineToPoint:NSMakePoint(15, 19.8)];
    [shortTrack closePath];
    return @[longTrack, shortTrack];
}

static inline void YSDrawBrandMark(CGContextRef context, NSRect rect, NSColor *color) {
    [NSGraphicsContext saveGraphicsState];
    CGContextTranslateCTM(context, rect.origin.x, rect.origin.y);
    CGContextScaleCTM(context, rect.size.width / 24, rect.size.height / 24);
    CGContextSetAlpha(context, color.alphaComponent);
    CGContextBeginTransparencyLayer(context, NULL);
    [[color colorWithAlphaComponent:1] setFill];
    for (NSBezierPath *path in YSBrandPaths()) [path fill];
    CGContextEndTransparencyLayer(context);
    [NSGraphicsContext restoreGraphicsState];
}

static inline NSImage *YSBrandImage(NSSize size) {
    NSImage *image = [NSImage imageWithSize:size flipped:YES drawingHandler:^BOOL(NSRect rect) {
        YSDrawBrandMark(NSGraphicsContext.currentContext.CGContext, rect, NSColor.blackColor);
        return YES;
    }];
    image.template = YES;
    image.accessibilityDescription = YSL(@"双轨记错位双轨");
    return image;
}
