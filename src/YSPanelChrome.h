#import <Cocoa/Cocoa.h>
#import "YSLocalization.h"
#import "YSG3Corners.h"

// Shared material for the single upper-left drag handle in either state.
static inline void YSDrawFrostedChrome(CGContextRef context, CGRect rect, CGFloat radius, BOOL hovered) {
    CGContextSaveGState(context);
    CGPathRef outline = CGPathCreateWithRoundedRect(CGRectInset(rect, 0.5, 0.5), radius, radius, NULL);
    CGContextAddPath(context, outline);
    CGContextSetRGBFillColor(context, 0.72, 0.72, 0.72, hovered ? 0.44 : 0.32);
    CGContextFillPath(context);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat colors[] = {1, 1, 1, 0.18, 1, 1, 1, 0.01};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(space, colors, NULL, 2);
    CGContextSaveGState(context);
    CGContextAddPath(context, outline);
    CGContextClip(context);
    BOOL flipped = NSGraphicsContext.currentContext.isFlipped;
    CGFloat top = flipped ? CGRectGetMinY(rect) : CGRectGetMaxY(rect);
    CGFloat bottom = flipped ? CGRectGetMaxY(rect) : CGRectGetMinY(rect);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(CGRectGetMidX(rect), top),
                                CGPointMake(CGRectGetMidX(rect), bottom), 0);
    CGContextRestoreGState(context);
    CGContextAddPath(context, outline);
    CGContextSetRGBStrokeColor(context, 1, 1, 1, hovered ? 0.42 : 0.26);
    CGContextSetLineWidth(context, 1);
    CGContextStrokePath(context);
    CGPathRelease(outline);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    CGContextRestoreGState(context);
}

static inline NSImage *YSStickyGlyphImage(void) {
    NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithPointSize:16 weight:NSFontWeightMedium];
    NSImage *image = [[NSImage imageWithSystemSymbolName:@"pin.fill" accessibilityDescription:YSL(@"便签图钉")] imageWithSymbolConfiguration:configuration];
    image.template = YES;
    return image;
}

typedef struct { NSPoint point, derivative; } YSResizeArcSample;

// Flipped coordinates. Offset the FULL panel corner along its inward unit
// normal, rather than scaling a second corner. The handle ends 4pt before
// both panel edges, so their intersection is bounds.max + (4,4).
static inline YSResizeArcSample YSResizeArcSampleAt(NSPoint edge, CGFloat extent,
                                                  CGFloat inset, CGFloat t) {
    YSG3CornerJet j = YSG3EvaluateCorner(t);
    CGFloat speed = hypot(j.d1.x, j.d1.y);
    CGFloat curvature = (j.d1.x * j.d2.y - j.d1.y * j.d2.x) / (speed * speed * speed);
    CGFloat scale = extent - inset * curvature;
    return (YSResizeArcSample){
        NSMakePoint(edge.x - extent * j.point.y - inset * j.d1.x / speed,
                    edge.y - extent + extent * j.point.x - inset * j.d1.y / speed),
        NSMakePoint(-scale * j.d1.y, scale * j.d1.x)
    };
}

