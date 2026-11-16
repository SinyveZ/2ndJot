#import <Cocoa/Cocoa.h>
#import "../src/YSG3Corners.h"
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

// Independent oracle: long-double Bernstein evaluation/differentiation of the
// ORIGINAL quintic control polygon. No production private helper is used here.
typedef struct { long double x, y; } Vec;
typedef struct { Vec p[4]; } Cubic;
typedef struct { Vec origin, xStep, yStep; } Frame;
typedef struct { CGPathElementType type; CGPoint p[3]; } Element;
static const Vec Unit[6] = {{0,0}, {0.2L,0}, {1,0}, {1,0}, {1,0.8L}, {1,1}};
static unsigned long long Assertions, Segments, PathCases;
static unsigned Failures;
static long double MaxHullError, MaxSampleError;

static void Expect(BOOL condition, const char *format, ...) {
    Assertions++;
    if (condition) return;
    Failures++;
    if (Failures <= 24) {
        va_list args; va_start(args, format);
        fputs("FAIL: ", stderr); vfprintf(stderr, format, args); fputc('\n', stderr);
        va_end(args);
    }
}
static Vec V(long double x, long double y) { return (Vec){x,y}; }
static Vec FromPoint(NSPoint p) { return V(p.x,p.y); }
static Vec Add(Vec a, Vec b) { return V(a.x+b.x,a.y+b.y); }
static Vec Sub(Vec a, Vec b) { return V(a.x-b.x,a.y-b.y); }
static Vec Mul(Vec a, long double s) { return V(a.x*s,a.y*s); }
static long double Cross(Vec a, Vec b) { return a.x*b.y-a.y*b.x; }
static long double Dot(Vec a, Vec b) { return a.x*b.x+a.y*b.y; }
static long double Norm(Vec a) { return hypotl(a.x,a.y); }
static Vec Lerp(Vec a, Vec b, long double t) { return Add(Mul(a,1-t),Mul(b,t)); }
static long double Magnitude(Vec a) { return fmaxl(fabsl(a.x),fabsl(a.y)); }
static Vec Map(Vec p, Frame f) { return Add(f.origin,Add(Mul(f.xStep,p.x),Mul(f.yStep,p.y))); }
static Vec Inverse(Vec p, Frame f) {
    // Normalize BEFORE multiplying: on arm64 long double is also binary64,
    // so a determinant formed from DBL_MIN-sized axes would underflow.
    long double scale=fmaxl(Magnitude(f.xStep),Magnitude(f.yStep));
    Vec a=V(f.xStep.x/scale,f.xStep.y/scale),b=V(f.yStep.x/scale,f.yStep.y/scale);
    Vec delta=Sub(p,f.origin),d=V(delta.x/scale,delta.y/scale);
    long double det=Cross(a,b);
    return V(Cross(d,b)/det,Cross(a,d)/det);
}
static void Split(const Vec *p, unsigned degree, long double t, Vec *left, Vec *right) {
    Vec row[8]; memcpy(row,p,(degree+1)*sizeof(Vec));
    left[0]=row[0]; right[degree]=row[degree];
    for (unsigned level=1;level<=degree;level++) {
        for (unsigned i=0;i<=degree-level;i++) row[i]=Lerp(row[i],row[i+1],t);
        left[level]=row[0]; right[degree-level]=row[degree-level];
    }
}
static Vec Evaluate(const Vec *p, unsigned degree, long double t) {
    Vec left[8],right[8]; Split(p,degree,t,left,right); return left[degree];
}
static void Derivative(const Vec *p, unsigned degree, Vec *result) {
    for (unsigned i=0;i<degree;i++) result[i]=Mul(Sub(p[i+1],p[i]),degree);
}
static void Restrict(long double a, long double b, Vec result[6]) {
    Vec left[6],right[6],unused[6];
    Split(Unit,5,b,left,unused);
    Split(left,5,b>0 ? a/b : 0,unused,right);
    memcpy(result,right,6*sizeof(Vec));
}
static long double Choose(unsigned n,unsigned k) {
    if (k>n) return 0;
    long double r=1;
    for (unsigned i=1;i<=k;i++) r=r*(n+1-i)/i;
    return r;
}
static long double HullBound(Cubic cubic, const Vec exact[6]) {
    long double bound=0;
    // Direct combinatorial degree elevation, independent of the production
    // routine's two successive degree-elevation passes.
    for (unsigned k=0;k<6;k++) {
        Vec elevated=V(0,0);
        for (unsigned i=0;i<4;i++) {
            if (k>=i && k-i<=2)
                elevated=Add(elevated,Mul(cubic.p[i],Choose(3,i)*Choose(2,k-i)/Choose(5,k)));
        }
        bound=fmaxl(bound,Norm(Sub(elevated,exact[k])));
    }
    return bound;
}
static long double RecoverParameter(Vec point) {
    BOOL useX=point.x<=27.0L/32;
    long double target=useX ? point.x : point.y,lo=0,hi=1;
    for (unsigned i=0;i<80;i++) {
        long double mid=(lo+hi)/2;
        Vec p=Evaluate(Unit,5,mid);
        if ((useX ? p.x : p.y)<target) lo=mid; else hi=mid;
    }
    return (lo+hi)/2;
}
static long double Curvature(Vec d1,Vec d2) {
    return Cross(d1,d2)/powl(Norm(d1),3);
}
static long double CurvatureDerivative(Vec d1,Vec d2,Vec d3) {
    long double v2=Dot(d1,d1);
    return Cross(d1,d3)/(v2*v2)-3*Cross(d1,d2)*Dot(d1,d2)/(v2*v2*v2);
}

