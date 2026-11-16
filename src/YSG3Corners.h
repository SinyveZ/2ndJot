#ifndef YS_G3_CORNERS_H
#define YS_G3_CORNERS_H

#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#include <float.h>
#include <math.h>

// The ideal unit corner is a single quintic Bezier, with control points
// (0,0), (.2,0), (1,0), (1,0), (1,.8), (1,1). Its endpoint speeds are 1;
// D2 and D3 are tangent there, so kappa = d(kappa)/ds = 0 at either end.
// Thus the IDEAL contour joins straight edges with geometric continuity G3.
// Core Graphics/AppKit only receive cubics: those are subpixel approximations,
// not an assertion of exact G3 for the individual rendered cubic joins.
typedef struct { NSPoint point, d1, d2, d3; } YSG3CornerJet;

// Finite t is clamped to [0,1]; nonfinite t selects the initial endpoint.
static inline YSG3CornerJet YSG3EvaluateCorner(CGFloat t) {
    t = isfinite(t) ? fmin(1, fmax(0, t)) : 0;
    CGFloat u = 1 - t, tt = t * t, uu = u * u;
    // The expanded x polynomial avoids cancellation close to t = 0.
    CGFloat x = t <= 0.5 ? t * (1 + t * (6 + t * (-14 + t * (11 - 3 * t))))
                           : 1 - uu * uu * (4 - 3 * u);
    return (YSG3CornerJet){
        NSMakePoint(x, tt * tt * (4 - 3 * t)),
        NSMakePoint(uu * u * (16 - 15 * u), tt * t * (16 - 15 * t)),
        NSMakePoint(12 * uu * (5 * u - 4), 12 * tt * (4 - 5 * t)),
        NSMakePoint(12 * u * (8 - 15 * u), 12 * t * (8 - 15 * t))
    };
}

// Private implementation uses only local state; no window, graphics context,
// preferences, or NSApplication is needed. The 0.002pt Bezier hull budget
// leaves 0.001pt for arithmetic/coordinate rounding (total <= 0.003pt).
// Rectangles with nonpositive dimensions, nonfinite/overflowed coordinates,
// or coordinates too large to support that absolute precision are empty.
static inline CGFloat YSG3PrivatePrecisionAllowance(CGFloat magnitude) {
    return 2048 * DBL_EPSILON * fmax(1, magnitude);
}

static inline BOOL YSG3PrivateRectIsUsable(NSRect rect) {
    CGFloat x = rect.origin.x, y = rect.origin.y;
    CGFloat w = rect.size.width, h = rect.size.height;
    if (!isfinite(x) || !isfinite(y) || !isfinite(w) || !isfinite(h) || w <= 0 || h <= 0)
        return NO;
    CGFloat maxX = x + w, maxY = y + h;
    if (!isfinite(maxX) || !isfinite(maxY) || maxX <= x || maxY <= y) return NO;
    CGFloat magnitude = fmax(fmax(fabs(x), fabs(maxX)), fmax(fabs(y), fabs(maxY)));
    return YSG3PrivatePrecisionAllowance(magnitude) <= 0.001;
}

// At t=1/2, (x,y)=(27/32,5/32). The 45-degree inset from a
// square corner is therefore 5*extent/32, matching r*(1-1/sqrt(2)).
// Negative/nonfinite radii mean square corners. Negative-sized rects are
// rejected, not standardized. Clamp BEFORE multiplying to avoid overflow.
static inline CGFloat YSG3CornerExtent(NSRect rect, CGFloat nominalRadius) {
    if (!YSG3PrivateRectIsUsable(rect) || !isfinite(nominalRadius) || nominalRadius <= 0)
        return 0;
    const CGFloat factor = (32.0 / 5.0) * (1 - 1 / sqrt(2.0));
    CGFloat limit = fmin(rect.size.width, rect.size.height) / 2;
    return nominalRadius >= limit / factor ? limit : nominalRadius * factor;
}

typedef struct {
    NSPoint origin, xStep, yStep;
    CGFloat minX, minY, maxX, maxY, scale;
} YSG3PrivateTransform;

static inline NSPoint YSG3PrivateAdd(NSPoint a, NSPoint b) {
    return NSMakePoint(a.x + b.x, a.y + b.y);
}
static inline NSPoint YSG3PrivateSubtract(NSPoint a, NSPoint b) {
    return NSMakePoint(a.x - b.x, a.y - b.y);
}
static inline NSPoint YSG3PrivateMultiply(NSPoint a, CGFloat s) {
    return NSMakePoint(a.x * s, a.y * s);
}
static inline CGFloat YSG3PrivateCross(NSPoint a, NSPoint b) {
    return a.x * b.y - a.y * b.x;
}

