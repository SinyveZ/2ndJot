#import <Cocoa/Cocoa.h>
#import "../src/YSBrandMark.h"
#import "../src/YSBrandIcon.h"
#import "../src/YSPanelChrome.h"

static void SavePNG(NSString *path, NSInteger sideX, NSInteger sideY, void (^drawing)(void)) {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:sideX pixelsHigh:sideY bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:sideX * 4 bitsPerPixel:32];
    NSGraphicsContext *raw = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    CGContextRef context = raw.CGContext;
    CGContextTranslateCTM(context, 0, sideY); CGContextScaleCTM(context, 1, -1);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:context flipped:YES]];
    drawing();
    [NSGraphicsContext restoreGraphicsState];
    NSData *data = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (![data writeToFile:path atomically:YES]) { fprintf(stderr, "Cannot write %s\n", path.UTF8String); exit(1); }
}
static void Text(NSString *text, CGFloat x, CGFloat y, CGFloat width, CGFloat size, BOOL bold, CGFloat white) {
    [text drawInRect:NSMakeRect(x,y,width,120) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:size weight:bold ? NSFontWeightSemibold : NSFontWeightRegular],NSForegroundColorAttributeName:[NSColor colorWithWhite:white alpha:1]}];
}
static void Round(NSRect rect, CGFloat radius, CGFloat white) {
    [[NSColor colorWithWhite:white alpha:1] setFill];
    [YSG3RoundedRect(rect, radius) fill];
}
static void Icon(CGFloat side) { YSDrawBrandIcon(side); }
static NSString *SVG(void) {
    NSMutableString *svg = [NSMutableString stringWithString:@"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"currentColor\">\n"];
    for (NSBezierPath *path in YSBrandPaths()) {
        NSMutableString *d = [NSMutableString string];
        for (NSInteger i = 0; i < path.elementCount; i++) {
            NSPoint p[3];
            switch ([path elementAtIndex:i associatedPoints:p]) {
                case NSBezierPathElementMoveTo: [d appendFormat:@"M%.3g %.3g ",p[0].x,p[0].y]; break;
                case NSBezierPathElementLineTo: [d appendFormat:@"L%.3g %.3g ",p[0].x,p[0].y]; break;
                case NSBezierPathElementCubicCurveTo: [d appendFormat:@"C%.3g %.3g %.3g %.3g %.3g %.3g ",p[0].x,p[0].y,p[1].x,p[1].y,p[2].x,p[2].y]; break;
                case NSBezierPathElementClosePath: [d appendString:@"Z "]; break;
                default: break;
            }
        }
        [svg appendFormat:@"  <path d=\"%@\"/>\n",d];
    }
    [svg appendString:@"</svg>\n"]; return svg;
}
static void TintImage(NSImage *image, NSRect rect) {
    NSImage *tinted = [NSImage imageWithSize:image.size flipped:YES drawingHandler:^BOOL(NSRect bounds) {
        [image drawInRect:bounds fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
        [[NSColor colorWithWhite:1 alpha:0.82] setFill]; NSRectFillUsingOperation(bounds, NSCompositingOperationSourceIn); return YES;
    }];
    [tinted drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
}
static void Circle(CGFloat x, CGFloat y, BOOL sticky) {
    YSDrawFrostedChrome(NSGraphicsContext.currentContext.CGContext, NSMakeRect(x,y,36,36),18,NO);
    if (sticky) { NSImage *pin = YSStickyGlyphImage(); CGFloat w=20*pin.size.width/pin.size.height; TintImage(pin,NSMakeRect(x+18-w/2,y+8,w,20)); }
    else YSDrawBrandMark(NSGraphicsContext.currentContext.CGContext,NSMakeRect(x+8,y+8,20,20),[NSColor colorWithWhite:1 alpha:0.82]);
}
static void Panel(CGFloat x, CGFloat y, BOOL sticky, NSUInteger arcs) {
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    [NSGraphicsContext saveGraphicsState]; CGContextTranslateCTM(context,x,y);
    Round(NSMakeRect(0,0,480,180),18,sticky?0.33:0.50); Circle(8,8,sticky);
    if (!sticky) {
        Text(@"回车或软盘存盘 · 图钉变便签",56,18,334,12,NO,0.82);
        TintImage(YSFloppyDiskImage(),NSMakeRect(409,18,16,16));
    }
    NSImageSymbolConfiguration *size=[NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium];
    for (NSInteger i=sticky?0:1;i<2;i++) {
        NSString *name=sticky?(i==0?@"arrow.up.to.line":@"xmark"):@"pin";
        NSImage *image=[[NSImage imageWithSystemSymbolName:name accessibilityDescription:nil] imageWithSymbolConfiguration:size];
        CGFloat w=14*image.size.width/image.size.height;
        TintImage(image,NSMakeRect(417+36*i-w/2,19,w,14));
    }
    Text(@"把想法记下来，回到正在做的事。",26,60,430,21,NO,1);
    if (sticky) {
        [NSGraphicsContext saveGraphicsState]; CGContextTranslateCTM(context,452,152); YSDrawResizeArcs(NSMakeRect(0,0,24,24),18,arcs); [NSGraphicsContext restoreGraphicsState];
    }
    [NSGraphicsContext restoreGraphicsState];
}
int main(int argc,const char *argv[]) {
    @autoreleasepool {
        if (argc < 3) return 1;
        NSString *mode = @(argv[1]), *folder = @(argv[2]);
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        if ([mode isEqualToString:@"--assets"]) {
            NSString *set = [folder stringByAppendingPathComponent:@"AppIcon.iconset"];
            [[NSFileManager defaultManager] createDirectoryAtPath:set withIntermediateDirectories:YES attributes:nil error:nil];
            NSArray *sizes = @[@[@"icon_16x16",@16],@[@"icon_16x16@2x",@32],@[@"icon_32x32",@32],@[@"icon_32x32@2x",@64],@[@"icon_128x128",@128],@[@"icon_128x128@2x",@256],@[@"icon_256x256",@256],@[@"icon_256x256@2x",@512],@[@"icon_512x512",@512],@[@"icon_512x512@2x",@1024]];
            for (NSArray *entry in sizes) { NSInteger size = [entry[1] integerValue]; SavePNG([set stringByAppendingPathComponent:[entry[0] stringByAppendingString:@".png"]],size,size,^{Icon(size);}); }
        } else if ([mode isEqualToString:@"--preview"]) {
            SavePNG([folder stringByAppendingPathComponent:@"app-icon.png"],1024,1024,^{Icon(1024);});
            SavePNG([folder stringByAppendingPathComponent:@"brand-design.png"],1440,1030,^{
                Round(NSMakeRect(0,0,1440,1030),0,0.96);
                Text(@"双轨记",70,48,1300,36,YES,0.16);
                Text(@"主线继续，灵感先记。",70,106,1300,21,NO,0.4);
                [NSGraphicsContext saveGraphicsState]; CGContextTranslateCTM(NSGraphicsContext.currentContext.CGContext,48,155); Icon(360); [NSGraphicsContext restoreGraphicsState];
                Text(@"应用图标",90,520,300,18,YES,0.3);
                YSDrawBrandMark(NSGraphicsContext.currentContext.CGContext,NSMakeRect(510,245,100,100),[NSColor colorWithWhite:0.23 alpha:1]);
                Text(@"同一份矢量路径",460,420,300,18,NO,0.4);
                Round(NSMakeRect(800,250,260,44),12,0.88); YSDrawBrandMark(NSGraphicsContext.currentContext.CGContext,NSMakeRect(920,262,18,18),NSColor.blackColor);
                Text(@"菜单栏 18 pt",820,420,260,18,NO,0.4);
                Round(NSMakeRect(1170,220,160,108),18,0.5);
                [NSGraphicsContext saveGraphicsState]; CGContextTranslateCTM(NSGraphicsContext.currentContext.CGContext,1214,238); CGContextScaleCTM(NSGraphicsContext.currentContext.CGContext,2,2); Circle(0,0,NO); [NSGraphicsContext restoreGraphicsState];
                Text(@"输入框圆点",1170,420,230,18,NO,0.4);
                Text(@"快捷输入框",70,620,580,23,YES,0.25); Text(@"桌面便签",820,620,580,23,YES,0.25);
                Panel(70,680,NO,2); Panel(820,680,YES,2);
                Text(@"左上角是品牌标记",70,896,600,19,NO,0.4); Text(@"左上角换为图钉，仍可按住拖动",820,896,600,19,NO,0.4);
                Text(@"设计示意；真实液态玻璃效果以应用窗口为准。",70,970,1300,16,NO,0.5);
            });
            SavePNG([folder stringByAppendingPathComponent:@"resize-arc-comparison.png"],1240,430,^{
                Round(NSMakeRect(0,0,1240,430),0,0.96); Text(@"缩放提示 · 沿窗口转角等距内缩",70,35,1100,28,YES,0.2);
                Panel(70,115,YES,1); Panel(690,115,YES,2);
                Text(@"一条圆弧",70,330,480,20,NO,0.35); Text(@"两条圆弧",690,330,480,20,NO,0.35);
                Text(@"两种提示均保留原有缩放操作区域。矢量示意。",70,382,1100,16,NO,0.5);
            });
        } else return 1;
        [SVG() writeToFile:[folder stringByAppendingPathComponent:@"2ndJotMark.svg"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    return 0;
}