static void CheckIdealGeometry(void) {
    unsigned failuresBefore=Failures;
    Vec d1[5],d2[4],d3[3];
    Derivative(Unit,5,d1); Derivative(d1,4,d2); Derivative(d2,3,d3);
    for (unsigned endpoint=0;endpoint<=1;endpoint++) {
        YSG3CornerJet j=YSG3EvaluateCorner(endpoint);
        Vec a=FromPoint(j.d1),b=FromPoint(j.d2),c=FromPoint(j.d3);
        Expect(Norm(a)>0.99L,"endpoint %u must be regular",endpoint);
        Expect(fabsl(Curvature(a,b))<1e-14L,"endpoint %u kappa",endpoint);
        Expect(fabsl(CurvatureDerivative(a,b,c))<1e-14L,"endpoint %u d(kappa)/ds",endpoint);
        Vec oracleA=Evaluate(d1,4,endpoint),oracleB=Evaluate(d2,3,endpoint),oracleC=Evaluate(d3,2,endpoint);
        Expect(Norm(Sub(a,oracleA))<1e-14L && Norm(Sub(b,oracleB))<1e-13L &&
               Norm(Sub(c,oracleC))<1e-12L,"endpoint %u derivatives from quintic polygon",endpoint);
    }
    // Global monotonicity certificate: both derivative Bernstein nets have
    // nonnegative coefficients, with strictly positive basis terms inside.
    for (unsigned i=0;i<5;i++) Expect(d1[i].x>=0 && d1[i].y>=0,"monotonicity certificate %u",i);
    // Global regularity certificate: dx >= 1 on the first half, dy >= 1 on
    // the second, using the convex hull of restricted derivative controls.
    Vec first[5],second[5]; Split(d1,4,0.5L,first,second);
    for (unsigned i=0;i<5;i++)
        Expect(first[i].x>=1-1e-15L && second[i].y>=1-1e-15L,"speed certificate %u",i);
    // Convexity certificate for cross(C',C''): multiply Bernstein nets.
    for (unsigned k=0;k<8;k++) {
        long double coefficient=0;
        for (unsigned i=0;i<5;i++) for (unsigned j=0;j<4;j++) if (i+j==k)
            coefficient+=Cross(d1[i],d2[j])*Choose(4,i)*Choose(3,j)/Choose(7,k);
        Expect(coefficient>=-1e-14L,"convexity Bernstein coefficient %u = %.18Lg",k,coefficient);
        if (k>=2 && k<=5) Expect(coefficient>0,"strict interior convexity %u",k);
    }
    for (unsigned i=0;i<=10000;i++) {
        long double t=i/10000.0L;
        YSG3CornerJet j=YSG3EvaluateCorner((CGFloat)t);
        Vec expected[]={Evaluate(Unit,5,t),Evaluate(d1,4,t),Evaluate(d2,3,t),Evaluate(d3,2,t)};
        Vec actual[]={FromPoint(j.point),FromPoint(j.d1),FromPoint(j.d2),FromPoint(j.d3)};
        for (unsigned n=0;n<4;n++)
            Expect(Norm(Sub(actual[n],expected[n]))<3e-12L,"analytic jet t=%.8Lg order %u",t,n);
        Vec p=actual[0],a=actual[1],b=actual[2];
        Expect(p.x>=0 && p.x<=1 && p.y>=0 && p.y<=1,"ideal corner in unit square t=%.8Lg",t);
        Expect(a.x>=0 && a.y>=0 && Norm(a)>=1-1e-12L,"positive speed and monotonicity t=%.8Lg",t);
        long double certificate=12*t*t*(1-t)*(1-t)*(4+35*t*(1-t));
        Expect(fabsl(Cross(a,b)-certificate)<2e-12L,"convexity factorization t=%.8Lg",t);
        YSG3CornerJet reflected=YSG3EvaluateCorner((CGFloat)(1-t));
        Expect(Norm(Sub(p,V(1-reflected.point.y,1-reflected.point.x)))<2e-14L,"unit diagonal symmetry");
    }
    for (unsigned i=1;i<=6;i++) {
        CGFloat t=pow(10,-(double)i);
        YSG3CornerJet j=YSG3EvaluateCorner(t);
        Expect(fabsl(Curvature(FromPoint(j.d1),FromPoint(j.d2)))<=49*t*t,"endpoint kappa O(t^2)");
        Expect(fabsl(CurvatureDerivative(FromPoint(j.d1),FromPoint(j.d2),FromPoint(j.d3)))<=100*t,
               "endpoint d(kappa)/ds O(t)");
    }
    CGFloat inputs[]={-100,2,NAN,INFINITY,-INFINITY};
    for (unsigned i=0;i<sizeof(inputs)/sizeof(inputs[0]);i++) {
        YSG3CornerJet j=YSG3EvaluateCorner(inputs[i]);
        NSPoint expected=isfinite(inputs[i]) && inputs[i]>1 ? NSMakePoint(1,1) : NSZeroPoint;
        Expect(Norm(Sub(FromPoint(j.point),FromPoint(expected)))==0,"t input sanitation %u",i);
    }
    NSRect rect=NSMakeRect(0,0,1000,1000);
    long double e=YSG3CornerExtent(rect,18);
    Vec midpoint=Evaluate(Unit,5,0.5L);
    Expect(fabsl(e*midpoint.y-18*(1-1/sqrtl(2)))<1e-13L,"nominal radius preserves 45-degree inset");
    Expect(fabsl(midpoint.x-27.0L/32)<1e-17L && fabsl(midpoint.y-5.0L/32)<1e-17L,"independent midpoint");
    printf("%s ideal G3 endpoints; analytic jets; global regularity/monotonicity/convexity certificates\n",
           Failures==failuresBefore ? "PASS" : "FAIL");
}