// The central t=[.28,.72] contour is approximated with C1 cubic Hermite spans.
// The independent check samples their default-R18 offset error below .001pt.
// Invalid/nonfinite/precision-degenerate bounds or radii, offsets that could
// cusp, and strokes that cannot fit (INCLUDING the .6pt round caps) return no
// paths. Counts above two select two; count one keeps the outer stroke.
static inline NSArray<NSBezierPath *> *YSResizeArcPaths(NSRect bounds, CGFloat cornerRadius, NSUInteger count) {
    count = MIN(2, count);
    if (!count || !YSG3PrivateRectIsUsable(bounds) || !isfinite(cornerRadius) || cornerRadius <= 0)
        return @[];
    CGFloat extent = YSG3CornerExtent(NSMakeRect(0, 0, 4 * cornerRadius, 4 * cornerRadius), cornerRadius);
    // Unit-corner curvature is <3 (certified by the offline checker). Keeping
    // extent > inset*3 makes every inward offset regular, without a cusp.
    if (extent <= 3 * (count == 1 ? 5.5 : 10)) return @[];
    NSPoint edge = NSMakePoint(NSMaxX(bounds) + 4, NSMaxY(bounds) + 4);
    NSRect safe = NSInsetRect(bounds, 0.6, 0.6);
    if (NSWidth(safe) <= 0 || NSHeight(safe) <= 0) return @[];
    NSMutableArray *paths = [NSMutableArray array];
    const NSUInteger spans = 12;
    const CGFloat start = 0.28, step = 0.44 / spans;
    for (NSUInteger index = 0; index < count; index++) {
        CGFloat inset = index == 0 ? 5.5 : 10;
        NSBezierPath *arc = [NSBezierPath bezierPath];
        for (NSUInteger span = 0; span < spans; span++) {
            YSResizeArcSample a = YSResizeArcSampleAt(edge, extent, inset, start + span * step);
            YSResizeArcSample b = YSResizeArcSampleAt(edge, extent, inset, start + (span + 1) * step);
            NSPoint p[] = {a.point,
                NSMakePoint(a.point.x + a.derivative.x * step / 3, a.point.y + a.derivative.y * step / 3),
                NSMakePoint(b.point.x - b.derivative.x * step / 3, b.point.y - b.derivative.y * step / 3), b.point};
            // Cubic convex-hull containment plus the .6pt stroke radius proves
            // the entire rendered stroke fits, not just its sampled vertices.
            for (NSUInteger i = 0; i < 4; i++)
                if (!isfinite(p[i].x) || !isfinite(p[i].y) ||
                    p[i].x < NSMinX(safe) || p[i].x > NSMaxX(safe) ||
                    p[i].y < NSMinY(safe) || p[i].y > NSMaxY(safe)) return @[];
            if (span == 0) [arc moveToPoint:p[0]];
            [arc curveToPoint:p[3] controlPoint1:p[1] controlPoint2:p[2]];
        }
        arc.lineWidth = 1.2;
        arc.lineCapStyle = NSLineCapStyleRound;
        [paths addObject:arc];
    }
    return paths;
}

static inline void YSDrawResizeArcs(NSRect bounds, CGFloat cornerRadius, NSUInteger count) {
    [[NSColor colorWithWhite:1 alpha:0.64] setStroke];
    for (NSBezierPath *path in YSResizeArcPaths(bounds, cornerRadius, count)) [path stroke];
}

// Shared, original line icon for the quick-capture save action.
static inline NSImage *YSFloppyDiskImage(void) {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(16, 16) flipped:YES drawingHandler:^BOOL(NSRect rect) {
        [[NSColor blackColor] setStroke];
        NSBezierPath *outline = [NSBezierPath bezierPath];
        [outline moveToPoint:NSMakePoint(2.5, 1.7)];
        [outline lineToPoint:NSMakePoint(11.2, 1.7)];
        [outline lineToPoint:NSMakePoint(14.3, 4.8)];
        [outline lineToPoint:NSMakePoint(14.3, 13.5)];
        [outline curveToPoint:NSMakePoint(13.5, 14.3) controlPoint1:NSMakePoint(14.3, 14.1) controlPoint2:NSMakePoint(14.1, 14.3)];
        [outline lineToPoint:NSMakePoint(2.5, 14.3)];
        [outline curveToPoint:NSMakePoint(1.7, 13.5) controlPoint1:NSMakePoint(1.9, 14.3) controlPoint2:NSMakePoint(1.7, 14.1)];
        [outline lineToPoint:NSMakePoint(1.7, 2.5)];
        [outline curveToPoint:NSMakePoint(2.5, 1.7) controlPoint1:NSMakePoint(1.7, 1.9) controlPoint2:NSMakePoint(1.9, 1.7)];
        [outline closePath];
        outline.lineWidth = 1.15;
        outline.lineJoinStyle = NSLineJoinStyleRound;
        [outline stroke];
        NSBezierPath *label = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(4.1, 8.2, 7.8, 6.1) xRadius:0.7 yRadius:0.7];
        label.lineWidth = 1.05;
        [label stroke];
        NSBezierPath *slot = [NSBezierPath bezierPath];
        [slot moveToPoint:NSMakePoint(5, 1.8)]; [slot lineToPoint:NSMakePoint(5, 5.3)];
        [slot lineToPoint:NSMakePoint(10, 5.3)]; [slot lineToPoint:NSMakePoint(10, 1.8)];
        slot.lineWidth = 1.05;
        slot.lineJoinStyle = NSLineJoinStyleRound;
        [slot stroke];
        return YES;
    }];
    image.template = YES;
    return image;
}

