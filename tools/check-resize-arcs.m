#import <Cocoa/Cocoa.h>
// The shared chrome header also contains an unrelated image drawing block.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
#import "../src/YSPanelChrome.h"
#pragma clang diagnostic pop
#include <stdarg.h>
#include <stdio.h>

// Offline oracle: differentiate/evaluate the original quintic Bernstein net,
// independently of the production corner evaluator and offset helpers.
typedef struct { double x, y; } Vec;
typedef struct { Vec p[4]; } Cubic;
static const Vec Unit[] = {{0,0}, {.2,0}, {1,0}, {1,0}, {1,.8}, {1,1}};
static unsigned long Assertions, Failures, Samples;
static double MaxOffsetError, MaxSpacingError, CurvatureBound, MinStrokeMargin = INFINITY;

static void Expect(BOOL ok, const char *format, ...) {
    Assertions++;
    if (ok) return;
    Failures++;
    if (Failures > 20) return;
    va_list args; va_start(args, format);
    fputs("FAIL: ", stderr); vfprintf(stderr, format, args); fputc('\n', stderr);
    va_end(args);
}
static Vec V(double x, double y) { return (Vec){x,y}; }
static Vec FromPoint(NSPoint p) { return V(p.x,p.y); }
static Vec Add(Vec a, Vec b) { return V(a.x+b.x,a.y+b.y); }
static Vec Sub(Vec a, Vec b) { return V(a.x-b.x,a.y-b.y); }
static Vec Mul(Vec a, double s) { return V(a.x*s,a.y*s); }
static double Dot(Vec a, Vec b) { return a.x*b.x+a.y*b.y; }
static double Cross(Vec a, Vec b) { return a.x*b.y-a.y*b.x; }
static double Norm(Vec a) { return hypot(a.x,a.y); }
static void Split(const Vec *p, unsigned n, double t, Vec *left, Vec *right) {
    Vec row[8];
    for (unsigned i=0;i<=n;i++) row[i]=p[i];
    left[0]=row[0]; right[n]=row[n];
    for (unsigned level=1;level<=n;level++) {
        for (unsigned i=0;i<=n-level;i++) row[i]=Add(Mul(row[i],1-t),Mul(row[i+1],t));
        left[level]=row[0]; right[n-level]=row[n-level];
    }
}
static Vec Eval(const Vec *p, unsigned n, double t) {
    Vec left[8],right[8]; Split(p,n,t,left,right); return left[n];
}
static void Derive(const Vec *p, unsigned n, Vec *d) {
    for (unsigned i=0;i<n;i++) d[i]=Mul(Sub(p[i+1],p[i]),n);
}
static void Restrict(const Vec *p, unsigned n, double a, double b, Vec *result) {
    Vec left[8],unused[8]; Split(p,n,b,left,unused);
    Split(left,n,a/b,unused,result);
}
static double Choose(unsigned n, unsigned k) {
    double value=1;
    for (unsigned i=1;i<=k;i++) value=value*(n+1-i)/i;
    return value;
}
static double CrossCoefficient(const Vec *a, unsigned n, const Vec *b, unsigned m, unsigned k) {
    double value=0;
    for (unsigned i=0;i<=n;i++) for (unsigned j=0;j<=m;j++)
        if (i+j==k) value+=Cross(a[i],b[j])*Choose(n,i)*Choose(m,j)/Choose(n+m,k);
    return value;
}

static void CheckCurvatureCertificate(void) {
    Vec d1[5],d2[4]; Derive(Unit,5,d1); Derive(d1,4,d2);
    // On each interval the derivative and cross-product Bernstein hulls bound
    // speed from below and cross(C',C'') from above. This certifies kappa<3
    // over the ENTIRE ideal corner, rather than only at sampled parameters.
    for (unsigned cell=0;cell<256;cell++) {
        Vec a[5],b[4];
        Restrict(d1,4,cell/256.0,(cell+1)/256.0,a);
        Restrict(d2,3,cell/256.0,(cell+1)/256.0,b);
        double minX=INFINITY,minY=INFINITY,maxCross=0;
        for (unsigned i=0;i<5;i++) { minX=fmin(minX,a[i].x); minY=fmin(minY,a[i].y); }
        for (unsigned k=0;k<8;k++) maxCross=fmax(maxCross,CrossCoefficient(a,4,b,3,k));
        double speed=Norm(V(minX,minY)), bound=maxCross/(speed*speed*speed);
        Expect(speed>0 && minX>=0 && minY>=0 && bound<3,"curvature certificate cell %u",cell);
        CurvatureBound=fmax(CurvatureBound,bound);
    }
}

