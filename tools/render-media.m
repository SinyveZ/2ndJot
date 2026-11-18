// Editorial layouts with original brand vectors and unchanged native window
// captures. The Xiaohongshu carousel uses separately captured sample windows.
#import <Cocoa/Cocoa.h>
#import "../src/YSBrandMark.h"
#import "../src/YSBrandIcon.h"

static NSSize CanvasSize;
static NSUInteger TextBlocks;
static NSImage *QuickScreenshot, *StickyScreenshot, *QuickEnglishScreenshot, *StickyEnglishScreenshot;
static NSImage *LaunchCapture, *LaunchNext, *LaunchOther;

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

static void DrawWindow(NSImage *image, CGFloat x, CGFloat y, CGFloat width, CGFloat cornerRadius) {
    NSSize size = image.size;
    NSRect frame = NSMakeRect(x,y,width,width*size.height/size.width);
    [NSGraphicsContext saveGraphicsState];
    [YSG3RoundedRect(frame,cornerRadius) addClip];
    NSGraphicsContext.currentContext.imageInterpolation = NSImageInterpolationHigh;
    [image drawInRect:frame
            fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1
      respectFlipped:YES hints:nil];
    [NSGraphicsContext restoreGraphicsState];
}

static void Screenshot(NSImage *image, CGFloat x, CGFloat y, CGFloat width) {
    DrawWindow(image, x, y, width, 18 * width / image.size.width);
}

static void LaunchWindow(NSImage *image, CGFloat x, CGFloat y, CGFloat width) {
    // Native launch captures have two pixels per AppKit point.
    DrawWindow(image, x, y, width, 36 * width / image.representations.firstObject.pixelsWide);
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

static void DarkPaper(void) {
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:C(0x304052) endingColor:C(0x101722)];
    [gradient drawInRect:NSMakeRect(0,0,1080,1440) angle:70];
    Brand(542,230,690,[C(0xB3CAEA) colorWithAlphaComponent:0.10]);
}

static void LaunchFooter(NSInteger number, NSString *label, BOOL dark) {
    Box(76,1307,928,1,0,dark ? C(0x4C5E73) : C(0xCED7E1));
    Text(label,76,1335,850,23,NO,dark ? C(0xB7C8DB) : Accent());
    Text([NSString stringWithFormat:@"%02ld",(long)number],952,1335,52,23,YES,dark ? LightInk() : Ink());
}

static void LaunchHeader(NSString *category) {
    Box(0,0,1080,1440,0,C(0xF1F4F8));
    Brand(71,57,43,Accent());
    Text(@"双轨记  /  2ndJot",125,65,810,29,YES,Ink());
    Rule(138);
    Text(category,76,172,928,27,YES,Accent());
}

static void LaunchCover(void) {
    DarkPaper();
    Brand(68,177,53,C(0xC2D6F0));
    Text(@"双轨记  /  2ndJot",131,186,870,32,YES,LightInk());
    Text(@"AI 还在跑，",71,280,930,102,YES,LightInk());
    Text(@"想法先记下",72,406,936,110,YES,C(0xD4E4FA));
    AppIcon(821,407,168);
    Text(@"做 vibe coding 时，给下一步留个位置。",77,590,928,36,NO,C(0xC8D6E8));
    LaunchWindow(LaunchCapture,76,705,928);
    Floppy(77,1064,33,C(0xBDCEE6));
    Text(@"存为 Markdown",127,1049,393,38,YES,LightInk());
    Box(535,1056,1,54,0,C(0x51657B));
    Pin(583,1064,33,C(0xBDCEE6));
    Text(@"钉在桌面",632,1049,372,38,YES,LightInk());
    Text(@"主线继续，灵感先记。",76,1180,928,30,NO,C(0xBDCEE6));
    LaunchFooter(1,@"macOS 速记 · 真实窗口，示例文字",YES);
}