static inline BOOL YSG3PrivateMakeTransform(NSPoint origin, NSPoint xStep, NSPoint yStep,
                                           YSG3PrivateTransform *result) {
    NSPoint vertices[] = {origin, YSG3PrivateAdd(origin, xStep),
                         YSG3PrivateAdd(origin, yStep),
                         YSG3PrivateAdd(YSG3PrivateAdd(origin, xStep), yStep)};
    CGFloat minX = origin.x, minY = origin.y, maxX = origin.x, maxY = origin.y;
    for (NSUInteger i = 0; i < 4; i++) {
        if (!isfinite(vertices[i].x) || !isfinite(vertices[i].y)) return NO;
        minX = fmin(minX, vertices[i].x); maxX = fmax(maxX, vertices[i].x);
        minY = fmin(minY, vertices[i].y); maxY = fmax(maxY, vertices[i].y);
    }
    CGFloat magnitude = fmax(fmax(fabs(minX), fabs(maxX)), fmax(fabs(minY), fabs(maxY)));
    if (YSG3PrivatePrecisionAllowance(magnitude) > 0.001) return NO;
    // sqrt(||A||_1 * ||A||_infinity) bounds the Euclidean operator norm.
    // It is exactly extent for the orthogonal axis-aligned rectangle corners.
    CGFloat rowNorm = fmax(fabs(xStep.x) + fabs(yStep.x), fabs(xStep.y) + fabs(yStep.y));
    CGFloat columnNorm = fmax(fabs(xStep.x) + fabs(xStep.y), fabs(yStep.x) + fabs(yStep.y));
    CGFloat scale = sqrt(rowNorm) * sqrt(columnNorm);
    if (!isfinite(scale) || scale <= 0) return NO;
    *result = (YSG3PrivateTransform){origin, xStep, yStep, minX, minY, maxX, maxY, scale};
    return YES;
}

static inline NSPoint YSG3PrivateMap(NSPoint p, YSG3PrivateTransform transform) {
    CGFloat x = transform.origin.x + transform.xStep.x * p.x + transform.yStep.x * p.y;
    CGFloat y = transform.origin.y + transform.xStep.y * p.x + transform.yStep.y * p.y;
    // Only removes floating-point edge overshoot; all controls already lie in
    // the unit square. This also bounds the actual emitted control polygon.
    return NSMakePoint(fmin(transform.maxX, fmax(transform.minX, x)),
                       fmin(transform.maxY, fmax(transform.minY, y)));
}

static inline void YSG3PrivateSplit(const NSPoint p[6], NSPoint left[6], NSPoint right[6]) {
    NSPoint row[6];
    for (NSUInteger i = 0; i < 6; i++) row[i] = p[i];
    left[0] = row[0]; right[5] = row[5];
    for (NSUInteger level = 1; level < 6; level++) {
        for (NSUInteger i = 0; i < 6 - level; i++)
            row[i] = YSG3PrivateAdd(YSG3PrivateMultiply(row[i], 0.5),
                                   YSG3PrivateMultiply(row[i + 1], 0.5));
        left[level] = row[0]; right[5 - level] = row[5 - level];
    }
}