static NSMutableData *Elements(CGPathRef path) {
    NSMutableData *data=[NSMutableData data];
    CGPathApplyWithBlock(path, ^(const CGPathElement *item) {
        Element e={0}; e.type=item->type;
        unsigned count=e.type==kCGPathElementAddCurveToPoint ? 3 :
                       e.type==kCGPathElementAddQuadCurveToPoint ? 2 :
                       e.type==kCGPathElementCloseSubpath ? 0 : 1;
        for (unsigned i=0;i<count;i++) e.p[i]=item->points[i];
        [data appendBytes:&e length:sizeof(e)];
    });
    return data;
}
static NSMutableData *Cubics(NSMutableData *elements) {
    NSMutableData *data=[NSMutableData data];
    const Element *items=elements.bytes;
    Vec current=V(0,0);
    for (NSUInteger i=0;i<elements.length/sizeof(Element);i++) {
        if (items[i].type==kCGPathElementAddCurveToPoint) {
            Cubic cubic={{current,FromPoint(items[i].p[0]),FromPoint(items[i].p[1]),FromPoint(items[i].p[2])}};
            [data appendBytes:&cubic length:sizeof(cubic)]; current=cubic.p[3];
        } else if (items[i].type==kCGPathElementMoveToPoint || items[i].type==kCGPathElementAddLineToPoint)
            current=FromPoint(items[i].p[0]);
    }
    return data;
}
static void CompareBezier(NSBezierPath *bezier, NSMutableData *elements) {
    const Element *items=elements.bytes;
    NSUInteger count=elements.length/sizeof(Element);
    NSInteger meaningfulCount=bezier.elementCount;
    // AppKit automatically appends MoveTo(subpathStart) after closePath.
    // It changes no contour; normalize that platform representation only.
    if (count>0 && meaningfulCount==(NSInteger)count+1 && items[count-1].type==kCGPathElementCloseSubpath) {
        NSPoint points[3];
        NSBezierPathElement last=[bezier elementAtIndex:meaningfulCount-1 associatedPoints:points];
        if (last==NSBezierPathElementMoveTo && points[0].x==items[0].p[0].x && points[0].y==items[0].p[0].y)
            meaningfulCount--;
    }
    Expect(meaningfulCount==(NSInteger)count,"NSBezier/CGPath normalized element counts");
    if (meaningfulCount!=(NSInteger)count) return;
    for (NSUInteger i=0;i<count;i++) {
        NSPoint points[3]; NSBezierPathElement type=[bezier elementAtIndex:(NSInteger)i associatedPoints:points];
        NSUInteger n=0; CGPathElementType expected=kCGPathElementCloseSubpath;
        switch (type) {
            case NSBezierPathElementMoveTo: expected=kCGPathElementMoveToPoint; n=1; break;
            case NSBezierPathElementLineTo: expected=kCGPathElementAddLineToPoint; n=1; break;
            case NSBezierPathElementCurveTo: expected=kCGPathElementAddCurveToPoint; n=3; break;
            case NSBezierPathElementClosePath: break;
            default: Expect(NO,"unexpected NSBezier element"); break;
        }
        Expect(items[i].type==expected,"NSBezier/CGPath element type");
        for (NSUInteger j=0;j<n;j++)
            Expect(points[j].x==items[i].p[j].x && points[j].y==items[i].p[j].y,"identical NSBezier/CGPath controls");
    }
}