static Vec PanelCorner(double t, double extent, Vec edge) {
    Vec p=Eval(Unit,5,t);
    return V(edge.x-extent*p.y,edge.y-extent+extent*p.x);
}
static double NearestParameter(Vec q, double extent, Vec edge) {
    // Locate a minimum globally on a coarse grid, then refine its bracket.
    // This does not assume the cubic's subdivision or parameterization.
    unsigned best=0; double distance=INFINITY;
    for (unsigned i=0;i<=64;i++) {
        Vec delta=Sub(PanelCorner(i/64.0,extent,edge),q);
        double candidate=Dot(delta,delta);
        if (candidate<distance) { distance=candidate; best=i; }
    }
    double lo=(best ? best-1 : 0)/64.0,hi=fmin(64,best+1)/64.0;
    for (unsigned i=0;i<52;i++) {
        double a=(2*lo+hi)/3,b=(lo+2*hi)/3;
        Vec da=Sub(PanelCorner(a,extent,edge),q),db=Sub(PanelCorner(b,extent,edge),q);
        if (Dot(da,da)<Dot(db,db)) hi=b; else lo=a;
    }
    return (lo+hi)/2;
}

static unsigned ReadPath(NSBezierPath *path, NSRect bounds, Cubic cubics[64]) {
    Expect(path.lineWidth==1.2 && path.lineCapStyle==NSLineCapStyleRound,"1.2pt round stroke retained");
    NSPoint points[3]; Vec current=V(0,0); unsigned count=0;
    for (NSInteger i=0;i<path.elementCount;i++) {
        NSBezierPathElement element=[path elementAtIndex:i associatedPoints:points];
        if (i==0) { Expect(element==NSBezierPathElementMoveTo,"one initial move"); current=FromPoint(points[0]); continue; }
        Expect(element==NSBezierPathElementCurveTo,"all drawing elements must be cubic, never line/close/move");
        if (element!=NSBezierPathElementCurveTo || count>=64) continue;
        Cubic c={{current,FromPoint(points[0]),FromPoint(points[1]),FromPoint(points[2])}};
        for (unsigned p=0;p<4;p++) {
            double margin=fmin(fmin(c.p[p].x-NSMinX(bounds),NSMaxX(bounds)-c.p[p].x),
                               fmin(c.p[p].y-NSMinY(bounds),NSMaxY(bounds)-c.p[p].y))-.6;
            Expect(isfinite(margin) && margin>=0,"full control hull + round caps inside view");
            MinStrokeMargin=fmin(MinStrokeMargin,margin);
        }
        Vec d1[3],d2[2]; Derive(c.p,3,d1); Derive(d1,2,d2);
        for (unsigned p=0;p<3;p++) Expect(d1[p].x<0 && d1[p].y>0,"strictly monotone/regular cubic");
        for (unsigned k=0;k<4;k++)
            Expect(CrossCoefficient(d1,2,d2,1,k)>0,"curvature certificate: not a polyline or flat cubic");
        if (count) {
            Vec previous=Sub(cubics[count-1].p[3],cubics[count-1].p[2]);
            Vec next=Sub(c.p[1],c.p[0]);
            double magnitude=fmax(1,fmax(fabs(c.p[0].x),fabs(c.p[0].y)));
            Expect(Norm(Sub(previous,next))<32*DBL_EPSILON*magnitude,"C1 joins without visible kinks");
        }
        cubics[count++]=c; current=c.p[3];
    }
    Expect(count>1 && count<64,"short open curve with multiple cubic spans");
    return count;
}

static void CheckDefaultGeometry(void) {
    NSRect bounds=NSMakeRect(0,0,24,24);
    NSArray<NSBezierPath *> *paths=YSResizeArcPaths(bounds,18,2);
    Expect(paths.count==2,"R18 two-line mode");
    if (paths.count!=2) return;
    // Recover the whole-panel extent from its independently known midpoint
    // relation, not the production YSG3CornerExtent helper.
    double extent=18*(1-1/sqrt(2))*32/5; Vec edge=V(28,28);
    Cubic outer[64],inner[64];
    unsigned n=ReadPath(paths[0],bounds,outer),m=ReadPath(paths[1],bounds,inner);
    Expect(n==m,"paired curve partitions");
    if (n!=m) return;
    for (unsigned line=0;line<2;line++) {
        Cubic *curves=line ? inner : outer; double inset=line ? 10 : 5.5;
        for (unsigned i=0;i<n;i++) for (unsigned sample=0;sample<=256;sample++) {
            double u=sample/256.0; Vec q=Eval(curves[i].p,3,u);
            double t=NearestParameter(q,extent,edge);
            double error=fabs(Norm(Sub(q,PanelCorner(t,extent,edge)))-inset);
            MaxOffsetError=fmax(MaxOffsetError,error); Samples++;
            Expect(t>.27 && t<.73 && error<.001,"constant %.1fpt normal offset error %.9g",inset,error);
            Vec paired=Eval((line ? outer : inner)[i].p,3,u);
            double spacing=fabs(Norm(Sub(paired,q))-4.5);
            MaxSpacingError=fmax(MaxSpacingError,spacing);
            Expect(spacing<.001,"constant 4.5pt spacing error %.9g",spacing);
        }
    }
    // Reflection in x=y maps each complete stroke onto itself.
    for (unsigned i=0;i<n;i++) for (unsigned p=0;p<4;p++) {
        Vec a=outer[i].p[p],b=outer[n-1-i].p[3-p];
        Expect(Norm(Sub(a,V(b.y,b.x)))<2e-12,"diagonal symmetry");
    }
}

