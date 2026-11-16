#import <Cocoa/Cocoa.h>
#import "YSBrandMark.h"
#import "YSG3Corners.h"

// One approved application-icon rendering for the ICNS and promotional artwork.
static inline void YSDrawBrandIcon(CGFloat side) {
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    [NSGraphicsContext saveGraphicsState];
    CGContextScaleCTM(context, side / 1024, side / 1024);
    NSBezierPath *tile = YSG3RoundedRect(NSMakeRect(64,64,896,896), 207);
    [NSGraphicsContext saveGraphicsState];
    NSShadow *shadow = [NSShadow new];
    shadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.13];
    shadow.shadowBlurRadius = 26; shadow.shadowOffset = NSMakeSize(0,-10);
    [shadow set]; [[NSColor colorWithWhite:0.4 alpha:1] setFill]; [tile fill];
    [NSGraphicsContext restoreGraphicsState];
    NSGradient *surface = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithSRGBRed:0.59 green:0.65 blue:0.71 alpha:1]
                                                     endingColor:[NSColor colorWithSRGBRed:0.24 green:0.29 blue:0.35 alpha:1]];
    [surface drawInBezierPath:tile angle:90];
    [[NSColor colorWithWhite:1 alpha:0.4] setStroke]; tile.lineWidth = 2; [tile stroke];
    NSBezierPath *inner = YSG3RoundedRect(NSMakeRect(69,69,886,886), 202);
    [[NSColor colorWithWhite:1 alpha:0.10] setStroke]; inner.lineWidth = 2; [inner stroke];
    // The same restrained local contrast treatment as the small drag handle.
    YSDrawBrandMark(context, NSMakeRect(236,239,552,552), [NSColor colorWithWhite:0 alpha:0.16]);
    YSDrawBrandMark(context, NSMakeRect(234,234,552,552), [NSColor colorWithWhite:1 alpha:0.98]);
    [NSGraphicsContext restoreGraphicsState];
}
