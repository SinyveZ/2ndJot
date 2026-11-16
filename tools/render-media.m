// Editorial layouts with original brand vectors and unchanged native window
// captures. Pages 2/4 identify real screenshots; the other pages are diagrams.
#import <Cocoa/Cocoa.h>
#import "../src/YSBrandMark.h"
#import "../src/YSBrandIcon.h"

static NSSize CanvasSize;
static NSUInteger TextBlocks;
static NSImage *QuickScreenshot, *StickyScreenshot, *QuickEnglishScreenshot, *StickyEnglishScreenshot;

static NSColor *C(unsigned int hex) {
    return [NSColor colorWithSRGBRed:((hex >> 16) & 255) / 255.0
                             green:((hex >> 8) & 255) / 255.0
                              blue:(hex & 255) / 255.0 alpha:1];
}
static NSColor *Paper(void) { return C(0xF6F7F9); }
static NSColor *Ink(void) { return C(0x283240); }
static NSColor *Muted(void) { return C(0x65717F); }
static NSColor *Accent(void) { return C(0x53677C); }
static NSColor *LightInk(void) { return C(0xF7F9FC); }
static NSFont *Font(CGFloat size, BOOL bold) {
    return [NSFont fontWithName:bold ? @"PingFangSC-Semibold" : @"PingFangSC-Regular" size:size]
        ?: [NSFont systemFontOfSize:size weight:bold ? NSFontWeightSemibold : NSFontWeightRegular];
}

static void Text(NSString *text, CGFloat x, CGFloat y, CGFloat width, CGFloat size, BOOL bold, NSColor *color) {
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.lineSpacing = size * 0.18;
    style.lineBreakMode = NSLineBreakByClipping;
    NSDictionary *attributes = @{NSFontAttributeName:Font(size, bold),
                                 NSForegroundColorAttributeName:color,
                                 NSParagraphStyleAttributeName:style};
    // Every line is authored explicitly. Fail instead of silently wrapping or clipping a name.
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        CGFloat lineWidth = [line sizeWithAttributes:attributes].width;
        if (lineWidth > width + 0.5) {
            fprintf(stderr, "Text exceeds its column (%.1f > %.1f): %s\n", lineWidth, width, line.UTF8String);
            exit(1);
        }
    }
    NSSize measured = [text boundingRectWithSize:NSMakeSize(width, CGFLOAT_MAX)
                                       options:NSStringDrawingUsesLineFragmentOrigin
                                    attributes:attributes].size;
    NSRect rect = NSMakeRect(x, y, width, ceil(measured.height) + 6);
    if (x < 0 || y < 0 || NSMaxX(rect) > CanvasSize.width || NSMaxY(rect) > CanvasSize.height) {
        fprintf(stderr, "Text exceeds the canvas: %s\n", text.UTF8String);
        exit(1);
    }
    [text drawWithRect:rect options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes];
    TextBlocks++;
}

static void Box(CGFloat x, CGFloat y, CGFloat w, CGFloat h, CGFloat radius, NSColor *color) {
    [color setFill];
    [YSG3RoundedRect(NSMakeRect(x,y,w,h), radius) fill];
}
static void Rule(CGFloat y) { Box(76,y,928,1,0,C(0xDCE2E9)); }
static void Frost(CGFloat x, CGFloat y, CGFloat w, CGFloat h, CGFloat radius, BOOL dark) {
    NSBezierPath *path = YSG3RoundedRect(NSMakeRect(x,y,w,h), radius);
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:C(dark ? 0x718091 : 0xF0F3F7)
                                                       endingColor:C(dark ? 0x3F4C5C : 0xDDE4EC)];
    [gradient drawInBezierPath:path angle:90];
    NSBezierPath *edge = YSG3RoundedRect(NSMakeRect(x+1,y+1,w-2,h-2), radius-1);
    [[NSColor.whiteColor colorWithAlphaComponent:dark ? 0.25 : 0.72] setStroke];
    edge.lineWidth = 1.5;
    [edge stroke];
}
static void Brand(CGFloat x, CGFloat y, CGFloat size, NSColor *color) {
    YSDrawBrandMark(NSGraphicsContext.currentContext.CGContext, NSMakeRect(x,y,size,size),color);
}
static void AppIcon(CGFloat x, CGFloat y, CGFloat size) {
    [NSGraphicsContext saveGraphicsState];
    CGContextRef context=NSGraphicsContext.currentContext.CGContext;
    CGContextTranslateCTM(context,x-size*64/896,y-size*64/896);
    YSDrawBrandIcon(size*1024/896);
    [NSGraphicsContext restoreGraphicsState];
}