static inline CGFloat YSG3PrivateCubic(const NSPoint p[6], NSPoint q[4]) {
    NSPoint a = YSG3PrivateMultiply(YSG3PrivateSubtract(p[1], p[0]), 5.0 / 3.0);
    NSPoint b = YSG3PrivateMultiply(YSG3PrivateSubtract(p[5], p[4]), 5.0 / 3.0);
    NSPoint chord = YSG3PrivateSubtract(p[5], p[0]);
    CGFloat ab = YSG3PrivateCross(a, b);
    // A raw Hermite fit to t^4 undershoots at the straight-edge endpoint.
    // Limit each handle to the intersection of the two endpoint tangents.
    // This preserves tangent directions and gives a convex, monotone polygon.
    if (ab > 0) {
        CGFloat aLimit = fmin(1, fmax(0, YSG3PrivateCross(chord, b) / ab));
        CGFloat bLimit = fmin(1, fmax(0, YSG3PrivateCross(a, chord) / ab));
        a = YSG3PrivateMultiply(a, aLimit); b = YSG3PrivateMultiply(b, bLimit);
    }
    CGFloat scale = 1;
    if (a.x + b.x > chord.x) scale = fmin(scale, chord.x / (a.x + b.x));
    if (a.y + b.y > chord.y) scale = fmin(scale, chord.y / (a.y + b.y));
    q[0] = p[0]; q[3] = p[5];
    q[1] = YSG3PrivateAdd(p[0], YSG3PrivateMultiply(a, scale));
    q[2] = YSG3PrivateSubtract(p[5], YSG3PrivateMultiply(b, scale));
    // Clamp roundoff only, after tangent limiting. Recheck the error below.
    q[1].x = fmin(p[5].x, fmax(p[0].x, q[1].x));
    q[1].y = fmin(p[5].y, fmax(p[0].y, q[1].y));
    q[2].x = fmin(p[5].x, fmax(q[1].x, q[2].x));
    q[2].y = fmin(p[5].y, fmax(q[1].y, q[2].y));
    // Elevate the ACTUAL candidate cubic twice, to degree five. The norm of
    // every difference control point bounds the same-parameter error for the
    // whole interval, hence also bounds the contour's Hausdorff distance.
    NSPoint degree4[5], degree5[6];
    degree4[0] = q[0]; degree4[4] = q[3];
    for (NSUInteger i = 1; i < 4; i++)
        degree4[i] = YSG3PrivateAdd(YSG3PrivateMultiply(q[i - 1], i / 4.0),
                                   YSG3PrivateMultiply(q[i], 1 - i / 4.0));
    degree5[0] = degree4[0]; degree5[5] = degree4[4];
    for (NSUInteger i = 1; i < 5; i++)
        degree5[i] = YSG3PrivateAdd(YSG3PrivateMultiply(degree4[i - 1], i / 5.0),
                                   YSG3PrivateMultiply(degree4[i], 1 - i / 5.0));
    CGFloat bound = 0;
    for (NSUInteger i = 0; i < 6; i++)
        bound = fmax(bound, hypot(degree5[i].x - p[i].x, degree5[i].y - p[i].y));
    return bound;
}

static inline BOOL YSG3PrivateAppendHalf(CGMutablePathRef path, const NSPoint p[6],
                                        YSG3PrivateTransform transform, BOOL reflected,
                                        NSUInteger depth) {
    NSPoint q[4];
    CGFloat bound = YSG3PrivateCubic(p, q);
    if (bound * transform.scale <= 0.002) {
        NSPoint mapped[4];
        for (NSUInteger i = 0; i < 4; i++) {
            NSPoint v = reflected ? NSMakePoint(1 - q[3 - i].y, 1 - q[3 - i].x) : q[i];
            mapped[i] = YSG3PrivateMap(v, transform);
        }
        CGPathAddCurveToPoint(path, NULL, mapped[1].x, mapped[1].y, mapped[2].x, mapped[2].y,
                             mapped[3].x, mapped[3].y);
        return YES;
    }
    // Never silently emit an unbounded approximation after a recursion cap.
    if (depth >= 48 || !isfinite(bound)) return NO;
    NSPoint left[6], right[6];
    YSG3PrivateSplit(p, left, right);
    return reflected
        ? (YSG3PrivateAppendHalf(path, right, transform, YES, depth + 1) &&
           YSG3PrivateAppendHalf(path, left, transform, YES, depth + 1))
        : (YSG3PrivateAppendHalf(path, left, transform, NO, depth + 1) &&
           YSG3PrivateAppendHalf(path, right, transform, NO, depth + 1));
}

static inline BOOL YSG3PrivateAppendCorner(CGMutablePathRef path, YSG3PrivateTransform transform) {
    const NSPoint unit[6] = {{0, 0}, {0.2, 0}, {1, 0}, {1, 0}, {1, 0.8}, {1, 1}};
    NSPoint left[6], right[6];
    YSG3PrivateSplit(unit, left, right);
    // Generate both halves from the SAME net to preserve reflection symmetry
    // even when coordinates near 1 have less floating-point resolution.
    return YSG3PrivateAppendHalf(path, left, transform, NO, 0) &&
           YSG3PrivateAppendHalf(path, left, transform, YES, 0);
}