static void CertifyCorner(const Cubic *cubics,NSUInteger count,Frame frame,const char *label) {
    Expect(count>=2 && count%2==0,"%s has paired symmetric half corners",label);
    long double previous=0;
    long double magnitude=fmaxl(1,Magnitude(frame.origin)+Norm(frame.xStep)+Norm(frame.yStep));
    long double numericMargin=64*DBL_EPSILON*magnitude;
    for (NSUInteger i=0;i<count;i++) {
        Cubic q=cubics[i]; Segments++;
        Vec end=Inverse(q.p[3],frame);
        long double t=i+1==count ? 1 : i+1==count/2 ? 0.5L : RecoverParameter(end);
        Expect(t>previous && t<=1,"%s corner intervals cover [0,1] in order",label);
        Vec localExact[6],worldExact[6]; Restrict(previous,t,localExact);
        for (unsigned j=0;j<6;j++) worldExact[j]=Map(localExact[j],frame);
        long double bound=HullBound(q,worldExact);
        MaxHullError=fmaxl(MaxHullError,bound);
        Expect(bound<=0.003L,"%s emitted cubic hull error %.12Lgpt > .003pt (segment %lu/%lu)",
               label,bound,(unsigned long)i,(unsigned long)count);
        for (unsigned j=0;j<=8;j++) {
            long double s=j/8.0L;
            long double error=Norm(Sub(Evaluate(q.p,3,s),Evaluate(worldExact,5,s)));
            MaxSampleError=fmaxl(MaxSampleError,error);
            Expect(error<=bound+numericMargin,"%s sampled error covered by hull certificate",label);
        }
        // Check actual, world-space controls for monotonicity after undoing
        // the affine transform. Allow arithmetic roundoff, not visible loops.
        Vec local[4]; for (unsigned j=0;j<4;j++) local[j]=Inverse(q.p[j],frame);
        long double localMargin=numericMargin/fmaxl(1e-30L,fminl(Norm(frame.xStep),Norm(frame.yStep)));
        for (unsigned j=0;j<3;j++) {
            Expect(local[j+1].x>=local[j].x-localMargin && local[j+1].y>=local[j].y-localMargin,
                   "%s actual cubic monotone control polygon",label);
        }
        for (unsigned j=0;j<2;j++) {
            Vec a=Sub(local[j+1],local[j]),b=Sub(local[j+2],local[j+1]);
            Expect(Cross(a,b)>=-localMargin*(Norm(a)+Norm(b)+localMargin),"%s actual cubic convex polygon",label);
        }
        // The reversed reflected control sequence must coincide, including
        // adaptive partition choices, not only the four outer endpoints.
        Cubic opposite=cubics[count-1-i];
        for (unsigned j=0;j<4;j++) {
            Vec p=Inverse(opposite.p[3-j],frame);
            // Compare in unit coordinates. Mapping an inverse-rounding error
            // back through a different axis amplifies it on anisotropic frames
            // (our stress case has an axis ratio of one million).
            Expect(Norm(Sub(local[j],V(1-p.y,1-p.x)))<=localMargin*2,"%s diagonal symmetry",label);
        }
        previous=t;
    }
    Expect(previous==1,"%s final parameter is one",label);
}