static void Screenshot(NSImage *image, CGFloat x, CGFloat y, CGFloat width) {
    NSSize size = image.size;
    NSRect frame = NSMakeRect(x,y,width,width*size.height/size.width);
    [NSGraphicsContext saveGraphicsState];
    [YSG3RoundedRect(frame,18*width/size.width) addClip];
    [image drawInRect:frame
            fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1
      respectFlipped:YES hints:nil];
    [NSGraphicsContext restoreGraphicsState];
}

// Small operation symbols use AppKit paths, without image assets or font glyph fallbacks.
static void Floppy(CGFloat x, CGFloat y, CGFloat size, NSColor *color) {
    [NSGraphicsContext saveGraphicsState];
    CGContextRef cg = NSGraphicsContext.currentContext.CGContext;
    CGContextTranslateCTM(cg,x,y);
    CGContextScaleCTM(cg,size/24,size/24);
    [color setStroke];
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(4,3)];
    [path lineToPoint:NSMakePoint(17,3)];
    [path lineToPoint:NSMakePoint(21,7)];
    [path lineToPoint:NSMakePoint(21,21)];
    [path lineToPoint:NSMakePoint(3,21)];
    [path lineToPoint:NSMakePoint(3,3)];
    [path closePath];
    [path moveToPoint:NSMakePoint(7,3)]; [path lineToPoint:NSMakePoint(7,10)];
    [path lineToPoint:NSMakePoint(16,10)]; [path lineToPoint:NSMakePoint(16,3)];
    [path moveToPoint:NSMakePoint(7,21)]; [path lineToPoint:NSMakePoint(7,14)];
    [path lineToPoint:NSMakePoint(17,14)]; [path lineToPoint:NSMakePoint(17,21)];
    path.lineWidth = 1.6;
    path.lineJoinStyle = NSLineJoinStyleRound;
    [path stroke];
    [NSGraphicsContext restoreGraphicsState];
}
static void Pin(CGFloat x, CGFloat y, CGFloat size, NSColor *color) {
    [NSGraphicsContext saveGraphicsState];
    CGContextRef cg = NSGraphicsContext.currentContext.CGContext;
    CGContextTranslateCTM(cg,x,y);
    CGContextScaleCTM(cg,size/24,size/24);
    [color setFill];
    NSBezierPath *head = [NSBezierPath bezierPath];
    [head moveToPoint:NSMakePoint(6,3)]; [head lineToPoint:NSMakePoint(18,3)];
    [head lineToPoint:NSMakePoint(15,7)]; [head lineToPoint:NSMakePoint(15,12)];
    [head lineToPoint:NSMakePoint(19,16)]; [head lineToPoint:NSMakePoint(5,16)];
    [head lineToPoint:NSMakePoint(9,12)]; [head lineToPoint:NSMakePoint(9,7)];
    [head closePath]; [head fill];
    [color setStroke];
    NSBezierPath *stem = [NSBezierPath bezierPath];
    [stem moveToPoint:NSMakePoint(12,15)]; [stem lineToPoint:NSMakePoint(12,22)];
    stem.lineWidth = 1.8; stem.lineCapStyle = NSLineCapStyleRound; [stem stroke];
    [NSGraphicsContext restoreGraphicsState];
}