// Always returns a non-NULL retained path, including an empty path for invalid
// or precision-degenerate input. Caller owns it and must CGPathRelease it.
static inline CGPathRef YSG3CreateRoundedRectPath(CGRect rect, CGFloat nominalRadius) CF_RETURNS_RETAINED;
static inline CGPathRef YSG3CreateRoundedRectPath(CGRect rect, CGFloat nominalRadius) {
    CGMutablePathRef path = CGPathCreateMutable();
    if (!YSG3PrivateRectIsUsable(NSRectFromCGRect(rect))) return path;
    CGFloat extent = YSG3CornerExtent(NSRectFromCGRect(rect), nominalRadius);
    if (extent <= 0) { CGPathAddRect(path, NULL, rect); return path; }
    CGFloat x0 = CGRectGetMinX(rect), x1 = CGRectGetMaxX(rect);
    CGFloat y0 = CGRectGetMinY(rect), y1 = CGRectGetMaxY(rect);
    NSPoint origins[] = {{x1 - extent, y0}, {x1, y1 - extent},
                         {x0 + extent, y1}, {x0, y0 + extent}};
    NSPoint xSteps[] = {{extent, 0}, {0, extent}, {-extent, 0}, {0, -extent}};
    NSPoint ySteps[] = {{0, extent}, {-extent, 0}, {0, -extent}, {extent, 0}};
    CGPathMoveToPoint(path, NULL, x0 + extent, y0);
    for (NSUInteger i = 0; i < 4; i++) {
        YSG3PrivateTransform transform;
        if (!YSG3PrivateMakeTransform(origins[i], xSteps[i], ySteps[i], &transform)) {
            CGPathRelease(path); return CGPathCreateMutable();
        }
        // Rect edge bounds also remove addition/subtraction rounding at a seam.
        transform.minX = fmax(transform.minX, x0); transform.maxX = fmin(transform.maxX, x1);
        transform.minY = fmax(transform.minY, y0); transform.maxY = fmin(transform.maxY, y1);
        NSPoint start = YSG3PrivateMap(NSZeroPoint, transform);
        CGPoint current = CGPathGetCurrentPoint(path);
        if (current.x != start.x || current.y != start.y)
            CGPathAddLineToPoint(path, NULL, start.x, start.y);
        if (!YSG3PrivateAppendCorner(path, transform)) {
            CGPathRelease(path); return CGPathCreateMutable();
        }
    }
    CGPathCloseSubpath(path);
    return path;
}

static inline NSBezierPath *YSG3PrivateBezierPath(CGPathRef cgPath) {
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGPathApplyWithBlock(cgPath, ^(const CGPathElement *element) {
        const CGPoint *p = element->points;
        switch (element->type) {
            case kCGPathElementMoveToPoint: [path moveToPoint:NSPointFromCGPoint(p[0])]; break;
            case kCGPathElementAddLineToPoint: [path lineToPoint:NSPointFromCGPoint(p[0])]; break;
            case kCGPathElementAddCurveToPoint:
                [path curveToPoint:NSPointFromCGPoint(p[2]) controlPoint1:NSPointFromCGPoint(p[0])
                    controlPoint2:NSPointFromCGPoint(p[1])]; break;
            case kCGPathElementCloseSubpath: [path closePath]; break;
            case kCGPathElementAddQuadCurveToPoint: break; // Not emitted by this module.
        }
    });
    return path;
}

static inline NSBezierPath *YSG3RoundedRect(NSRect rect, CGFloat nominalRadius) {
    CGPathRef cgPath = YSG3CreateRoundedRectPath(NSRectToCGRect(rect), nominalRadius);
    NSBezierPath *path = YSG3PrivateBezierPath(cgPath);
    CGPathRelease(cgPath);
    return path;
}

// Open quarter contour. extent is the ACTUAL unit-corner scale, NOT a nominal
// circular radius. start + extent*(axisX*x(t) + axisY*y(t)); arbitrary finite
// axes are supported with the same <=0.003pt absolute error budget. Invalid,
// nonpositive, zero-transform, or precision-degenerate input returns empty.
static inline NSBezierPath *YSG3QuarterCorner(NSPoint start, NSPoint axisX, NSPoint axisY,
                                            CGFloat extent) {
    if (!isfinite(extent) || extent <= 0 ||
        !isfinite(axisX.x) || !isfinite(axisX.y) || !isfinite(axisY.x) || !isfinite(axisY.y))
        return [NSBezierPath bezierPath];
    YSG3PrivateTransform transform;
    if (!YSG3PrivateMakeTransform(start, YSG3PrivateMultiply(axisX, extent),
                                YSG3PrivateMultiply(axisY, extent), &transform))
        return [NSBezierPath bezierPath];
    CGMutablePathRef cgPath = CGPathCreateMutable();
    CGPathMoveToPoint(cgPath, NULL, start.x, start.y);
    BOOL okay = YSG3PrivateAppendCorner(cgPath, transform);
    NSBezierPath *path = okay ? YSG3PrivateBezierPath(cgPath) : [NSBezierPath bezierPath];
    CGPathRelease(cgPath);
    return path;
}

#endif // YS_G3_CORNERS_H