static BOOL FiniteUsableRect(NSRect r) {
    if (!isfinite(r.origin.x) || !isfinite(r.origin.y) || !isfinite(r.size.width) || !isfinite(r.size.height) ||
        r.size.width<=0 || r.size.height<=0) return NO;
    CGFloat x1=r.origin.x+r.size.width,y1=r.origin.y+r.size.height;
    if (!isfinite(x1) || !isfinite(y1) || x1<=r.origin.x || y1<=r.origin.y) return NO;
    long double magnitude=fmaxl(fmaxl(fabsl(r.origin.x),fabsl(x1)),fmaxl(fabsl(r.origin.y),fabsl(y1)));
    return 2048*DBL_EPSILON*fmaxl(1,magnitude)<=0.001L;
}
static void CheckRect(NSRect rect,CGFloat radius,const char *label) {
    PathCases++;
    CGPathRef path=YSG3CreateRoundedRectPath(NSRectToCGRect(rect),radius);
    Expect(path!=NULL,"%s retained path must be non-NULL",label);
    if (!path) return;
    NSBezierPath *bezier=YSG3RoundedRect(rect,radius);
    NSMutableData *elements=Elements(path);
    CompareBezier(bezier,elements);
    CGFloat e=YSG3CornerExtent(rect,radius);
    if (!FiniteUsableRect(rect)) {
        Expect(CGPathIsEmpty(path) && bezier.empty && e==0,"%s invalid/precision-degenerate rect is empty",label);
        CGPathRelease(path); return;
    }
    Expect(!CGPathIsEmpty(path),"%s usable rect cannot be empty",label);
    CGFloat limit=fmin(rect.size.width,rect.size.height)/2;
    long double expected=isfinite(radius) && radius>0 ?
        fminl(limit,(long double)radius*(32.0L/5)*(1-1/sqrtl(2))) : 0;
    Expect(fabsl(e-expected)<=4e-15L*fmaxl(1,expected),"%s safe extent conversion/clamp",label);
    Expect(e>=0 && e<=limit,"%s extent cannot cross adjacent corners",label);
    const Element *items=elements.bytes; NSUInteger count=elements.length/sizeof(Element);
    Expect(count>0 && items[0].type==kCGPathElementMoveToPoint && items[count-1].type==kCGPathElementCloseSubpath,
           "%s one closed subpath",label);
    CGFloat x0=NSMinX(rect),x1=NSMaxX(rect),y0=NSMinY(rect),y1=NSMaxY(rect);
    NSUInteger moves=0,closes=0;
    for (NSUInteger i=0;i<count;i++) {
        if (items[i].type==kCGPathElementMoveToPoint) moves++;
        if (items[i].type==kCGPathElementCloseSubpath) closes++;
        unsigned n=items[i].type==kCGPathElementAddCurveToPoint ? 3 : items[i].type==kCGPathElementCloseSubpath ? 0 : 1;
        for (unsigned j=0;j<n;j++) {
            CGPoint p=items[i].p[j];
            Expect(isfinite(p.x) && isfinite(p.y) && p.x>=x0 && p.x<=x1 && p.y>=y0 && p.y<=y1,
                   "%s ALL emitted controls strictly within rectangle",label);
        }
    }
    Expect(moves==1 && closes==1,"%s no disconnected corner subpaths",label);
    CGRect bounds=CGPathGetBoundingBox(path);
    Expect(bounds.origin.x==x0 && bounds.origin.y==y0 && CGRectGetMaxX(bounds)==x1 && CGRectGetMaxY(bounds)==y1,
           "%s output bounds equal rectangle",label);
    NSMutableData *data=Cubics(elements); const Cubic *cubics=data.bytes;
    NSUInteger cubicCount=data.length/sizeof(Cubic);
    if (e<=0) Expect(cubicCount==0,"%s square-corner fallback",label);
    else {
        Expect(cubicCount>=8 && cubicCount%4==0,"%s four equal adaptive corner counts",label);
        if (cubicCount%4==0 && cubicCount>0) {
            NSUInteger n=cubicCount/4;
            Frame frames[]={
                {V(x1-e,y0),V(e,0),V(0,e)}, {V(x1,y1-e),V(0,e),V(-e,0)},
                {V(x0+e,y1),V(-e,0),V(0,-e)}, {V(x0,y0+e),V(0,-e),V(e,0)}
            };
            for (unsigned corner=0;corner<4;corner++) {
                CertifyCorner(cubics+corner*n,n,frames[corner],label);
                for (NSUInteger i=0;i<n;i++) for (unsigned j=0;j<4;j++) {
                    Vec actual=Inverse(cubics[corner*n+i].p[j],frames[corner]);
                    Vec first=Inverse(cubics[i].p[j],frames[0]);
                    long double margin=128*DBL_EPSILON*fmaxl(1,fmaxl(fabsl(x1),fabsl(y1)))/e;
                    Expect(Norm(Sub(actual,first))<=margin,"%s four-corner rotational symmetry",label);
                }
            }
            Vec start=FromPoint(items[0].p[0]),end=cubics[cubicCount-1].p[3];
            long double margin=32*DBL_EPSILON*fmaxl(1,fmaxl(fabsl(x1),fabsl(y1)));
            Expect(Norm(Sub(start,end))<=margin,"%s final corner closes without a diagonal seam",label);
        }
    }
    CGPathRelease(path);
}