static void Base(NSInteger number, NSString *category) {
    Box(0,0,1080,1440,0,Paper());
    Text(@"双轨记  /  2ndJot",76,54,800,27,YES,Ink());
    Brand(944,52,48,Ink());
    Rule(126);
    Text(category,76,167,928,24,YES,Accent());
    Rule(1316);
    Text(@"macOS · Markdown · Obsidian",76,1341,800,23,NO,Muted());
    Text([NSString stringWithFormat:@"%02ld",(long)number],950,1341,54,23,YES,Ink());
    Text(number == 2 || number == 4 ? @"实机窗口 · macOS 27.2.1 · build 18 · 虚构示例"
                                  : @"功能图解 · 虚构示例",76,1382,928,20,NO,Muted());
}
static void Step(NSString *n, NSString *title, NSString *body, CGFloat y) {
    Frost(76,y,928,180,22,NO);
    Text(n,108,y+36,100,n.length > 2 ? 26 : 44,YES,Accent());
    Text(title,222,y+27,740,36,YES,Ink());
    Text(body,222,y+89,730,25,NO,Muted());
}
static void Card(NSInteger n) {
    NSArray *labels = @[@"工作到一半，灵感先记", @"从灵感到笔记", @"文件留在自己的库里",
                        @"留在桌面，稍后处理", @"先说清楚语音这件事", @"第一次公开分享"];
    Base(n,labels[n-1]);
    if (n == 1) {
        Text(@"主线继续，\n灵感先记。",76,245,928,86,YES,Ink());
        Text(@"双轨记",76,551,640,140,YES,Ink());
        Text(@"2ndJot",82,748,630,32,NO,Muted());
        AppIcon(786,566,208);
        Text(@"工作到一半，把突然想到的先记下。",76,827,928,31,NO,Ink());
        Frost(76,928,928,180,24,YES);
        Text(@"回车 / 软盘 → 本地 Markdown",118,963,820,39,YES,LightInk());
        Text(@"图钉 → 留在桌面，稍后处理",118,1032,820,30,NO,LightInk());
        Text(@"快捷键呼出 · 原生输入法输入 · 保存到 Obsidian",76,1162,928,27,NO,Muted());
    } else if (n == 2) {
        Text(@"突然想到一句话，\n先记下来。",76,245,928,76,YES,Ink());
        Text(@"默认 ⌃⇧Space 呼出，也可以自定义。",76,503,928,27,NO,Muted());
        Screenshot(QuickScreenshot,76,570,928);
        Rule(941);
        Floppy(83,987,36,Accent());
        Text(@"回车 / 软盘",144,976,850,34,YES,Ink());
        Text(@"存成库里的一份 .md 文件",144,1034,850,29,NO,Muted());
        Pin(83,1150,36,Accent());
        Text(@"图钉",144,1139,850,34,YES,Ink());
        Text(@"留在桌面，稍后处理",144,1197,850,29,NO,Muted());
    } else if (n == 3) {
        Text(@"一条灵感，\n一份 Markdown。",76,245,928,80,YES,Ink());
        Frost(76,547,928,470,24,YES);
        Text(@"示例笔记 · UTF-8",118,590,730,25,YES,C(0xE0E7EF));
        Floppy(918,588,32,LightInk());
        Text(@"2026-11-17 09.30.00.md",118,661,820,36,YES,LightInk());
        Text(@"先把这个点子记下。\n等手头的事做完，再展开。",118,768,820,42,NO,LightInk());
        Text(@"写入你选择的 Obsidian 库文件夹。\n文件在自己手里，之后再慢慢整理。",76,1081,928,34,NO,Ink());
        Text(@"虚构笔记示例 · 同步由 Obsidian 自行控制",76,1220,928,24,NO,Muted());
    } else if (n == 4) {
        Text(@"先留在桌面，\n等手头的事做完。",76,245,928,76,YES,Ink());
        Screenshot(StickyScreenshot,76,547,928);
        Text(@"左上角换成图钉，可以按住拖动。",76,959,928,32,YES,Ink());
        Text(@"支持多张、置顶或置底、调整大小。\n修改自动保存在本机，重启后恢复。",76,1030,928,29,NO,Ink());
        Text(@"回车换行 · ⌘ 回车另存为 Markdown",76,1173,928,31,YES,Accent());
        Text(@"钉成便签不会直接生成 .md 文件。",76,1235,928,25,NO,Muted());
    } else if (n == 5) {
        Text(@"语音来自\n你正在用的输入法。",76,245,928,76,YES,Ink());
        Step(@"输入法",@"将语音转成文字",@"是否支持语音，由具体输入法决定。",550);
        Step(@"双轨记",@"接收文字并保存",@"双轨记本身不录音，不提供语音识别。",754);
        Text(@"普通文字也能直接输入。\n不修改输入法配置。",76,1020,928,38,YES,Ink());
        Text(@"输入法的联网与隐私规则，以它自身说明为准。",76,1204,928,25,NO,Muted());
    } else {
        Text(@"第一次开源，\n欢迎来试试。",76,245,928,76,YES,Ink());
        Text(@"GitHub",76,537,928,29,NO,Muted());
        Text(@"SinyveZ / 2ndJot",76,594,928,54,YES,Ink());
        Rule(711);
        Text(@"Releases → arm64.zip",76,764,928,40,YES,Ink());
        Text(@"面向 Apple Silicon 的 Mac。\n安装前请看 README；当前版本尚未公证。",76,841,928,28,NO,Muted());
        Rule(985);
        Text(@"最想听到的反馈",76,1032,928,29,YES,Accent());
        Text(@"能不能装好，第一条笔记存下了吗？\n哪一步还不够顺手？",76,1102,928,34,NO,Ink());
        Text(@"MIT 开源 · 免费使用",76,1244,928,25,NO,Muted());
    }
}
static void Banner(void) {
    Box(0,0,1600,640,0,Paper());
    Text(@"双轨记",90,48,1000,136,YES,Ink());
    Text(@"2ndJot",101,237,1000,38,NO,Muted());
    Text(@"主线继续，灵感先记。",98,323,1100,59,YES,Ink());
    Text(@"回车 / 软盘 → 本地 Markdown / Obsidian\n图钉 → 桌面便签，稍后处理",101,427,1070,30,NO,Muted());
    AppIcon(1210,74,290);
    Box(100,541,1400,1,0,C(0xDCE2E9));
    Text(@"macOS  /  Markdown  /  Desktop notes",101,571,1000,25,NO,Muted());
    Text(@"功能图解 · 非真实截图",1180,575,320,20,NO,Muted());
}