static void Card(NSInteger n) {
    if (n == 1) {
        LaunchCover();
    } else if (n == 2) {
        LaunchHeader(@"做双轨记的起因");
        Text(@"工具在执行，\n思路已经往前走。",76,237,928,76,YES,Ink());
        Text(@"有时工具还忙，有时得顾着额度，\n也有时注意力只够先做一件事。",76,475,928,35,NO,Ink());
        LaunchWindow(LaunchCapture,76,646,928);
        Text(@"按 ⌃⇧Space 呼出小窗",76,1002,928,40,YES,Ink());
        Text(@"把这轮之后要做的事先记下，\n等合适的时候再发给 AI。",76,1080,928,34,NO,Accent());
        LaunchFooter(2,@"真实快捷输入框 · 示例文字",NO);
    } else if (n == 3) {
        LaunchHeader(@"去向一  /  存为本地文档");
        Text(@"回车存盘，\n想法进到库里。",76,237,928,76,YES,Ink());
        Text(@"写入所选 Obsidian 库里的独立 .md 文件。",76,476,928,34,NO,Ink());
        Frost(76,588,928,405,35,YES);
        Floppy(913,636,35,LightInk());
        Text(@"Markdown 文件示例",116,627,760,26,YES,C(0xE0E7EF));
        Text(@"2026-11-18 14.30.00.md",116,697,836,37,YES,LightInk());
        Text(@"等这轮跑完，\n再补上空状态的提示。",116,788,850,43,NO,LightInk());
        Text(@"保存后可以自动打开 Obsidian，\n也可以等有空再回库里整理。",76,1060,928,34,NO,Accent());
        LaunchFooter(3,@"虚构文件示例 · 笔记保存在本机",NO);
    } else if (n == 4) {
        LaunchHeader(@"去向二  /  钉在桌面");
        Text(@"多张便签，\n可以同时留在桌面。",76,237,928,73,YES,Ink());
        Text(@"下一步要改的一张，另一个想法的一张。",76,469,928,30,NO,Accent());
        LaunchWindow(LaunchNext,76,552,840);
        LaunchWindow(LaunchOther,164,894,840);
        Text(@"每张的位置、大小和置顶／置底会自动记住。",76,1227,928,28,NO,Ink());
        LaunchFooter(4,@"两张实机便签的组合排版 · 示例文字",NO);
    } else if (n == 5) {
        LaunchHeader(@"输入与设置");
        Text(@"用熟悉的方式\n把想法记下来。",76,237,928,76,YES,Ink());
        Rule(520);
        Text(@"快捷键",76,565,220,30,YES,Accent());
        Text(@"默认 ⌃⇧Space 呼出",332,550,672,41,YES,Ink());
        Text(@"可以在设置里换成自己的组合。",332,618,672,30,NO,Muted());
        Rule(710);
        Text(@"输入法",76,755,220,30,YES,Accent());
        Text(@"用原来的输入法",332,740,672,41,YES,Ink());
        Text(@"输入法支持语音时，也可以听写。",332,808,672,30,NO,Muted());
        Rule(900);
        Text(@"界面语言",76,945,220,30,YES,Accent());
        Text(@"简体中文 / English",332,930,672,41,YES,Ink());
        Text(@"在设置中随时切换。",332,998,672,30,NO,Muted());
        LaunchFooter(5,@"功能图解",NO);
    } else {
        DarkPaper();
        Brand(71,115,46,C(0xC2D6F0));
        Text(@"双轨记  /  2ndJot",129,123,875,31,YES,LightInk());
        Text(@"我的第一个\n开源小工具",76,244,928,82,YES,LightInk());
        Text(@"在 GitHub 搜索",76,542,928,30,NO,C(0xBDCEE6));
        Text(@"SinyveZ/2ndJot",76,602,928,70,YES,LightInk());
        Box(76,735,928,1,0,C(0x4C5E73));
        Text(@"Releases → arm64.zip",76,783,928,44,YES,LightInk());
        Text(@"Apple Silicon Mac · MIT 开源\n首次打开说明见仓库 README。",76,865,928,34,NO,C(0xBDCEE6));
        Text(@"你能顺手存下第一条想法吗？",76,1093,928,40,YES,LightInk());
        Text(@"欢迎告诉我哪一步还不够顺手。",76,1160,928,30,NO,C(0xBDCEE6));
        LaunchFooter(6,@"首次发布下载指引",YES);
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
        LaunchCapture = [[NSImage alloc] initWithContentsOfFile:[folder stringByAppendingPathComponent:@"launch-quick-capture.png"]];
        LaunchNext = [[NSImage alloc] initWithContentsOfFile:[folder stringByAppendingPathComponent:@"launch-sticky-next.png"]];
        LaunchOther = [[NSImage alloc] initWithContentsOfFile:[folder stringByAppendingPathComponent:@"launch-sticky-other.png"]];
        if (!QuickScreenshot || !StickyScreenshot || !QuickEnglishScreenshot || !StickyEnglishScreenshot ||
            !LaunchCapture || !LaunchNext || !LaunchOther) {
            fputs("Missing native window captures in docs/media. See docs/media/README.md.\n",stderr);
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