static uint64_t RandomState=UINT64_C(0x4759436f726e6572);
static double Random01(void) {
    RandomState=RandomState*UINT64_C(6364136223846793005)+UINT64_C(1442695040888963407);
    return (double)(RandomState>>11)*0x1p-53;
}
static void CheckRectangles(void) {
    unsigned failuresBefore=Failures;
    const NSSize sizes[]={{480,154},{360,260},{36,36},{1,100},{100,0.125},{0.003,0.004},
                          {1e-9,2e-9},{1e6,2e6},{128,1024}};
    const CGFloat radii[]={-INFINITY,-DBL_MAX,-1,-0.0,0,DBL_TRUE_MIN,1e-10,0.1,0.5,1,7,12,18,36,72,DBL_MAX,NAN,INFINITY};
    for (unsigned i=0;i<sizeof(sizes)/sizeof(sizes[0]);i++) {
        for (unsigned j=0;j<sizeof(radii)/sizeof(radii[0]);j++) {
            char label[80]; snprintf(label,sizeof(label),"rect[%u] radius[%u]",i,j);
            NSRect r=NSMakeRect(i%2 ? -190.75 : 13.25,i%3 ? 52.125 : -27.5,sizes[i].width,sizes[i].height);
            CheckRect(r,radii[j],label);
        }
    }
    for (unsigned i=0;i<200;i++) {
        CGFloat w=pow(10,-2+7*Random01()),h=pow(10,-2+7*Random01());
        NSRect r=NSMakeRect(-1000+2000*Random01(),-1000+2000*Random01(),w,h);
        CGFloat radius=(i%4==0 ? DBL_MAX : fmin(w,h)*Random01()*1.5);
        char label[48]; snprintf(label,sizeof(label),"deterministic fuzz %u",i);
        CheckRect(r,radius,label);
    }
    NSRect stress[]={NSMakeRect(-1e9,-5e8,2e9,1e9),NSMakeRect(1e9,1e9,1,0.125),
                     NSMakeRect(0,0,DBL_MIN,DBL_MIN),NSMakeRect(0,0,DBL_TRUE_MIN,DBL_TRUE_MIN)};
    for (unsigned i=0;i<sizeof(stress)/sizeof(stress[0]);i++) CheckRect(stress[i],DBL_MAX,"finite stress");
    NSRect invalid[]={NSZeroRect,NSMakeRect(0,0,0,10),NSMakeRect(0,0,10,-1),NSMakeRect(0,0,-10,10),
                      NSMakeRect(NAN,0,10,10),NSMakeRect(0,INFINITY,10,10),NSMakeRect(0,0,NAN,10),
                      NSMakeRect(0,0,10,INFINITY),NSMakeRect(DBL_MAX,0,DBL_MAX,10),
                      NSMakeRect(0,0,DBL_MAX,DBL_MAX),NSMakeRect(1e12,0,100,100),
                      NSMakeRect(1e9,0,DBL_TRUE_MIN,10)};
    for (unsigned i=0;i<sizeof(invalid)/sizeof(invalid[0]);i++) CheckRect(invalid[i],18,"invalid rect");
    printf("%s rectangles: boundary hulls, symmetry, closure, radius overflow, degenerate/nonfinite inputs\n",
           Failures==failuresBefore ? "PASS" : "FAIL");
}