static void CheckOriginsModesAndInvalidInput(void) {
    NSArray<NSBezierPath *> *reference=YSResizeArcPaths(NSMakeRect(0,0,24,24),18,2);
    NSPoint origins[]={{.25,-.75},{-1234.5,987.25},{100000,-200000},{-1e8,2e8}};
    for (unsigned k=0;k<sizeof(origins)/sizeof(origins[0]);k++) {
        NSRect bounds=NSMakeRect(origins[k].x,origins[k].y,24,24);
        NSArray<NSBezierPath *> *translated=YSResizeArcPaths(bounds,18,2);
        Expect(translated.count==2,"nonzero origin supported");
        for (NSUInteger line=0;line<MIN(translated.count,reference.count);line++) {
            NSBezierPath *a=reference[line],*b=translated[line];
            Expect(a.elementCount==b.elementCount,"translation retains structure");
            Cubic curves[64]; ReadPath(b,bounds,curves);
            for (NSInteger i=0;i<MIN(a.elementCount,b.elementCount);i++) {
                NSPoint pa[3],pb[3]; NSBezierPathElement type=[a elementAtIndex:i associatedPoints:pa];
                Expect(type==[b elementAtIndex:i associatedPoints:pb],"translation retains element type");
                unsigned points=type==NSBezierPathElementCurveTo ? 3 : 1;
                double tolerance=32*DBL_EPSILON*fmax(1,fmax(fabs(origins[k].x),fabs(origins[k].y)));
                for (unsigned j=0;j<points;j++)
                    Expect(Norm(Sub(Sub(FromPoint(pb[j]),FromPoint(pa[j])),FromPoint(origins[k])))<tolerance,"origin-relative coordinates");
            }
        }
    }
    Expect(YSResizeArcPaths(NSMakeRect(0,0,24,24),18,0).count==0,"zero-count mode");
    Expect(YSResizeArcPaths(NSMakeRect(0,0,24,24),18,NSUIntegerMax).count==2,"counts clamped to two");
    NSArray *single=YSResizeArcPaths(NSMakeRect(0,0,24,24),18,1);
    Expect(single.count==1,"single mode returns a path");
    if (single.count==1) {
        NSBezierPath *a=single[0],*b=reference[0];
        Expect(NSEqualRects(a.controlPointBounds,b.controlPointBounds) && a.elementCount==b.elementCount,
               "single mode retains outer geometry");
        for (NSInteger i=0;i<MIN(a.elementCount,b.elementCount);i++) {
            NSPoint pa[3],pb[3]; NSBezierPathElement type=[a elementAtIndex:i associatedPoints:pa];
            Expect(type==[b elementAtIndex:i associatedPoints:pb],"single mode retains element type");
            for (unsigned p=0;p<(type==NSBezierPathElementCurveTo ? 3u : 1u);p++)
                Expect(NSEqualPoints(pa[p],pb[p]),"single mode retains every outer control point");
        }
    }
    CGFloat radii[]={0,-18,NAN,INFINITY,-INFINITY,DBL_MAX,DBL_MIN,12,100};
    for (unsigned i=0;i<sizeof(radii)/sizeof(radii[0]);i++)
        Expect(YSResizeArcPaths(NSMakeRect(0,0,24,24),radii[i],2).count==0,"unusable radius safely empty");
    NSRect invalid[]={NSMakeRect(0,0,0,24),NSMakeRect(0,0,24,-1),NSMakeRect(0,0,1,1),
        NSMakeRect(NAN,0,24,24),NSMakeRect(0,INFINITY,24,24),NSMakeRect(0,0,INFINITY,24),
        NSMakeRect(DBL_MAX,0,24,24),NSMakeRect(1e20,0,24,24),NSMakeRect(0,0,8,24)};
    for (unsigned i=0;i<sizeof(invalid)/sizeof(invalid[0]);i++)
        Expect(YSResizeArcPaths(invalid[i],18,2).count==0,"invalid or clipping bounds safely empty");
    // Nearby real radii must still produce safe smooth paths; no test GUI.
    CGFloat supported[]={17,17.5,18,18.5,19};
    for (unsigned i=0;i<sizeof(supported)/sizeof(supported[0]);i++) {
        NSArray<NSBezierPath *> *paths=YSResizeArcPaths(NSMakeRect(0,0,24,24),supported[i],2);
        Expect(paths.count==2,"nearby supported radius %.2f",supported[i]);
        for (NSBezierPath *path in paths) { Cubic curves[64]; ReadPath(path,NSMakeRect(0,0,24,24),curves); }
    }
}

int main(void) {
    @autoreleasepool {
        CheckCurvatureCertificate(); CheckDefaultGeometry(); CheckOriginsModesAndInvalidInput();
        printf("resize-arcs: %s; %lu assertions; %lu offset samples; max offset error=%.9gpt; "
               "max spacing error=%.9gpt; certified unit curvature<=%.9g<3; min stroke margin=%.9gpt\n",
               Failures ? "FAIL" : "PASS",Assertions,Samples,MaxOffsetError,MaxSpacingError,CurvatureBound,MinStrokeMargin);
        return Failures ? 1 : 0;
    }
}
