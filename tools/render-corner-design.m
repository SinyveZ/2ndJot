#define main YSBrandPreviewMain
#import "render-brand.m"
#undef main

static NSBezierPath *ComparisonPath(NSRect rect, CGFloat radius, BOOL continuous) {
    return continuous ? YSG3RoundedRect(rect,radius)
        : [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
}
static void ComparisonPanel(NSPoint origin, BOOL continuous) {
    [NSGraphicsContext saveGraphicsState];
    CGContextRef context=NSGraphicsContext.currentContext.CGContext;
    CGContextTranslateCTM(context,origin.x,origin.y);
    NSBezierPath *path=ComparisonPath(NSMakeRect(0,0,480,180),18,continuous);
    [[NSColor colorWithWhite:.50 alpha:1] setFill]; [path fill];
    [[NSColor colorWithWhite:1 alpha:.18] setStroke]; path.lineWidth=1; [path stroke];
    Circle(8,8,NO);
    Text(@"回车或软盘存盘 · 图钉变便签",56,18,334,12,NO,.72);
    TintImage(YSFloppyDiskImage(),NSMakeRect(409,18,16,16));
    NSImage *pin=[[NSImage imageWithSystemSymbolName:@"pin" accessibilityDescription:nil]
        imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium]];
    CGFloat w=14*pin.size.width/pin.size.height;
    TintImage(pin,NSMakeRect(453-w/2,19,w,14));
    Text(@"先接住这个念头，继续手头的事。",26,62,430,21,NO,1);
    [NSGraphicsContext restoreGraphicsState];
}
static void CornerZoom(NSPoint origin, BOOL continuous) {
    [NSGraphicsContext saveGraphicsState];
    NSRect crop=NSMakeRect(origin.x,origin.y,380,380);
    [[NSBezierPath bezierPathWithRect:crop] addClip];
    CGContextRef context=NSGraphicsContext.currentContext.CGContext;
    CGContextTranslateCTM(context,origin.x,origin.y);
    CGContextScaleCTM(context,10,10);
    NSBezierPath *path=ComparisonPath(NSMakeRect(0,0,120,120),18,continuous);
    [[NSColor colorWithWhite:.50 alpha:1] setFill]; [path fill];
    [[NSColor colorWithSRGBRed:.24 green:.37 blue:.52 alpha:1] setStroke]; path.lineWidth=.35; [path stroke];
    [NSGraphicsContext restoreGraphicsState];
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *folder=argc>1?@(argv[1]):@"docs/media";
        SavePNG([folder stringByAppendingPathComponent:@"g3-corners.png"],1440,1130,^{
            Round(NSMakeRect(0,0,1440,1130),0,.97);
            Text(@"双轨记 · 连续曲率圆角",70,46,1300,34,YES,.18);
            Text(@"直边逐渐进入转角，保留原有面板尺度与控件位置。",70,108,1300,21,NO,.42);
            Text(@"原圆弧圆角",70,180,600,24,YES,.25);
            Text(@"G3 连续曲率轮廓",820,180,550,24,YES,.25);
            ComparisonPanel(NSMakePoint(70,235),NO);
            ComparisonPanel(NSMakePoint(820,235),YES);
            Text(@"左上角局部 · 10×",70,465,600,20,NO,.43);
            Text(@"左上角局部 · 10×",820,465,550,20,NO,.43);
            CornerZoom(NSMakePoint(70,530),NO);
            CornerZoom(NSMakePoint(820,530),YES);
            Text(@"直线进入恒定曲率圆弧，弯曲程度在接点改变。",70,950,620,19,NO,.40);
            Text(@"弯曲程度逐渐变化，直边与转角更自然地相接。",820,950,550,19,NO,.40);
            Text(@"轮廓设计对照 · 同一标记与布局 · 几何示意，非应用截图",70,1062,1300,17,NO,.50);
        });
    }
    return 0;
}