static NSMutableData *BezierElements(NSBezierPath *path) {
    NSMutableData *data=[NSMutableData data];
    for (NSInteger i=0;i<path.elementCount;i++) {
        Element item={0}; NSPoint p[3]; unsigned count=0;
        switch ([path elementAtIndex:i associatedPoints:p]) {
            case NSBezierPathElementMoveTo: item.type=kCGPathElementMoveToPoint; count=1; break;
            case NSBezierPathElementLineTo: item.type=kCGPathElementAddLineToPoint; count=1; break;
            case NSBezierPathElementCurveTo: item.type=kCGPathElementAddCurveToPoint; count=3; break;
            case NSBezierPathElementClosePath: item.type=kCGPathElementCloseSubpath; break;
            default: Expect(NO,"unexpected quarter path element"); break;
        }
        for (unsigned j=0;j<count;j++) item.p[j]=p[j];
        [data appendBytes:&item length:sizeof(item)];
    }
    return data;
}
static void CheckQuarters(void) {
    unsigned failuresBefore=Failures;
    struct { NSPoint start,x,y; CGFloat extent; } cases[]={
        {{100,80},{0,1},{-1,0},12},{{100,80},{0,1},{-1,0},7},
        {{-17,29},{1,0},{0,1},33.7412988073},{{100,80},{0,-1},{-1,0},12},
        {{-3,21},{1,0.25},{-0.4,1.75},400},{{0,0},{-2,1},{3,0.5},0.003},
        {{12,-32},{1e4,0},{0,1e-2},2}
    };
    for (unsigned i=0;i<sizeof(cases)/sizeof(cases[0]);i++) {
        NSBezierPath *path=YSG3QuarterCorner(cases[i].start,cases[i].x,cases[i].y,cases[i].extent);
        Expect(!path.empty,"quarter %u nonempty",i);
        NSMutableData *elements=BezierElements(path),*data=Cubics(elements);
        NSUInteger n=data.length/sizeof(Cubic); const Cubic *cubics=data.bytes;
        Frame f={FromPoint(cases[i].start),Mul(FromPoint(cases[i].x),cases[i].extent),
                                         Mul(FromPoint(cases[i].y),cases[i].extent)};
        char label[48]; snprintf(label,sizeof(label),"quarter transform %u",i);
        if (n>0) {
            CertifyCorner(cubics,n,f,label);
            Expect(Norm(Sub(cubics[0].p[0],f.origin))<1e-12L,"quarter initial point");
            Expect(Norm(Sub(cubics[n-1].p[3],Map(V(1,1),f)))<1e-10L,"quarter transformed endpoint");
            Vec first=Sub(cubics[0].p[1],cubics[0].p[0]);
            Vec last=Sub(cubics[n-1].p[3],cubics[n-1].p[2]);
            Expect(fabsl(Cross(first,f.xStep))<=1e-10L*fmaxl(1,Norm(first)*Norm(f.xStep)),"quarter starts along axisX");
            Expect(fabsl(Cross(last,f.yStep))<=1e-10L*fmaxl(1,Norm(last)*Norm(f.yStep)),"quarter ends along axisY");
        }
        const Element *items=elements.bytes;
        for (NSUInteger j=0;j<elements.length/sizeof(Element);j++)
            Expect(items[j].type!=kCGPathElementCloseSubpath,"quarter must remain open for stroke");
    }
    NSPoint start=NSMakePoint(100,80),x=NSMakePoint(0,1),y=NSMakePoint(-1,0);
    CGFloat invalidExtents[]={0,-1,NAN,INFINITY,-INFINITY,DBL_MAX};
    for (unsigned i=0;i<sizeof(invalidExtents)/sizeof(invalidExtents[0]);i++)
        Expect(YSG3QuarterCorner(start,x,y,invalidExtents[i]).empty,"invalid quarter extent %u",i);
    Expect(YSG3QuarterCorner(NSMakePoint(NAN,0),x,y,12).empty,"invalid quarter start");
    Expect(YSG3QuarterCorner(start,NSMakePoint(INFINITY,0),y,12).empty,"invalid quarter axis");
    Expect(YSG3QuarterCorner(start,NSZeroPoint,NSZeroPoint,12).empty,"zero quarter transform");
    Expect(YSG3QuarterCorner(NSMakePoint(1e12,0),x,y,12).empty,"precision-degenerate quarter");
    // Rank-one transforms are well-defined degenerate open contours, and safe.
    Expect(!YSG3QuarterCorner(start,NSZeroPoint,y,12).empty,"rank-one quarter remains usable");
    printf("%s quarter strokes: r12/r7, flipped axes, skew/anisotropic transforms, invalid inputs\n",
           Failures==failuresBefore ? "PASS" : "FAIL");
}