static void Workflow(BOOL english) {
    Box(0,0,1600,720,0,Paper());
    Text(english ? @"A Markdown note, or a desktop sticky." : @"存为 Markdown，或留在桌面。",
         70,54,1460,49,YES,Ink());
    Text(english ? @"Quick capture" : @"快捷输入框",70,183,690,28,YES,Accent());
    Text(english ? @"Desktop sticky" : @"桌面便签",840,183,690,28,YES,Accent());
    Screenshot(english ? QuickEnglishScreenshot : QuickScreenshot,70,257,690);
    Screenshot(english ? StickyEnglishScreenshot : StickyScreenshot,840,257,690);
    Text(english ? @"Return / disk → Markdown in Obsidian" : @"回车 / 软盘 → 存入 Obsidian 库",
         70,565,690,27,NO,Ink());
    Text(english ? @"Pin → A sticky note, saved locally" : @"图钉 → 独立便签，修改自动保存",
         840,565,690,27,NO,Ink());
    Text(english ? @"Actual windows · macOS 27.2.1 · build 18 · English UI · fictional text"
                 : @"真实窗口 · macOS 27.2.1 · build 18 · 虚构示例正文",
         70,653,1460,22,NO,Muted());
}

static void Render(NSString *path, NSInteger w, NSInteger h, void (^draw)(void)) {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:w pixelsHigh:h
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace
        bytesPerRow:w*4 bitsPerPixel:32];
    NSGraphicsContext *raw = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    CGContextRef cg = raw.CGContext;
    CGContextTranslateCTM(cg,0,h); CGContextScaleCTM(cg,1,-1);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:cg flipped:YES]];
    CanvasSize = NSMakeSize(w,h);
    draw();
    [NSGraphicsContext restoreGraphicsState];
    NSData *data = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (![data writeToFile:path atomically:YES]) {
        fprintf(stderr,"Cannot write %s\n",path.UTF8String); exit(1);
    }
}
int main(int argc,const char *argv[]) {
    @autoreleasepool {
        if (![YSBrandImage(NSMakeSize(24,24)).accessibilityDescription containsString:@"双轨记"]) {
            fputs("Wait for the approved 2ndJot mark in src/YSBrandMark.h before rendering.\n",stderr);
            return 1;
        }
        NSString *folder = argc > 1 ? @(argv[1]) : @"docs/media";
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        QuickScreenshot = [[NSImage alloc] initWithContentsOfFile:[folder stringByAppendingPathComponent:@"quick-capture.png"]];
        StickyScreenshot = [[NSImage alloc] initWithContentsOfFile:[folder stringByAppendingPathComponent:@"desktop-sticky.png"]];
        QuickEnglishScreenshot = [[NSImage alloc] initWithContentsOfFile:[folder stringByAppendingPathComponent:@"quick-capture.en.png"]];
        StickyEnglishScreenshot = [[NSImage alloc] initWithContentsOfFile:[folder stringByAppendingPathComponent:@"desktop-sticky.en.png"]];
        if (!QuickScreenshot || !StickyScreenshot || !QuickEnglishScreenshot || !StickyEnglishScreenshot) {
            fputs("Missing native window captures: quick-capture.png / desktop-sticky.png\n",stderr);
            return 1;
        }
        Render([folder stringByAppendingPathComponent:@"github-banner.png"],1600,640,^{Banner();});
        Render([folder stringByAppendingPathComponent:@"github-social-preview.png"],1280,640,^{
            Box(0,0,1280,640,0,Paper());
            AppIcon(82,130,240);
            Text(@"2ndJot",390,172,810,74,YES,Ink());
            Text(@"Stay on track.\nJot it down.",390,284,810,44,NO,Ink());
            Text(@"Markdown capture & desktop sticky notes for macOS",82,497,1116,31,NO,Muted());
            Text(@"双轨记",82,566,1116,26,NO,Muted());
        });
        Render([folder stringByAppendingPathComponent:@"workflow-preview.png"],1600,720,^{Workflow(NO);});
        Render([folder stringByAppendingPathComponent:@"workflow-preview.en.png"],1600,720,^{Workflow(YES);});
        for (NSInteger n=1;n<=6;n++) {
            Render([folder stringByAppendingPathComponent:[NSString stringWithFormat:@"xhs-%02ld.png",(long)n]],1080,1440,^{Card(n);});
        }
        Render([folder stringByAppendingPathComponent:@"contact-sheet.png"],1080,960,^{
            Box(0,0,1080,960,0,Paper());
            for (NSInteger n=1;n<=6;n++) {
                [NSGraphicsContext saveGraphicsState];
                CGContextRef cg = NSGraphicsContext.currentContext.CGContext;
                CGContextTranslateCTM(cg,((n-1)%3)*360,((n-1)/3)*480);
                CGContextScaleCTM(cg,1.0/3,1.0/3);
                // Card coordinates remain full-size inside the scaled contact-sheet cell.
                CanvasSize = NSMakeSize(1080,1440);
                Card(n);
                [NSGraphicsContext restoreGraphicsState];
            }
        });
        printf("Rendered 11 PNGs; validated %lu text blocks: %s\n",(unsigned long)TextBlocks,folder.UTF8String);
    }
    return 0;
}
