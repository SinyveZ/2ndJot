#import <Cocoa/Cocoa.h>
#import <ImageIO/ImageIO.h>
#import "../src/YSPanelChrome.h"
#import "../src/YSBrandMark.h"
#import "../src/YSG3Corners.h"

static NSColor *RGB(CGFloat white) { return [NSColor colorWithWhite:white alpha:1]; }
static void Label(NSString *text, CGFloat x, CGFloat y, CGFloat w, CGFloat size, NSColor *color, BOOL bold) {
    [text drawInRect:NSMakeRect(x,y,w,200) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:size weight:bold ? NSFontWeightSemibold : NSFontWeightRegular],NSForegroundColorAttributeName:color}];
}
static void Shape(CGRect rect, CGFloat radius, NSColor *color) { [color setFill]; [YSG3RoundedRect(rect, radius) fill]; }
static void Symbol(NSString *name, CGRect frame, CGFloat pointSize) {
    NSImageSymbolConfiguration *size=[NSImageSymbolConfiguration configurationWithPointSize:pointSize weight:NSFontWeightMedium];
    NSImageSymbolConfiguration *color=[NSImageSymbolConfiguration configurationWithPaletteColors:@[[NSColor colorWithWhite:1 alpha:0.82]]];
    NSImage *image=[[NSImage imageWithSystemSymbolName:name accessibilityDescription:nil] imageWithSymbolConfiguration:[size configurationByApplyingConfiguration:color]];
    CGFloat width=frame.size.height*image.size.width/MAX(1,image.size.height);
    [image drawInRect:CGRectMake(CGRectGetMidX(frame)-width/2,frame.origin.y,width,frame.size.height) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
}
static void SaveSymbol(CGRect frame) {
    NSImage *line = YSFloppyDiskImage();
    NSImage *tinted = [NSImage imageWithSize:line.size flipped:YES drawingHandler:^BOOL(NSRect rect) {
        [line drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
        [[NSColor colorWithWhite:1 alpha:0.82] setFill];
        NSRectFillUsingOperation(rect, NSCompositingOperationSourceIn);
        return YES;
    }];
    [tinted drawInRect:frame fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
}
static void Panel(CGFloat x, CGFloat y, BOOL sticky, CGFloat scale, CGFloat alpha) {
    CGContextRef context=NSGraphicsContext.currentContext.CGContext;
    [NSGraphicsContext saveGraphicsState];
    CGContextTranslateCTM(context,x,y);
    Shape(CGRectMake(0,0,480,180),18,RGB(sticky ? 0.33 : 0.50));
    YSDrawFrostedChrome(context,CGRectMake(8,8,36,36),18,NO);
    if(sticky) {
        Symbol(@"arrow.up.to.line",CGRectMake(402,19,30,14),14);
        Symbol(@"xmark",CGRectMake(438,19,30,14),14);
        [NSGraphicsContext saveGraphicsState];
        CGContextSetAlpha(context,alpha);
        CGContextTranslateCTM(context,26,26);
        CGContextScaleCTM(context,scale,scale);
        Symbol(@"pin.fill",CGRectMake(-10,-10,20,20),16);
        [NSGraphicsContext restoreGraphicsState];
    } else {
        YSDrawBrandMark(context,NSMakeRect(16,16,20,20),[NSColor colorWithWhite:1 alpha:0.82]);
        Label(@"回车或软盘存盘 · 图钉变便签",56,18,334,12,[NSColor colorWithWhite:1 alpha:0.55],NO);
        SaveSymbol(CGRectMake(409,18,16,16));
        Symbol(@"pin",CGRectMake(438,19,30,14),14);
    }
    if (sticky) {
        [NSGraphicsContext saveGraphicsState];
        CGContextTranslateCTM(context,452,152);
        YSDrawResizeArcs(NSMakeRect(0,0,24,24),18,2);
        [NSGraphicsContext restoreGraphicsState];
    }
    Label(@"把眼前的想法，先记下来。",26,60,430,21,[NSColor whiteColor],NO);
    Label(sticky ? @"留在桌面，等下一次继续。" : @"写完回车，回到正在做的事。",26,94,430,18,[NSColor colorWithWhite:1 alpha:0.84],NO);
    [NSGraphicsContext restoreGraphicsState];
}
static NSBitmapImageRep *Bitmap(NSInteger w, NSInteger h, void (^draw)(void)) {
    NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:w pixelsHigh:h bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:w*4 bitsPerPixel:32];
    NSGraphicsContext *raw=[NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    CGContextRef context=raw.CGContext; CGContextTranslateCTM(context,0,h); CGContextScaleCTM(context,1,-1);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:context flipped:YES]];
    draw(); [NSGraphicsContext restoreGraphicsState];
    return rep;
}
int main(int argc,const char *argv[]) {
    @autoreleasepool {
        NSString *folder=argc>1 ? @(argv[1]) : @"docs/media";
        NSBitmapImageRep *board=Bitmap(1240,630,^{
            Shape(CGRectMake(0,0,1240,630),0,RGB(0.95));
            Label(@"双轨记 · 主线继续，灵感先记",70,46,1100,32,RGB(0.17),YES);
            Label(@"快捷输入框",70,135,480,23,RGB(0.24),YES);
            Label(@"桌面便签",690,135,480,23,RGB(0.24),YES);
            Panel(70,188,NO,1,1); Panel(690,188,YES,1,1);
            Label(@"软盘：存为 .md · 图钉：转为便签",70,397,500,19,RGB(0.42),NO);
            Label(@"左上图钉可拖动 · 右下圆弧可缩放",690,397,500,19,RGB(0.42),NO);
            Label(@"输入框默认浅染色，便签默认深染色；玻璃风格、染色与交互光效各自可调",70,487,1100,20,RGB(0.3),NO);
            Label(@"转换时轻压、淡入；恢复便签时静止。设计示意，实际玻璃以实机为准。",70,535,1100,17,RGB(0.45),NO);
        });
        [[board representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[folder stringByAppendingPathComponent:@"sticky-pin-design.png"] atomically:YES];
        NSURL *url=[NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"sticky-pin-motion.gif"]];
        CGImageDestinationRef gif=CGImageDestinationCreateWithURL((__bridge CFURLRef)url,CFSTR("com.compuserve.gif"),60,NULL);
        CGImageDestinationSetProperties(gif,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImagePropertyGIFDictionary:@{(__bridge NSString *)kCGImagePropertyGIFLoopCount:@0}});
        for(NSInteger frame=0;frame<60;frame++) {
            NSBitmapImageRep *rep=Bitmap(640,340,^{
                Shape(CGRectMake(0,0,640,340),0,RGB(0.95));
                CGFloat t=frame/24.0-0.55;
                BOOL sticky=t>=0;
                CGFloat progress=MIN(1,MAX(0,t/0.28));
                CGFloat size=progress<0.55 ? 1.06+(0.94-1.06)*progress/0.55 : 0.94+0.06*(progress-0.55)/0.45;
                Panel(80,70,sticky,size,MIN(1,MAX(0,t/0.14)));
                Label(sticky ? @"已钉成便签" : @"快捷输入框",80,21,480,20,RGB(0.23),YES);
                Label(@"动效设计示意 · 非录屏",80,280,480,15,RGB(0.47),NO);
            });
            NSDictionary *properties=@{(__bridge NSString *)kCGImagePropertyGIFDictionary:@{(__bridge NSString *)kCGImagePropertyGIFDelayTime:@(1.0/24)}};
            CGImageDestinationAddImage(gif,rep.CGImage,(__bridge CFDictionaryRef)properties);
        }
        BOOL okay=CGImageDestinationFinalize(gif); CFRelease(gif);
        if(!okay) return 1;
        puts(folder.UTF8String);
    }
}