static void CheckOracleSensitivity(void) {
    unsigned failuresBefore=Failures;
    Vec exact[6]; Restrict(0,0.5L,exact);
    Cubic bad={{exact[0],V(0.1L,-0.03L),V(0.7L,0.1L),exact[5]}};
    Expect(HullBound(bad,exact)>0.003L,"oracle must reject a visibly corrupted cubic");
    // Explicitly reproduce the raw Hermite issue that motivated tangent
    // limiting; an unmodified Hermite first segment really leaves the rect.
    Restrict(0,0.125L,exact);
    Cubic hermite={{exact[0],Add(exact[0],Mul(Sub(exact[1],exact[0]),5.0L/3)),
                   Sub(exact[5],Mul(Sub(exact[5],exact[4]),5.0L/3)),exact[5]}};
    Expect(Evaluate(hermite.p,3,0.1L).y<0,"oracle detects Hermite endpoint overshoot");
    printf("%s independent oracle sensitivity to corrupted controls and raw Hermite overshoot\n",
           Failures==failuresBefore ? "PASS" : "FAIL");
}

int main(void) {
    @autoreleasepool {
        CheckIdealGeometry(); CheckRectangles(); CheckQuarters(); CheckOracleSensitivity();
        printf("%s: %llu assertions, %llu rect cases, %llu actual cubic segments; "
               "max certified hull error=%.12Lgpt, max sampled error=%.12Lgpt (limit .003pt)\n",
               Failures ? "FAIL" : "PASS",Assertions,PathCases,Segments,MaxHullError,MaxSampleError);
        if (Failures) fprintf(stderr,"%u assertion(s) failed\n",Failures);
        return Failures ? 1 : 0;
    }
}
