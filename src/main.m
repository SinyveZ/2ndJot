#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
#import <QuartzCore/QuartzCore.h>
#import <ServiceManagement/ServiceManagement.h>
#import <objc/message.h>
#import "YSLocalization.h"
#import "YSPanelChrome.h"
#import "YSBrandMark.h"
#import "YSG3Corners.h"

static NSString *const DefaultHotkeyKeyLabel = @"Space";
static NSString *const LegacyFolderName = @"语音速记";
#define DefaultHintText YSL(@"回车或软盘存盘 · 图钉变便签")
static const CGKeyCode DefaultHotkeyKeyCode = 49;
static const NSEventModifierFlags DefaultHotkeyModifiers = NSEventModifierFlagControl | NSEventModifierFlagShift;
static const CGFloat PanelWidth = 480.0;
static const CGFloat PanelMinimumHeight = 154.0;
static const CGFloat PanelMaximumHeight = 460.0;
static const CGFloat PanelCornerRadius = 18.0;
static const CGFloat DragHandleDiameter = PanelCornerRadius * 2.0;
static const CGFloat DragHandleInset = 8.0;
static const CGFloat PanelHeaderHeight = 52.0;
static const CGFloat StickyMinimumWidth = 280.0;
static const CGFloat StickyMinimumHeight = 180.0;
static const OSType YSHotKeySignature = 'YSHK';

static NSString *const LegacyDefaultsSuiteName = @"com.sinyve.VoiceNoteBridge";
static NSString *const DefaultsMigrationMarker = @"prefsMigratedFromVoiceNoteBridge";

// Finder/Launch Services may reopen a preview without its shell environment.
// Keep the disposable app tied to its fixture even in that launch path.
static void ConfigurePreviewEnvironment(void) {
    NSString *directory = [NSBundle.mainBundle objectForInfoDictionaryKey:@"YinSuPreviewDirectory"];
    if (![directory isKindOfClass:NSString.class] || !directory.isAbsolutePath) return;
    setenv("YIN_SU_ISOLATED", "1", 1);
    NSString *language = [NSBundle.mainBundle objectForInfoDictionaryKey:@"YinSuPreviewLanguage"];
    if ([language isEqualToString:@"en"] || [language isEqualToString:@"zh-Hans"]) {
        if (!getenv("YIN_SU_UI_LANGUAGE")) setenv("YIN_SU_UI_LANGUAGE", language.UTF8String, 1);
    }
    NSDictionary *fallbacks = @{
        @"VOICE_NOTE_FOLDER_PATH": [directory stringByAppendingPathComponent:@"Demo Vault/Notes"],
        @"YIN_SU_STICKY_STORE": [directory stringByAppendingPathComponent:@"stickies.plist"],
        @"YIN_SU_EDITOR_DRAFT": [directory stringByAppendingPathComponent:@"editor-draft.txt"],
        @"VOICE_NOTE_NO_OPEN": @"1", @"VOICE_NOTE_NO_CLIPBOARD": @"1",
    };
    for (NSString *key in fallbacks) {
        if (!getenv(key.UTF8String)) setenv(key.UTF8String, [fallbacks[key] UTF8String], 1);
    }
}

// Isolated runs use a separate preferences domain, never the user's settings.
static NSString *YSPreferencesDomain;
static NSUserDefaults *YSPreferences(void) {
    static NSUserDefaults *preferences;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ([[NSProcessInfo processInfo].environment[@"YIN_SU_ISOLATED"] boolValue]) {
            YSPreferencesDomain = [@"com.sinyve.YinSu.preview." stringByAppendingString:NSUUID.UUID.UUIDString];
            preferences = [[NSUserDefaults alloc] initWithSuiteName:YSPreferencesDomain];
        } else {
            YSPreferencesDomain = NSBundle.mainBundle.bundleIdentifier ?: @"com.sinyve.YinSu";
            preferences = [NSUserDefaults standardUserDefaults];
        }
    });
    return preferences;
}

typedef struct {
    NSInteger style;
    BOOL interactive;
    CGFloat tintStrength;
} YSGlassAppearance;

static YSGlassAppearance DefaultGlassAppearance(BOOL sticky) {
    return sticky ? (YSGlassAppearance){0, NO, 0.50} : (YSGlassAppearance){0, YES, 0.10};
}

static NSString *GlassKey(BOOL sticky, NSString *suffix) {
    return [(sticky ? @"stickyGlass" : @"quickGlass") stringByAppendingString:suffix];
}

static void ConfigureGlassPreferences(NSUserDefaults *defaults, NSString *domain) {
    // Run before registering defaults: explicit legacy values belong to quick capture.
    // Never copy the old shared appearance into the new sticky-note profile.
    NSDictionary *legacyStyle = @{@"glassStyle": @"quickGlassStyle", @"glassInteractive": @"quickGlassInteractive"};
    NSDictionary *stored = [defaults persistentDomainForName:domain] ?: @{};
    BOOL hasLegacyAppearance = stored[@"glassStyle"] || stored[@"glassInteractive"] || stored[@"glassTintEnabled"];
    for (NSString *key in legacyStyle) {
        if (hasLegacyAppearance && stored[legacyStyle[key]] == nil)
            [defaults setObject:stored[key] ?: ([key isEqualToString:@"glassStyle"] ? @0 : @YES) forKey:legacyStyle[key]];
    }
    if (hasLegacyAppearance && stored[@"quickGlassTintStrength"] == nil)
        [defaults setDouble:[stored[@"glassTintEnabled"] boolValue] ? 0.28 : 0 forKey:@"quickGlassTintStrength"];
    YSGlassAppearance quick = DefaultGlassAppearance(NO), sticky = DefaultGlassAppearance(YES);
    [defaults registerDefaults:@{
        @"quickGlassStyle": @(quick.style), @"quickGlassInteractive": @(quick.interactive), @"quickGlassTintStrength": @(quick.tintStrength),
        @"stickyGlassStyle": @(sticky.style), @"stickyGlassInteractive": @(sticky.interactive), @"stickyGlassTintStrength": @(sticky.tintStrength),
    }];
}

static YSGlassAppearance ReadGlassAppearance(NSUserDefaults *defaults, BOOL sticky) {
    YSGlassAppearance appearance = DefaultGlassAppearance(sticky);
    appearance.style = MAX(0, MIN(1, [defaults integerForKey:GlassKey(sticky, @"Style")]));
    appearance.interactive = [defaults boolForKey:GlassKey(sticky, @"Interactive")];
    CGFloat strength = [defaults doubleForKey:GlassKey(sticky, @"TintStrength")];
    if (isfinite(strength)) appearance.tintStrength = MAX(0, MIN(0.60, strength));
    return appearance;
}

static void WriteGlassAppearance(NSUserDefaults *defaults, BOOL sticky, YSGlassAppearance appearance) {
    [defaults setInteger:appearance.style forKey:GlassKey(sticky, @"Style")];
    [defaults setBool:appearance.interactive forKey:GlassKey(sticky, @"Interactive")];
    [defaults setDouble:appearance.tintStrength forKey:GlassKey(sticky, @"TintStrength")];
}

static void YSLog(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [formatter stringFromDate:[NSDate date]], message];
    FILE *file = fopen("/tmp/YinSu.log", "a");
    if (file) {
        fputs(line.UTF8String, file);
        fclose(file);
    }
}

static NSError *YSError(NSUInteger code, NSString *description) {
    return [NSError errorWithDomain:@"com.sinyve.YinSu"
                               code:(NSInteger)code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

// 从「语音速记」时代（com.sinyve.VoiceNoteBridge）迁移用户设置到新域。
// 只复制新域里还没有的键，迁移过一次后打标记，之后不再触碰。
static void MigrateLegacyPreferences(void) {
    if ([[NSProcessInfo processInfo].environment[@"YIN_SU_ISOLATED"] boolValue]) return;
    NSUserDefaults *defaults = YSPreferences();
    if ([defaults boolForKey:DefaultsMigrationMarker]) return;
    NSUserDefaults *legacy = [[NSUserDefaults alloc] initWithSuiteName:LegacyDefaultsSuiteName];
    NSDictionary *legacyValues = [legacy dictionaryRepresentation];
    NSUInteger migrated = 0;
    for (NSString *key in legacyValues) {
        if ([key isEqualToString:DefaultsMigrationMarker]) continue;
        if ([defaults objectForKey:key] != nil) continue;
        [defaults setObject:legacyValues[key] forKey:key];
        migrated++;
    }
    [defaults setBool:YES forKey:DefaultsMigrationMarker];
    [defaults synchronize];
    if (migrated > 0) YSLog(@"migrated %lu preferences from %@", (unsigned long)migrated, LegacyDefaultsSuiteName);
}

static NSURL *ConfiguredNotesFolder(void) {
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    NSUserDefaults *defaults = YSPreferences();
    NSString *path = environment[@"VOICE_NOTE_FOLDER_PATH"];
    if (path.length == 0) path = [defaults stringForKey:@"notesFolderPath"];
    if (path.length == 0) {
        NSString *vaultPath = environment[@"VOICE_NOTE_VAULT"];
        if (vaultPath.length == 0) vaultPath = [defaults stringForKey:@"vaultPath"];
        if (vaultPath.length == 0) vaultPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/SO FAR"];
        NSString *folderName = environment[@"VOICE_NOTE_FOLDER"];
        if (folderName.length == 0) folderName = [defaults stringForKey:@"folderName"];
        if (folderName.length == 0) folderName = LegacyFolderName;
        path = [vaultPath stringByAppendingPathComponent:folderName];
    }
    return [[NSURL fileURLWithPath:path] URLByStandardizingPath];
}

static NSURL *StickyStoreURL(void) {
    NSString *override = [[NSProcessInfo processInfo] environment][@"YIN_SU_STICKY_STORE"];
    if (override.length) return [NSURL fileURLWithPath:override];
    NSURL *support = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                           inDomain:NSUserDomainMask
                                                  appropriateForURL:nil
                                                             create:YES
                                                              error:nil];
    return [[support URLByAppendingPathComponent:@"YinSu" isDirectory:YES]
        URLByAppendingPathComponent:@"stickies.plist"];
}

static NSURL *EditorDraftURL(void) {
    NSString *override = [[NSProcessInfo processInfo] environment][@"YIN_SU_EDITOR_DRAFT"];
    if (override.length) return [NSURL fileURLWithPath:override];
    return [StickyStoreURL().URLByDeletingLastPathComponent URLByAppendingPathComponent:@"editor-draft.txt"];
}

static NSDictionary *ReadStickyStore(void) {
    NSData *data = [NSData dataWithContentsOfURL:StickyStoreURL()];
    if (!data) return nil;
    id store = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:nil];
    return [store isKindOfClass:[NSDictionary class]] ? store : nil;
}

static NSURL *ObsidianVaultRootForFolder(NSURL *folderURL) {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *candidate = [folderURL URLByStandardizingPath];
    while (candidate.path.length > 1) {
        BOOL isDirectory = NO;
        NSURL *marker = [candidate URLByAppendingPathComponent:@".obsidian" isDirectory:YES];
        if ([manager fileExistsAtPath:marker.path isDirectory:&isDirectory] && isDirectory) {
            return candidate;
        }
        candidate = [candidate URLByDeletingLastPathComponent];
    }
    return nil;
}

static NSURL *WriteNote(NSString *rawText, NSURL *notesFolderURL, NSError **error) {
    NSString *text = [rawText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) {
        if (error) *error = YSError(1, YSL(@"没有收到语音识别文字"));
        return nil;
    }

    NSURL *folderURL = [notesFolderURL URLByStandardizingPath];
    NSError *directoryError = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:folderURL
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&directoryError]) {
        if (error) *error = directoryError;
        return nil;
    }

    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd HH.mm.ss";
    });
    NSString *stamp = [formatter stringFromDate:[NSDate date]];
    NSURL *noteURL = [folderURL URLByAppendingPathComponent:[stamp stringByAppendingPathExtension:@"md"]];
    NSInteger suffix = 2;
    while ([[NSFileManager defaultManager] fileExistsAtPath:noteURL.path]) {
        NSString *name = [NSString stringWithFormat:@"%@-%ld.md", stamp, (long)suffix++];
        noteURL = [folderURL URLByAppendingPathComponent:name];
    }

    NSString *content = [text hasSuffix:@"\n"] ? text : [text stringByAppendingString:@"\n"];
    NSError *writeError = nil;
    if (![content writeToURL:noteURL atomically:YES encoding:NSUTF8StringEncoding error:&writeError]) {
        if (error) *error = writeError;
        return nil;
    }
    NSString *verified = [NSString stringWithContentsOfURL:noteURL encoding:NSUTF8StringEncoding error:&writeError];
    if (![verified isEqualToString:content]) {
        if (error) *error = writeError ?: YSError(2, YSL(@"保存后的文件校验失败，请重试。原文仍保留。"));
        return nil;
    }
    return noteURL;
}

static NSURL *ObsidianURLForNote(NSURL *noteURL, NSURL *vaultURL) {
    NSString *prefix = [vaultURL.path stringByAppendingString:@"/"];
    NSString *relativePath = [noteURL.path hasPrefix:prefix]
        ? [noteURL.path substringFromIndex:prefix.length]
        : noteURL.lastPathComponent;
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = @"obsidian";
    components.host = @"open";
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"vault" value:vaultURL.lastPathComponent],
        [NSURLQueryItem queryItemWithName:@"file" value:relativePath],
    ];
    return components.URL;
}

static NSEventModifierFlags SupportedHotkeyModifiers(void) {
    return NSEventModifierFlagControl | NSEventModifierFlagOption |
           NSEventModifierFlagShift | NSEventModifierFlagCommand;
}

static UInt32 CarbonModifiersForFlags(NSEventModifierFlags flags) {
    UInt32 carbon = 0;
    if (flags & NSEventModifierFlagCommand) carbon |= cmdKey;
    if (flags & NSEventModifierFlagOption) carbon |= optionKey;
    if (flags & NSEventModifierFlagControl) carbon |= controlKey;
    if (flags & NSEventModifierFlagShift) carbon |= shiftKey;
    return carbon;
}

static NSString *ModifierSymbolsForFlags(NSEventModifierFlags flags) {
    NSMutableString *symbols = [NSMutableString string];
    if (flags & NSEventModifierFlagControl) [symbols appendString:@"⌃"];
    if (flags & NSEventModifierFlagOption) [symbols appendString:@"⌥"];
    if (flags & NSEventModifierFlagShift) [symbols appendString:@"⇧"];
    if (flags & NSEventModifierFlagCommand) [symbols appendString:@"⌘"];
    return symbols;
}

static NSString *KeyLabelForKeyCode(CGKeyCode keyCode, NSString *typedCharacters) {
    switch (keyCode) {
        case 49: return @"Space";
        case 36: return @"Return";
        case 48: return @"Tab";
        case 53: return @"Esc";
        case 51: return @"Delete";
        case 117: return @"Forward Delete";
        case 123: return @"←";
        case 124: return @"→";
        case 125: return @"↓";
        case 126: return @"↑";
        case 116: return @"Page Up";
        case 121: return @"Page Down";
        case 115: return @"Home";
        case 119: return @"End";
        case 122: return @"F1";
        case 120: return @"F2";
        case 99: return @"F3";
        case 118: return @"F4";
        case 96: return @"F5";
        case 97: return @"F6";
        case 98: return @"F7";
        case 100: return @"F8";
        case 101: return @"F9";
        case 109: return @"F10";
        case 103: return @"F11";
        case 111: return @"F12";
        default: break;
    }
    if (typedCharacters.length > 0) {
        NSString *label = [[typedCharacters substringToIndex:1] uppercaseString];
        return label.length ? label : typedCharacters;
    }
    return [NSString stringWithFormat:@"Key %u", (unsigned int)keyCode];
}

static NSString *HotkeyDisplayString(CGKeyCode keyCode, NSEventModifierFlags modifiers, NSString *keyLabel) {
    NSString *label = keyLabel.length ? keyLabel : KeyLabelForKeyCode(keyCode, nil);
    return [ModifierSymbolsForFlags(modifiers) stringByAppendingString:label];
}

static NSInteger SystemHotkeyConflictID(CGKeyCode keyCode, NSEventModifierFlags modifiers) {
    NSDictionary *hotkeys = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("AppleSymbolicHotKeys"),
                                                                        CFSTR("com.apple.symbolichotkeys")));
    if (![hotkeys isKindOfClass:[NSDictionary class]]) {
        NSURL *plistURL = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.apple.symbolichotkeys.plist"]];
        NSDictionary *root = [NSDictionary dictionaryWithContentsOfURL:plistURL];
        hotkeys = root[@"AppleSymbolicHotKeys"];
    }
    if (![hotkeys isKindOfClass:[NSDictionary class]]) return 0;

    NSEventModifierFlags wanted = modifiers & SupportedHotkeyModifiers();
    for (id key in hotkeys) {
        NSDictionary *entry = hotkeys[key];
        if (![entry isKindOfClass:[NSDictionary class]] || ![entry[@"enabled"] boolValue]) continue;
        NSDictionary *value = entry[@"value"];
        if (![value isKindOfClass:[NSDictionary class]]) continue;
        if (value[@"type"] && ![value[@"type"] isEqualToString:@"standard"]) continue;
        NSArray *parameters = value[@"parameters"];
        if (![parameters isKindOfClass:[NSArray class]] || parameters.count < 3) continue;
        NSInteger candidateKey = [parameters[1] integerValue];
        NSEventModifierFlags candidateModifiers = [parameters[2] unsignedIntegerValue] & SupportedHotkeyModifiers();
        if ((CGKeyCode)candidateKey == keyCode && candidateModifiers == wanted) {
            return [key integerValue];
        }
    }
    return 0;
}

static NSString *SystemHotkeyConflictDescription(NSInteger conflictID) {
    NSString *name = nil;
    switch (conflictID) {
        case 60: name = YSL(@"切换上一个输入源"); break;
        case 61: name = YSL(@"切换下一个输入源"); break;
        case 64: name = YSL(@"聚焦搜索"); break;
        case 65: name = YSL(@"访达搜索"); break;
        default: break;
    }
    if (name.length > 0) {
        return [NSString stringWithFormat:YSL(@"已被 macOS 用于“%@”"), name];
    }
    return [NSString stringWithFormat:YSL(@"与 macOS 系统快捷键冲突（系统项 %ld）"), (long)conflictID];
}

static NSString *ReservedAppHotkeyReason(CGKeyCode keyCode, NSEventModifierFlags modifiers) {
    NSEventModifierFlags flags = modifiers & SupportedHotkeyModifiers();
    BOOL command = (flags & NSEventModifierFlagCommand) != 0;
    if (keyCode == 53) return YSL(@"Esc 用于取消输入");
    if (command && keyCode == 48) return YSL(@"Command+Tab 用于切换应用");
    if (command && keyCode == 43) return YSL(@"Command+, 用于打开设置");
    if (command && keyCode == 12) return YSL(@"Command+Q 用于退出应用");
    if (command && (flags & NSEventModifierFlagShift) && (keyCode == 20 || keyCode == 21 || keyCode == 23)) {
        return YSL(@"该组合已被 macOS 用作截屏快捷键");
    }
    if (command && (flags & NSEventModifierFlagControl) && keyCode == 12) {
        return YSL(@"Control+Command+Q 用于锁定屏幕");
    }
    if (command && (keyCode == 0 || keyCode == 6 || keyCode == 7 ||
                    keyCode == 8 || keyCode == 9)) {
        return YSL(@"该组合会覆盖常用的编辑快捷键");
    }
    if ((flags & (NSEventModifierFlagControl | NSEventModifierFlagCommand)) ==
        (NSEventModifierFlagControl | NSEventModifierFlagCommand) && keyCode == 49) {
        return YSL(@"Control+Command+Space 已被 macOS 用作表情与符号面板");
    }
    return nil;
}

static NSTextField *YSLabel(NSString *text, NSRect frame, NSFont *font, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.frame = frame;
    label.font = font;
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

static NSBox *YSSeparator(NSRect frame) {
    NSBox *box = [NSBox new];
    box.boxType = NSBoxSeparator;
    box.frame = frame;
    return box;
}

@interface YSSettingsCard : NSView
@end
@implementation YSSettingsCard
- (void)drawRect:(NSRect)dirtyRect {
    NSBezierPath *path = YSG3RoundedRect(NSInsetRect(self.bounds, 0.5, 0.5), 12);
    [[NSColor controlBackgroundColor] setFill];
    [path fill];
    [[[NSColor separatorColor] colorWithAlphaComponent:0.28] setStroke];
    path.lineWidth = 1;
    [path stroke];
}
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; self.needsDisplay = YES; }
@end

@interface YSFlippedView : NSView
@end
@implementation YSFlippedView
- (BOOL)isFlipped { return YES; }
@end

static NSTextField *YSHelp(NSString *text) {
    NSTextField *label = [NSTextField wrappingLabelWithString:text];
    label.font = [NSFont systemFontOfSize:11.5];
    label.textColor = [NSColor secondaryLabelColor];
    [label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    return label;
}

static NSStackView *YSStack(NSArray<NSView *> *views, NSUserInterfaceLayoutOrientation orientation, CGFloat spacing) {
    NSStackView *stack = [NSStackView stackViewWithViews:views];
    stack.orientation = orientation;
    stack.alignment = orientation == NSUserInterfaceLayoutOrientationVertical ? NSLayoutAttributeLeading : NSLayoutAttributeCenterY;
    stack.spacing = spacing;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    return stack;
}

static NSView *YSRow(NSString *title, NSView *control) {
    NSTextField *label = YSLabel(title, NSZeroRect, [NSFont systemFontOfSize:12], [NSColor secondaryLabelColor]);
    NSStackView *row = YSStack(@[label, control], NSUserInterfaceLayoutOrientationHorizontal, 12);
    [label.widthAnchor constraintEqualToConstant:[YSCurrentLanguage() isEqualToString:@"en"] ? 76 : 56].active = YES;
    [control setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    return row;
}

static NSView *YSSection(NSString *title, NSArray<NSView *> *rows) {
    NSView *card = [YSSettingsCard new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *heading = YSLabel(title, NSZeroRect, [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold], [NSColor labelColor]);
    NSStackView *stack = YSStack([@[heading] arrayByAddingObjectsFromArray:rows], NSUserInterfaceLayoutOrientationVertical, 12);
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
    ]];
    for (NSView *row in rows) [row.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    return card;
}

static NSView *YSSettingsPage(NSArray<NSView *> *sections) {
    NSScrollView *scroll = [NSScrollView new];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.scrollerStyle = NSScrollerStyleOverlay;
    YSFlippedView *document = [YSFlippedView new];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = document;
    NSStackView *stack = YSStack(sections, NSUserInterfaceLayoutOrientationVertical, 14);
    [document addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:document.trailingAnchor constant:-24],
        [stack.topAnchor constraintEqualToAnchor:document.topAnchor constant:16],
        [stack.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-24],
    ]];
    for (NSView *section in sections) [section.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    return scroll;
}

static NSButton *YSImageButton(NSImage *image, NSString *tooltip, id target, SEL action) {
    NSButton *button = [NSButton buttonWithImage:image target:target action:action];
    button.bordered = NO;
    button.imagePosition = NSImageOnly;
    button.imageScaling = NSImageScaleProportionallyDown;
    button.contentTintColor = [NSColor colorWithWhite:1 alpha:0.82];
    button.toolTip = tooltip;
    [button setAccessibilityLabel:tooltip];
    return button;
}

static NSButton *YSSymbolButton(NSString *symbolName, NSString *tooltip, id target, SEL action) {
    NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium];
    NSImage *image = [[NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:tooltip]
        imageWithSymbolConfiguration:configuration];
    return YSImageButton(image, tooltip, target, action);
}

static NSSegmentedControl *YSSegmentedControl(NSArray<NSString *> *labels,
                                               NSRect frame,
                                               id target,
                                               SEL action) {
    NSSegmentedControl *control = [[NSSegmentedControl alloc] initWithFrame:frame];
    control.segmentCount = labels.count;
    for (NSInteger index = 0; index < labels.count; index++) {
        [control setLabel:labels[index] forSegment:index];
        [control setWidth:0 forSegment:index];
    }
    control.segmentDistribution = NSSegmentDistributionFillEqually;
    control.trackingMode = NSSegmentSwitchTrackingSelectOne;
    control.target = target;
    control.action = action;
    control.selectedSegment = 0;
    return control;
}

static BOOL GlassAppearancesEqual(YSGlassAppearance left, YSGlassAppearance right) {
    return left.style == right.style && left.interactive == right.interactive && fabs(left.tintStrength - right.tintStrength) < 0.0001;
}

static BOOL SurfaceMatchesGlassAppearance(NSView *surface, NSView *content, YSGlassAppearance appearance) {
    if (@available(macOS 26.0, *)) {
        if ([surface isKindOfClass:NSGlassEffectView.class]) {
            NSGlassEffectView *glass = (NSGlassEffectView *)surface;
            CGFloat tint = glass.tintColor ? glass.tintColor.alphaComponent : 0;
            BOOL matches = glass.style == (appearance.style == 1 ? NSGlassEffectViewStyleClear : NSGlassEffectViewStyleRegular) &&
                fabs(tint - appearance.tintStrength) < 0.0001;
            if (@available(macOS 27.0, *)) {
                // Keep builds compatible with the macOS 26 SDK; this public property is new in 27.
                SEL getter = NSSelectorFromString(@"effectIsInteractive");
                if ([glass respondsToSelector:getter])
                    matches = matches && ((BOOL (*)(id, SEL))objc_msgSend)(glass, getter) == appearance.interactive;
            }
            return matches;
        }
    }
    return content.layer.backgroundColor && fabs(CGColorGetAlpha(content.layer.backgroundColor) - appearance.tintStrength) < 0.0001;
}

static NSUInteger CountMarkdownNotes(void) {
    NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:ConfiguredNotesFolder()
        includingPropertiesForKeys:nil options:0 error:nil];
    NSUInteger count = 0;
    for (NSURL *file in files) if ([file.pathExtension isEqualToString:@"md"]) count++;
    return count;
}

static BOOL ViewContainsIdentifier(NSView *view, NSString *identifier) {
    if ([view.accessibilityIdentifier isEqualToString:identifier]) return YES;
    for (NSView *child in view.subviews) if (ViewContainsIdentifier(child, identifier)) return YES;
    return NO;
}

static BOOL YSLocalizedSettingsFit(NSView *view) {
    if (view.isHidden) return YES;
    if ([view isKindOfClass:NSTextField.class]) {
        NSTextField *field = (NSTextField *)view;
        if (!field.editable && field.cell.wraps && field.stringValue.length) {
            NSRect text = [field.stringValue boundingRectWithSize:NSMakeSize(NSWidth(field.bounds), CGFLOAT_MAX)
                options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                attributes:@{NSFontAttributeName:field.font ?: [NSFont systemFontOfSize:12]}];
            if (NSHeight(field.bounds)+3 < ceil(NSHeight(text))) return NO;
        }
    } else if ([view isKindOfClass:NSButton.class] && ![view isKindOfClass:NSPopUpButton.class]) {
        NSButton *button = (NSButton *)view;
        if (button.title.length && button.imagePosition != NSImageOnly) {
            CGFloat width = [button.title sizeWithAttributes:@{NSFontAttributeName:button.font ?: [NSFont systemFontOfSize:13]}].width;
            if (width+12 > NSWidth(button.bounds)+1) return NO;
        }
    } else if ([view isKindOfClass:NSSegmentedControl.class]) {
        NSSegmentedControl *segments = (NSSegmentedControl *)view;
        CGFloat width = NSWidth(segments.bounds)/segments.segmentCount;
        for (NSInteger index=0; index<segments.segmentCount; index++) {
            CGFloat text = [[segments labelForSegment:index] sizeWithAttributes:@{NSFontAttributeName:segments.font ?: [NSFont systemFontOfSize:13]}].width;
            if (text+10 > width+1) return NO;
        }
    }
    for (NSView *child in view.subviews) if (!YSLocalizedSettingsFit(child)) return NO;
    return YES;
}

static void RunGlassPreferencesCheck(void) {
    NSString *suite = [@"com.sinyve.YinSu.glass-check." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    ConfigureGlassPreferences(defaults, suite);
    YSGlassAppearance quick = ReadGlassAppearance(defaults, NO), sticky = ReadGlassAppearance(defaults, YES);
    BOOL distinct = quick.style == 0 && fabs(quick.tintStrength - 0.10) < 0.0001 &&
        sticky.style == 0 && fabs(sticky.tintStrength - 0.50) < 0.0001;
    YSGlassAppearance chosen = {1, YES, 0.17};
    WriteGlassAppearance(defaults, YES, chosen);
    BOOL independent = GlassAppearancesEqual(ReadGlassAppearance(defaults, NO), quick);
    [defaults synchronize];
    NSUserDefaults *reloaded = [[NSUserDefaults alloc] initWithSuiteName:suite];
    ConfigureGlassPreferences(reloaded, suite);
    BOOL retained = GlassAppearancesEqual(ReadGlassAppearance(reloaded, YES), chosen) &&
        GlassAppearancesEqual(ReadGlassAppearance(reloaded, NO), quick);
    [defaults removePersistentDomainForName:suite];

    NSString *legacySuite = [@"com.sinyve.YinSu.glass-legacy-check." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *legacy = [[NSUserDefaults alloc] initWithSuiteName:legacySuite];
    [legacy setInteger:0 forKey:@"glassStyle"];
    [legacy setBool:NO forKey:@"glassInteractive"];
    [legacy setBool:YES forKey:@"glassTintEnabled"];
    [legacy setObject:@"unrelated-setting" forKey:@"hintText"];
    ConfigureGlassPreferences(legacy, legacySuite);
    BOOL migrated = GlassAppearancesEqual(ReadGlassAppearance(legacy, NO), (YSGlassAppearance){0, NO, 0.28}) &&
        GlassAppearancesEqual(ReadGlassAppearance(legacy, YES), DefaultGlassAppearance(YES));
    WriteGlassAppearance(legacy, NO, (YSGlassAppearance){1, YES, 0.09});
    ConfigureGlassPreferences(legacy, legacySuite);
    BOOL idempotent = GlassAppearancesEqual(ReadGlassAppearance(legacy, NO), (YSGlassAppearance){1, YES, 0.09}) &&
        [legacy boolForKey:@"glassTintEnabled"] && [[legacy stringForKey:@"hintText"] isEqualToString:@"unrelated-setting"];
    [legacy setDouble:NAN forKey:@"stickyGlassTintStrength"];
    BOOL sanitized = isfinite(ReadGlassAppearance(legacy, YES).tintStrength);
    [legacy removePersistentDomainForName:legacySuite];
    NSString *partialSuite = [@"com.sinyve.YinSu.glass-partial-check." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *partial = [[NSUserDefaults alloc] initWithSuiteName:partialSuite];
    [partial setInteger:1 forKey:@"glassStyle"];
    ConfigureGlassPreferences(partial, partialSuite);
    migrated = migrated && GlassAppearancesEqual(ReadGlassAppearance(partial, NO), (YSGlassAppearance){1, YES, 0});
    [partial removePersistentDomainForName:partialSuite];
    printf("glassDefaultsDistinct=%d glassProfilesIndependent=%d glassPersistence=%d glassLegacyPreserved=%d glassMigrationIdempotent=%d glassValuesFinite=%d\n",
           distinct, independent, retained, migrated, idempotent, sanitized);
    if (!(distinct && independent && retained && migrated && idempotent && sanitized)) exit(EXIT_FAILURE);
}

static void RunSelfTest(void) {
    NSURL *notesFolderURL = ConfiguredNotesFolder();
    NSURL *vaultURL = ObsidianVaultRootForFolder(notesFolderURL);
    NSString *sample = @"这是双轨记的自动测试，语音输入会直接写进 Obsidian。";
    NSError *error = nil;
    NSURL *noteURL = WriteNote(sample, notesFolderURL, &error);
    if (!noteURL) {
        fprintf(stderr, "self-test failed: %s\n", error.localizedDescription.UTF8String);
        exit(EXIT_FAILURE);
    }
    NSString *written = [NSString stringWithContentsOfURL:noteURL encoding:NSUTF8StringEncoding error:&error];
    if (![written containsString:sample]) {
        fprintf(stderr, "self-test failed: note content mismatch\n");
        exit(EXIT_FAILURE);
    }
    NSURL *openURL = vaultURL ? ObsidianURLForNote(noteURL, vaultURL) : nil;
    printf("uiLanguage=%s appName=%s\n%s\n%s\n", YSCurrentLanguage().UTF8String, YSL(@"双轨记").UTF8String, noteURL.path.UTF8String, openURL.absoluteString.UTF8String ?: "");
}

@interface YSEditorPanel : NSPanel
@end

@implementation YSEditorPanel
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
@end

// One outline owns the complete material, content clipping and edge highlight.
// Keep inner glass/vibrancy rectangular so a second circular clip cannot cut the G3 curve.
@interface YSRoundedPanelView : NSView
@property (nonatomic, readonly) CGFloat nominalCornerRadius;
@property (nonatomic, strong) CAShapeLayer *outlineMask;
@property (nonatomic, strong) CAShapeLayer *outlineEdge;
@property (nonatomic, assign) NSRect outlinedBounds;
@property (nonatomic, assign) CGFloat outlinedScale;
- (void)updateContinuousOutline;
@end

@implementation YSRoundedPanelView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.cornerRadius = 0;
        self.layer.masksToBounds = YES;
        self.outlineMask = [CAShapeLayer layer];
        self.outlineMask.fillColor = NSColor.blackColor.CGColor;
        self.layer.mask = self.outlineMask;
        self.outlineEdge = [CAShapeLayer layer];
        self.outlineEdge.fillColor = nil;
        self.outlineEdge.strokeColor = [NSColor colorWithWhite:1 alpha:0.18].CGColor;
        self.outlineEdge.lineWidth = 1;
        [self updateContinuousOutline];
    }
    return self;
}
- (CGFloat)nominalCornerRadius { return PanelCornerRadius; }
- (void)updateContinuousOutline {
    if (!self.outlineMask) return;
    CGFloat scale = self.window.backingScaleFactor ?: NSScreen.mainScreen.backingScaleFactor;
    if (!NSEqualRects(self.outlinedBounds, self.bounds) || self.outlinedScale != scale) {
        self.outlinedBounds = self.bounds;
        self.outlinedScale = scale;
        CGPathRef outline = YSG3CreateRoundedRectPath(NSRectToCGRect(self.bounds), self.nominalCornerRadius);
        CGPathRef edge = YSG3CreateRoundedRectPath(NSRectToCGRect(NSInsetRect(self.bounds, 0.5, 0.5)), self.nominalCornerRadius - 0.5);
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.outlineMask.frame = self.bounds;
        self.outlineMask.contentsScale = scale;
        self.outlineMask.path = outline;
        self.outlineEdge.frame = self.bounds;
        self.outlineEdge.contentsScale = scale;
        self.outlineEdge.path = edge;
        [CATransaction commit];
        CGPathRelease(outline);
        CGPathRelease(edge);
    }
    if (self.layer.sublayers.lastObject != self.outlineEdge) [self.layer addSublayer:self.outlineEdge];
}
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self updateContinuousOutline];
}
- (void)layout {
    [super layout];
    [self updateContinuousOutline];
}
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self updateContinuousOutline];
}
@end

static BOOL YSPanelHasContinuousOutline(YSRoundedPanelView *view) {
    [view layoutSubtreeIfNeeded];
    [view updateContinuousOutline];
    CGPathRef path = view.outlineMask.path;
    if (!path || view.layer.mask != view.outlineMask || view.layer.cornerRadius != 0) return NO;
    CGRect box = CGPathGetBoundingBox(path);
    CGRect bounds = NSRectToCGRect(view.bounds);
    BOOL boundsMatch = fabs(box.origin.x-bounds.origin.x)<0.01 && fabs(box.origin.y-bounds.origin.y)<0.01 &&
        fabs(box.size.width-bounds.size.width)<0.01 && fabs(box.size.height-bounds.size.height)<0.01;
    CGPoint center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    CGPoint corner = CGPointMake(CGRectGetMinX(bounds)+0.01, CGRectGetMinY(bounds)+0.01);
    return boundsMatch && CGPathContainsPoint(path, NULL, center, NO) &&
        !CGPathContainsPoint(path, NULL, corner, NO) && view.outlineEdge.path != nil;
}

static NSCursor *YSFallbackDiagonalResizeCursor(void) {
    static NSCursor *cursor;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSImage *image = [NSImage imageWithSize:NSMakeSize(24, 24) flipped:YES drawingHandler:^BOOL(NSRect rect) {
            NSBezierPath *arrows = [NSBezierPath bezierPath];
            [arrows moveToPoint:NSMakePoint(5.5, 5.5)];
            [arrows lineToPoint:NSMakePoint(18.5, 18.5)];
            [arrows moveToPoint:NSMakePoint(5.5, 10.5)];
            [arrows lineToPoint:NSMakePoint(5.5, 5.5)];
            [arrows lineToPoint:NSMakePoint(10.5, 5.5)];
            [arrows moveToPoint:NSMakePoint(13.5, 18.5)];
            [arrows lineToPoint:NSMakePoint(18.5, 18.5)];
            [arrows lineToPoint:NSMakePoint(18.5, 13.5)];
            arrows.lineCapStyle = NSLineCapStyleRound;
            arrows.lineJoinStyle = NSLineJoinStyleRound;
            [NSColor.whiteColor setStroke];
            arrows.lineWidth = 3.4;
            [arrows stroke];
            [NSColor.blackColor setStroke];
            arrows.lineWidth = 1.6;
            [arrows stroke];
            return YES;
        }];
        cursor = [[NSCursor alloc] initWithImage:image hotSpot:NSMakePoint(12, 12)];
    });
    return cursor;
}

static NSCursor *YSBottomRightResizeCursor(void) {
    static NSCursor *cursor;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (@available(macOS 15.0, *)) {
            cursor = [NSCursor frameResizeCursorFromPosition:NSCursorFrameResizePositionBottomRight
                                              inDirections:NSCursorFrameResizeDirectionsAll];
        } else {
            cursor = YSFallbackDiagonalResizeCursor();
        }
    });
    return cursor;
}

@interface YSResizeHandle : NSView
@property (nonatomic, readonly) NSUInteger arcCount;
@property (nonatomic, assign) BOOL resizing;
@property (nonatomic, assign) BOOL cursorRectsWereEnabled;
@property (nonatomic, assign) NSRect resizeStartFrame;
@property (nonatomic, assign) NSPoint resizeStartScreen;
- (void)finishResize;
@end

@implementation YSResizeHandle
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect:self.bounds cursor:YSBottomRightResizeCursor()];
}
- (void)mouseDown:(NSEvent *)event {
    [self finishResize];
    NSWindow *window = self.window;
    if (!window) return;
    [window makeKeyWindow];
    self.resizeStartFrame = window.frame;
    self.resizeStartScreen = [window convertPointToScreen:event.locationInWindow];
    self.cursorRectsWereEnabled = window.areCursorRectsEnabled;
    self.resizing = YES;
    // Window resizing invalidates cursor rectangles. Hold one diagonal cursor
    // until mouse-up so those resets cannot replace it midway through a drag.
    [window disableCursorRects];
    [YSBottomRightResizeCursor() push];
}
- (void)mouseDragged:(NSEvent *)event {
    if (!self.resizing) return;
    NSWindow *window = self.window;
    NSPoint point = [window convertPointToScreen:event.locationInWindow];
    NSRect startFrame = self.resizeStartFrame;
    CGFloat width = MAX(window.minSize.width, MIN(window.maxSize.width,
        startFrame.size.width + point.x - self.resizeStartScreen.x));
    CGFloat height = MAX(window.minSize.height, MIN(window.maxSize.height,
        startFrame.size.height - point.y + self.resizeStartScreen.y));
    [window setFrame:NSMakeRect(startFrame.origin.x, NSMaxY(startFrame) - height, width, height)
             display:YES];
}
- (void)mouseUp:(NSEvent *)event { [self finishResize]; }
- (void)finishResize {
    if (!self.resizing) return;
    self.resizing = NO;
    [NSCursor pop];
    if (self.cursorRectsWereEnabled) [self.window enableCursorRects];
    [self.window invalidateCursorRectsForView:self];
}
- (void)cancelOperation:(id)sender { [self finishResize]; }
- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    if (newWindow != self.window) [self finishResize];
    [super viewWillMoveToWindow:newWindow];
}
- (BOOL)isFlipped { return YES; }
- (NSUInteger)arcCount {
    if ([[NSProcessInfo processInfo].environment[@"YIN_SU_ISOLATED"] boolValue] &&
        [[NSProcessInfo processInfo].environment[@"YIN_SU_RESIZE_ARCS"] integerValue] == 1) return 1;
    return 2;
}
- (void)drawRect:(NSRect)dirtyRect {
    YSDrawResizeArcs(self.bounds, PanelCornerRadius, self.arcCount);
}

@end

@interface YSDragHandle : NSView
@property (nonatomic, assign) BOOL hovered;
@property (nonatomic, strong) NSTrackingArea *trackingArea;
@property (nonatomic, strong) NSImageView *logoShadowView;
@property (nonatomic, strong) NSImageView *logoView;
@property (nonatomic, assign, getter=isSticky) BOOL sticky;
@property (nonatomic, assign) BOOL arrivalAnimated;
@property (nonatomic, assign) NSUInteger attachmentGeneration;
- (void)animateAttachment;
@end

@class YSStickyNote;

static BOOL YSReducePinMotion(void) {
    return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion ||
        ([[NSProcessInfo processInfo].environment[@"YIN_SU_ISOLATED"] boolValue] &&
         [[NSProcessInfo processInfo].environment[@"YIN_SU_REDUCE_MOTION"] boolValue]);
}
@implementation YSDragHandle
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.cornerRadius = frameRect.size.width / 2.0;
        self.layer.masksToBounds = YES;

        NSImage *logo = YSBrandImage(NSMakeSize(20, 20));
        self.logoShadowView = [[NSImageView alloc] initWithFrame:NSZeroRect];
        self.logoShadowView.image = logo;
        self.logoShadowView.wantsLayer = YES;
        [self.logoShadowView setAccessibilityElement:NO];
        self.logoShadowView.imageScaling = NSImageScaleProportionallyUpOrDown;
        self.logoShadowView.contentTintColor = [NSColor colorWithWhite:0 alpha:0.32];
        [self addSubview:self.logoShadowView];

        self.logoView = [[NSImageView alloc] initWithFrame:NSZeroRect];
        self.logoView.image = logo;
        self.logoView.wantsLayer = YES;
        [self.logoView setAccessibilityElement:NO];
        self.logoView.imageScaling = NSImageScaleProportionallyUpOrDown;
        self.logoView.contentTintColor = [NSColor colorWithWhite:1 alpha:0.82];
        [self addSubview:self.logoView];
        self.sticky = NO;
    }
    return self;
}

- (void)setSticky:(BOOL)sticky {
    _sticky = sticky;
    NSImage *image = sticky ? YSStickyGlyphImage() : YSBrandImage(NSMakeSize(20, 20));
    self.logoView.image = self.logoShadowView.image = image;
    self.logoView.contentTintColor = [NSColor colorWithWhite:1 alpha:self.hovered ? 0.94 : 0.82];
    [self setAccessibilityElement:YES];
    [self setAccessibilityRole:NSAccessibilityImageRole];
    [self setAccessibilityLabel:sticky ? YSL(@"便签图钉，按住拖动便签") : YSL(@"双轨记错位双轨，按住拖动输入框")];
    [self setAccessibilityIdentifier:sticky ? @"sticky-drag-handle" : @"quick-drag-handle"];
}

- (NSView *)hitTest:(NSPoint)point { return [super hitTest:point] ? self : nil; }

- (void)animateAttachment {
    NSUInteger generation = ++self.attachmentGeneration;
    [self.logoView.layer removeAnimationForKey:@"pinAttachment"];
    [self.logoShadowView.layer removeAnimationForKey:@"pinAttachment"];
    self.arrivalAnimated = NO;
    if (YSReducePinMotion()) return;
    self.arrivalAnimated = YES;
    CAKeyframeAnimation *press = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    press.values = @[@1.06, @0.94, @1];
    press.keyTimes = @[@0, @0.55, @1];
    press.duration = 0.28;
    CABasicAnimation *appear = [CABasicAnimation animationWithKeyPath:@"opacity"];
    appear.fromValue = @0;
    appear.toValue = @1;
    appear.duration = 0.14;
    CAAnimationGroup *arrival = [CAAnimationGroup animation];
    arrival.animations = @[press, appear];
    arrival.duration = 0.28;
    arrival.beginTime = [self.logoView.layer convertTime:CACurrentMediaTime() fromLayer:nil];
    arrival.removedOnCompletion = YES;
    arrival.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [self.logoView.layer addAnimation:arrival forKey:@"pinAttachment"];
    [self.logoShadowView.layer addAnimation:arrival forKey:@"pinAttachment"];
    // Keep the one-shot press bounded even while the first window layout settles.
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakSelf.attachmentGeneration == generation) {
            [weakSelf.logoView.layer removeAnimationForKey:@"pinAttachment"];
            [weakSelf.logoShadowView.layer removeAnimationForKey:@"pinAttachment"];
        }
    });
}

- (void)layout {
    [super layout];
    self.layer.cornerRadius = NSWidth(self.bounds) / 2.0;
    CGFloat side = 20.0;
    NSRect logoFrame = NSMakeRect((NSWidth(self.bounds) - side) / 2.0,
                                  (NSHeight(self.bounds) - side) / 2.0,
                                  side, side);
    self.logoView.frame = logoFrame;
    self.logoShadowView.frame = NSOffsetRect(logoFrame, 0.6, -0.6);
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    YSDrawFrostedChrome(NSGraphicsContext.currentContext.CGContext, self.bounds, NSWidth(self.bounds) / 2, self.hovered);
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.trackingArea) [self removeTrackingArea:self.trackingArea];
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                     options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect
                                                       owner:self
                                                    userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect:self.bounds cursor:[NSCursor openHandCursor]];
}

- (void)mouseEntered:(NSEvent *)event {
    self.hovered = YES;
    self.logoView.contentTintColor = [NSColor colorWithWhite:1 alpha:0.94];
    self.needsDisplay = YES;
}

- (void)mouseExited:(NSEvent *)event {
    self.hovered = NO;
    self.logoView.contentTintColor = [NSColor colorWithWhite:1 alpha:0.82];
    self.needsDisplay = YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

- (void)mouseDown:(NSEvent *)event {
    NSResponder *previousResponder = self.window.firstResponder;
    [self.window performWindowDragWithEvent:event];
    if ([previousResponder isKindOfClass:[NSTextView class]]) {
        [self.window makeFirstResponder:previousResponder];
    }
}
@end

@interface YSStickyNote : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, strong) YSEditorPanel *panel;
@property (nonatomic, strong) YSDragHandle *dragHandle;
@property (nonatomic, strong) YSResizeHandle *resizeHandle;
@property (nonatomic, strong) NSTextView *textView;
@property (nonatomic, strong) NSScrollView *textScrollView;
@property (nonatomic, strong) NSView *glassEffectView;
@property (nonatomic, strong) NSView *surfaceView;
@property (nonatomic, strong) NSView *contentView;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSButton *levelButton;
@property (nonatomic, assign) BOOL floating;
@property (nonatomic, assign) BOOL suppressCallbacks;
@property (nonatomic, copy) NSString *restoredTopLeft;
- (NSDictionary *)dictionaryRepresentation;
@end

@interface YSGlassControls : NSObject
@property (nonatomic, strong) NSSegmentedControl *style;
@property (nonatomic, strong) NSButton *interactive;
@property (nonatomic, strong) NSSlider *tint;
@property (nonatomic, strong) NSTextField *tintValue;
@property (nonatomic, strong) NSTextField *availabilityHint;
@end
@implementation YSGlassControls
@end

@implementation YSStickyNote
- (NSDictionary *)dictionaryRepresentation {
    NSRect frame = self.panel.frame;
    return @{
        @"id": self.identifier,
        @"text": self.textView.string ?: @"",
        @"x": @(NSMinX(frame)), @"y": @(NSMinY(frame)),
        @"width": @(NSWidth(frame)), @"height": @(NSHeight(frame)),
        @"floating": @(self.floating),
    };
}
@end

@interface YSAppDelegate : NSObject <NSApplicationDelegate, NSTextViewDelegate, NSTextFieldDelegate, NSWindowDelegate>
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *statusMenu;
@property (nonatomic, strong) NSPanel *panel;
@property (nonatomic, strong) NSTextView *textView;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSScrollView *textScrollView;
@property (nonatomic, strong) NSView *panelSurfaceView;
@property (nonatomic, strong) NSView *panelContentView;
@property (nonatomic, strong) NSButton *pinButton;
@property (nonatomic, strong) YSDragHandle *editorDragHandle;
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, strong) NSView *glassEffectView;
@property (nonatomic, strong) NSLayoutConstraint *hintTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *hintBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *hintLeadingFullConstraint;
@property (nonatomic, strong) NSLayoutConstraint *hintTrailingFullConstraint;
@property (nonatomic, strong) NSLayoutConstraint *hintTrailingBeforeActionsConstraint;
@property (nonatomic, strong) NSLayoutConstraint *hintLeadingAfterLogoConstraint;
@property (nonatomic, strong) NSLayoutConstraint *scrollBottomToVisualConstraint;
@property (nonatomic, strong) NSLayoutConstraint *scrollBottomToHintConstraint;
@property (nonatomic, strong) NSMenuItem *hotkeyMenuTitleItem;
@property (nonatomic, strong) NSTimer *chordTimer;
@property (nonatomic, assign) EventHotKeyRef hotKeyRef;
@property (nonatomic, assign) EventHandlerRef hotKeyHandlerRef;
@property (nonatomic, assign) BOOL carbonHotKeyRegistered;
@property (nonatomic, assign) CGKeyCode hotkeyKeyCode;
@property (nonatomic, assign) NSEventModifierFlags hotkeyModifiers;
@property (nonatomic, copy) NSString *hotkeyKeyLabel;
@property (nonatomic, strong) NSWindow *settingsWindow;
@property (nonatomic, strong) NSPopUpButton *settingsLanguagePopup;
@property (nonatomic, strong) NSTextField *settingsFolderField;
@property (nonatomic, strong) NSTextField *settingsFolderHint;
@property (nonatomic, strong) NSButton *settingsHotkeyButton;
@property (nonatomic, strong) NSTextField *settingsHotkeyHint;
@property (nonatomic, strong) NSTextField *settingsHintField;
@property (nonatomic, strong) NSSegmentedControl *settingsHintPlacementControl;
@property (nonatomic, strong) NSSegmentedControl *settingsHintAlignmentControl;
@property (nonatomic, strong) YSGlassControls *quickGlassControls;
@property (nonatomic, strong) YSGlassControls *stickyGlassControls;
@property (nonatomic, strong) NSPopUpButton *settingsFontFamilyPopup;
@property (nonatomic, strong) NSPopUpButton *settingsFontSizePopup;
@property (nonatomic, strong) NSButton *autoCopyCheckbox;
@property (nonatomic, strong) NSButton *autoOpenCheckbox;
@property (nonatomic, strong) NSButton *closeAfterSaveCheckbox;
@property (nonatomic, strong) NSButton *loginAtStartupCheckbox;
@property (nonatomic, strong) NSTabView *settingsTabView;
@property (nonatomic, strong) NSSegmentedControl *settingsPageControl;
@property (nonatomic, strong) NSSegmentedControl *settingsStickyLevelControl;
@property (nonatomic, strong) NSSegmentedControl *settingsStickyCloseControl;
@property (nonatomic, strong) NSTextField *settingsStickyCountLabel;
@property (nonatomic, strong) NSMutableArray<YSStickyNote *> *stickyNotes;
@property (nonatomic, assign) NSInteger stickyDefaultLevel;
@property (nonatomic, assign) NSInteger stickyCloseAction;
@property (nonatomic, assign) BOOL savingStickies;
@property (nonatomic, strong) NSTimer *stickySaveTimer;
@property (nonatomic, strong) NSWindow *previewBackdrop;
@property (nonatomic, strong) id hotkeyCaptureMonitor;
@property (nonatomic, assign) BOOL recordingHotkey;
@property (nonatomic, assign) BOOL isConfirmingClose;
@property (nonatomic, assign) BOOL suppressWindowMoveSave;
@property (nonatomic, assign) CGKeyCode previousHotkeyKeyCode;
@property (nonatomic, assign) NSEventModifierFlags previousHotkeyModifiers;
@property (nonatomic, copy) NSString *previousHotkeyKeyLabel;
@property (nonatomic, assign) BOOL autoCopy;
@property (nonatomic, assign) BOOL autoOpen;
@property (nonatomic, assign) BOOL closeAfterSave;
@property (nonatomic, copy) NSString *hintText;
@property (nonatomic, assign) NSInteger hintPlacement;
@property (nonatomic, assign) NSInteger hintAlignment;
@property (nonatomic, assign) YSGlassAppearance quickGlass;
@property (nonatomic, assign) YSGlassAppearance stickyGlass;
@property (nonatomic, copy) NSString *inputFontFamily;
@property (nonatomic, assign) CGFloat inputFontSize;
@property (nonatomic, assign) BOOL shortcutDown;
@property (nonatomic, strong) NSURL *lastNoteURL;
@property (nonatomic, copy) NSString *pendingOpenText;
@property (nonatomic, strong) NSURL *pendingOpenNoteURL;
@property (nonatomic, assign) BOOL openingNote;
@property (nonatomic, strong) NSTimer *draftSaveTimer;
- (void)handleHotkeyPressed;
- (void)handleHotkeyReleased;
- (void)showEditor;
- (void)requestCloseEditor;
- (void)languageChanged:(NSPopUpButton *)sender;
- (void)refreshInterfaceLanguage;
- (NSString *)effectiveHintText;
@end

static OSStatus YSHotKeyHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData) {
    EventHotKeyID hotKeyID = {0};
    OSStatus status = GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID,
                                        NULL, sizeof(hotKeyID), NULL, &hotKeyID);
    if (status != noErr || hotKeyID.signature != YSHotKeySignature) {
        return eventNotHandledErr;
    }
    YSAppDelegate *delegate = (__bridge YSAppDelegate *)userData;
    UInt32 kind = GetEventKind(event);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (kind == kEventHotKeyPressed) {
            YSLog(@"global hotkey pressed");
            [delegate handleHotkeyPressed];
        } else if (kind == kEventHotKeyReleased) {
            YSLog(@"global hotkey released");
            [delegate handleHotkeyReleased];
        }
    });
    return noErr;
}

@implementation YSAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    NSString *iconPath = [NSBundle.mainBundle pathForResource:@"AppIcon" ofType:@"icns"];
    NSImage *appIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
    if (appIcon) NSApp.applicationIconImage = appIcon;
    MigrateLegacyPreferences();
    NSUserDefaults *startupDefaults = YSPreferences();
    ConfigureGlassPreferences(startupDefaults, YSPreferencesDomain);
    [startupDefaults registerDefaults:@{
        @"autoCopy": @YES,
        @"autoOpen": @YES,
        @"closeAfterSave": @YES,
        @"hotkeyKeyCode": @(DefaultHotkeyKeyCode),
        @"hotkeyModifiers": @(DefaultHotkeyModifiers),
        @"hotkeyKeyLabel": DefaultHotkeyKeyLabel,
        @"hintText": DefaultHintText,
        @"hintPlacement": @0,
        @"hintAlignment": @0,
        @"inputFontFamily": @"",
        @"inputFontSize": @21,
        @"stickyDefaultLevel": @0,
        @"stickyCloseAction": @0,
    }];
    self.stickyNotes = [NSMutableArray array];
    [self loadPreferences];
    NSString *draft = [NSString stringWithContentsOfURL:EditorDraftURL() encoding:NSUTF8StringEncoding error:nil];
    [self buildMainMenu];
    [self buildPanel];
    // Settings can be the first and only window opened after launch. Keep a
    // restored draft in memory so quitting there cannot overwrite it as empty.
    self.textView.string = draft ?: @"";
    [self buildStatusItem];
    [self restoreStickyNotes];
    if (![[NSProcessInfo processInfo].environment[@"YIN_SU_ISOLATED"] boolValue]) [self startInputMonitor];
    YSLog(@"startup hotkey=%@ registered=%@ notes=%@",
           [self hotkeyDisplayString], self.carbonHotKeyRegistered ? @"yes" : @"no",
           ConfiguredNotesFolder().path);
    NSString *lastPath = [YSPreferences() stringForKey:@"lastNotePath"];
    if (lastPath.length > 0) {
        self.lastNoteURL = [NSURL fileURLWithPath:lastPath];
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--draft-check"]) {
        printf("draftRestored=%d\n", [draft isEqualToString:@"未提交的长文草稿"] &&
            [self.textView.string isEqualToString:draft]);
        fflush(stdout);
        [NSApp terminate:nil];
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--ui-check"]) {
        [self showEditor];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BOOL key = weakSelf.panel.isKeyWindow;
            BOOL focused = [weakSelf.panel firstResponder] == weakSelf.textView;
            printf("panelVisible=%d keyWindow=%d textFocused=%d\n", weakSelf.panel.isVisible, key, focused);
            if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--commit-check"]) {
                weakSelf.textView.string = @"回车保存自动测试";
                [weakSelf textView:weakSelf.textView doCommandBySelector:@selector(insertNewline:)];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSString *content = weakSelf.lastNoteURL
                        ? [NSString stringWithContentsOfURL:weakSelf.lastNoteURL encoding:NSUTF8StringEncoding error:nil]
                        : nil;
                    printf("commitSaved=%d panelVisible=%d path=%s\n",
                           content != nil, weakSelf.panel.isVisible,
                           weakSelf.lastNoteURL.path.UTF8String ?: "");
                    printf("openRequestAccepted=%d textCleared=%d pendingRetry=%d\n",
                           !weakSelf.openingNote && weakSelf.pendingOpenNoteURL == nil,
                           weakSelf.textView.string.length == 0, weakSelf.pendingOpenNoteURL != nil);
                    fflush(stdout);
                    [NSApp terminate:nil];
                });
                return;
            }
            fflush(stdout);
            [NSApp terminate:nil];
        });
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--layout-check"]) {
        [self showEditor];
        CGFloat initialHeight = self.panel.frame.size.height;
        self.textView.string = @"第一行\n第二行\n第三行\n第四行";
        [self updatePanelSizeForContent];
        CGFloat mediumHeight = self.panel.frame.size.height;
        NSMutableArray *lines = [NSMutableArray array];
        for (NSInteger index = 0; index < 40; index++) {
            [lines addObject:[NSString stringWithFormat:@"这是一段用于测试自动高度的长文本，第 %ld 行。", (long)index + 1]];
        }
        self.textView.string = [lines componentsJoinedByString:@"\n"];
        [self updatePanelSizeForContent];
        CGFloat maximumHeight = self.panel.frame.size.height;
        printf("initialHeight=%.0f mediumHeight=%.0f maxHeight=%.0f scroller=%d\n",
               initialHeight, mediumHeight, maximumHeight, self.textScrollView.hasVerticalScroller);
        fflush(stdout);
        [NSApp terminate:nil];
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--settings-check"]) {
        [self openSettings:nil];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf.settingsWindow.contentView layoutSubtreeIfNeeded];
            NSScrollView *page = (NSScrollView *)weakSelf.settingsTabView.selectedTabViewItem.view;
            NSSize documentSize = page.documentView.frame.size;
            NSSize viewportSize = page.contentView.bounds.size;
            printf("settingsLayout=%d document=%.0fx%.0f viewport=%.0fx%.0f\n",
                   documentSize.width >= 500 && documentSize.height > viewportSize.height && viewportSize.height > 0,
                   documentSize.width, documentSize.height, viewportSize.width, viewportSize.height);
            printf("settingsVisible=%d keyWindow=%d folder=%s hotkey=%s hint=%s\n",
                   weakSelf.settingsWindow.isVisible, weakSelf.settingsWindow.isKeyWindow,
                   weakSelf.settingsFolderField.stringValue.UTF8String,
                   weakSelf.settingsHotkeyButton.title.UTF8String,
                   weakSelf.settingsHotkeyHint.stringValue.UTF8String);
            fflush(stdout);
            [NSApp terminate:nil];
        });
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--toggle-check"]) {
        self.textView.string = @"";
        [self saveEditorDraft];
        [self showEditor];
        BOOL before = self.panel.isVisible;
        self.shortcutDown = NO;
        [self handleHotkeyPressed];
        BOOL after = self.panel.isVisible;
        printf("toggleBefore=%d toggleAfter=%d confirmation=%d\n", before, after, self.panel.attachedSheet != nil);
        fflush(stdout);
        [NSApp terminate:nil];
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--open-failure-check"]) {
        [self showEditor];
        self.textView.string = @"打开失败时必须保留的正文";
        self.pendingOpenText = self.textView.string;
        self.pendingOpenNoteURL = [NSURL fileURLWithPath:@"/private/tmp/YinSu-open-does-not-exist.md"];
        NSURL *before = self.lastNoteURL;
        [self commitEditor];
        printf("failureTextRetained=%d noDuplicateSave=%d pendingRetry=%d panelVisible=%d\n",
               [self.textView.string isEqualToString:self.pendingOpenText], self.lastNoteURL == before,
               self.pendingOpenNoteURL != nil, self.panel.isVisible);
        fflush(stdout);
        if (self.panel.attachedSheet) [self.panel endSheet:self.panel.attachedSheet returnCode:NSAlertFirstButtonReturn];
        [NSApp terminate:nil];
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--draft-save-check"]) {
        self.textView.string = @"未提交的长文草稿";
        [self textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification object:self.textView]];
        [self saveEditorDraft];
        printf("draftSaved=%d\n", [[NSString stringWithContentsOfURL:EditorDraftURL() encoding:NSUTF8StringEncoding error:nil] isEqualToString:self.textView.string]);
        fflush(stdout);
        [NSApp terminate:nil];
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--confirm-check"]) {
        [self showEditor];
        self.textView.string = @"未保存测试内容";
        self.shortcutDown = NO;
        [self handleHotkeyPressed];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSWindow *sheet = weakSelf.panel.attachedSheet;
            printf("confirmationShown=%d panelStillVisible=%d\n", sheet != nil, weakSelf.panel.isVisible);
            fflush(stdout);
            if (sheet) [weakSelf.panel endSheet:sheet returnCode:NSAlertFirstButtonReturn];
            [weakSelf discardEditor];
            [NSApp terminate:nil];
        });
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--settings-hotkey-check"]) {
        [self openSettings:nil];
        CGKeyCode savedKeyCode = self.hotkeyKeyCode;
        NSEventModifierFlags savedModifiers = self.hotkeyModifiers;
        NSString *savedKeyLabel = self.hotkeyKeyLabel;
        [self recordHotkey:nil];
        NSEvent *testEvent = [NSEvent keyEventWithType:NSEventTypeKeyDown
                                             location:NSZeroPoint
                                        modifierFlags:NSEventModifierFlagControl | NSEventModifierFlagOption
                                            timestamp:0
                                         windowNumber:self.settingsWindow.windowNumber
                                              context:nil
                                           characters:@"j"
                          charactersIgnoringModifiers:@"j"
                                            isARepeat:NO
                                              keyCode:38];
        [self captureHotkeyEvent:testEvent];
        NSString *changed = [self hotkeyDisplayString];
        BOOL changedRegistered = self.carbonHotKeyRegistered;
        // 恢复用户原本的快捷键，而不是恢复默认值，避免测试污染用户设置。
        [self unregisterHotKey];
        if ([self registerHotKeyForKeyCode:savedKeyCode modifiers:savedModifiers]) {
            self.hotkeyKeyCode = savedKeyCode;
            self.hotkeyModifiers = savedModifiers;
            self.hotkeyKeyLabel = savedKeyLabel;
            [self saveHotkeyPreferences];
            [self refreshHotkeyUI];
        }
        printf("changedHotkey=%s registered=%d restoredHotkey=%s restoredRegistered=%d\n",
               changed.UTF8String, changedRegistered, [self hotkeyDisplayString].UTF8String,
               self.carbonHotKeyRegistered);
        fflush(stdout);
        [NSApp terminate:nil];
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--hint-settings-check"]) {
        [self openSettings:nil];
        NSString *savedHintText = self.hintText;
        NSInteger savedHintPlacement = self.hintPlacement;
        NSInteger savedHintAlignment = self.hintAlignment;
        self.settingsHintField.stringValue = @"自定义灰字";
        [self controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification
                                                                object:self.settingsHintField]];
        self.settingsHintPlacementControl.selectedSegment = 1;
        self.settingsHintAlignmentControl.selectedSegment = 1;
        [self hintOptionsChanged:nil];
        printf("hintText=%s placement=%ld alignment=%ld hidden=%d\n",
               self.hintText.UTF8String, (long)self.hintPlacement, (long)self.hintAlignment,
               self.statusLabel.hidden);
        // 恢复用户原本的灰字设置，避免测试污染用户配置。
        self.hintText = savedHintText;
        self.hintPlacement = savedHintPlacement;
        self.hintAlignment = savedHintAlignment;
        NSUserDefaults *defaults = YSPreferences();
        [defaults setObject:self.hintText forKey:@"hintText"];
        [defaults setInteger:self.hintPlacement forKey:@"hintPlacement"];
        [defaults setInteger:self.hintAlignment forKey:@"hintAlignment"];
        [self updateHintLayout];
        fflush(stdout);
        [NSApp terminate:nil];
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--preview-editor"]) {
        [self showEditor];
        self.textView.string = @"这是一个悬浮输入窗口。\n可以直接输入文字，也可以使用当前输入法的语音输入。\n左上角的圆点可以拖动窗口位置。";
        [self updatePanelSizeForContent];
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--preview-settings"] ||
        [[[NSProcessInfo processInfo] arguments] containsObject:@"--open-settings"]) {
        [self openSettings:nil];
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--sticky-check"]) {
        [self showEditor];
        self.textView.string = @"第一张便签\n持续输入也会自动保存";
        [self pinEditor:nil];
        [self showStickyFromMenu:nil];
        self.stickyNotes.lastObject.textView.string = @"第二张便签";
        YSStickyNote *second = self.stickyNotes.lastObject;
        [self toggleStickyLevel:second.levelButton];
        [self.stickyNotes.firstObject.panel setFrame:NSMakeRect(120, 180, 360, 260) display:YES];
        CGFloat handleTop = NSHeight(self.stickyNotes.firstObject.panel.contentView.bounds) - NSMinY(self.stickyNotes.firstObject.dragHandle.frame);
        [self.stickyNotes.firstObject.panel setFrame:NSMakeRect(120, 180, 280, 180) display:YES];
        CGFloat shrunkHandleTop = NSHeight(self.stickyNotes.firstObject.panel.contentView.bounds) - NSMinY(self.stickyNotes.firstObject.dragHandle.frame);
        [self.stickyNotes.firstObject.panel setFrame:NSMakeRect(120, 180, 360, 260) display:YES];
        [self windowDidResize:[NSNotification notificationWithName:NSWindowDidResizeNotification
                                                            object:self.stickyNotes.firstObject.panel]];
        [self saveStickyNotes];
        NSDictionary *store = ReadStickyStore();
        NSArray *stored = store[@"notes"];
        BOOL valid = stored.count == 2 && [stored[0][@"text"] containsString:@"第一张便签"];
        printf("stickies=%ld stored=%ld valid=%d pinHidden=%d independentEditor=%d floating=%d minSize=%d\n",
               (unsigned long)self.stickyNotes.count, (unsigned long)stored.count, valid,
               self.panel.contentView.subviews.count > 0, self.panel != self.stickyNotes.firstObject.panel,
               !self.stickyNotes.lastObject.floating,
               NSEqualSizes(self.stickyNotes.firstObject.panel.minSize, NSMakeSize(StickyMinimumWidth, StickyMinimumHeight)));
        BOOL stickyReturn = [self textView:second.textView doCommandBySelector:@selector(insertNewline:)];
        NSNotification *change = [NSNotification notificationWithName:NSTextDidChangeNotification object:second.textView];
        [self textDidChange:change];
        BOOL resizeKept = NSEqualSizes(self.stickyNotes.firstObject.panel.frame.size, NSMakeSize(360, 260));
        [self removeSticky:second saveCopy:NO];
        printf("stickyReturnIsNewline=%d stickyDoesNotResizeEditor=%d manualResizeKept=%d dragHandleTop=%.0f shrunkDragHandleTop=%.0f remaining=%ld rootRadius=%.0f settingsTabs=%ld\n",
               !stickyReturn, self.panel.frame.size.width == PanelWidth, resizeKept,
               handleTop, shrunkHandleTop, (unsigned long)self.stickyNotes.count, ((YSRoundedPanelView *)self.stickyNotes.firstObject.panel.contentView).nominalCornerRadius,
               (unsigned long)self.settingsTabView.tabViewItems.count);
        [self openSettings:nil];
        self.settingsPageControl.selectedSegment = 1;
        [self settingsPageChanged:self.settingsPageControl];
        printf("settingsTabsAfterBuild=%ld stickyTabLabel=%s\n", (unsigned long)self.settingsTabView.tabViewItems.count,
               [self.settingsTabView.tabViewItems[1].label UTF8String]);
        printf("selectedPage=%d pageControlFont=%.0f\n", self.settingsTabView.selectedTabViewItem == self.settingsTabView.tabViewItems[1], self.settingsPageControl.font.pointSize);
        fflush(stdout);
        [NSApp terminate:nil];
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--stickies-tab"]) {
        self.settingsPageControl.selectedSegment = 1;
        [self settingsPageChanged:self.settingsPageControl];
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--preview-stickies"]) {
        if (self.stickyNotes.count == 0) [self showStickyFromMenu:nil];
        self.stickyNotes.firstObject.textView.string = @"把重要的想法留在手边。\n\n可以继续输入和语音听写，所有修改都会自动保存。";
        NSRect visible = NSScreen.mainScreen.visibleFrame;
        [self.stickyNotes.firstObject.panel setFrame:NSMakeRect(NSMidX(visible) - 470, NSMidY(visible) + 80,
                                                                 420, 260) display:YES];
        [self.stickyNotes.firstObject.panel makeKeyAndOrderFront:nil];
        [self showEditor];
        self.textView.string = @"继续记录新的速记…";
        [self updatePanelSizeForContent];
        NSRect editorFrame = self.panel.frame;
        editorFrame.origin.x = NSMidX(visible) + 30;
        editorFrame.origin.y = NSMidY(visible) - 130;
        [self.panel setFrame:editorFrame display:YES];
        NSString *background = [[NSProcessInfo processInfo] environment][@"YIN_SU_PREVIEW_BACKGROUND"];
        if (background.length) {
            NSWindow *backdrop = [[NSWindow alloc] initWithContentRect:NSScreen.mainScreen.frame
                                                           styleMask:NSWindowStyleMaskBorderless
                                                             backing:NSBackingStoreBuffered defer:NO];
            backdrop.backgroundColor = [background isEqualToString:@"light"] ? [NSColor colorWithWhite:0.74 alpha:1] : [NSColor colorWithWhite:0.24 alpha:1];
            backdrop.level = NSFloatingWindowLevel - 1;
            self.stickyNotes.firstObject.panel.level = NSFloatingWindowLevel;
            [self.panel orderFront:nil];
            for (YSStickyNote *note in self.stickyNotes) [note.panel orderFront:nil];
            backdrop.hasShadow = NO;
            self.previewBackdrop = backdrop;
            [backdrop orderBack:nil];
        }
    }
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--preview-stickies"] &&
        [NSProcessInfo.processInfo.environment[@"YIN_SU_ISOLATED"] boolValue]) {
        printf("Preview screen=%s editor=%s\n", NSStringFromRect(NSScreen.mainScreen.frame).UTF8String,
               NSStringFromRect(self.panel.frame).UTF8String);
        fflush(stdout);
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--sticky-restore-check"]) {
        YSStickyNote *note = self.stickyNotes.firstObject;
        printf("restored=%ld text=%d size=%.0fx%.0f floating=%d editorIndependent=%d rootRadius=%.0f\n",
               (unsigned long)self.stickyNotes.count, [note.textView.string containsString:@"第一张便签"],
               note.panel.frame.size.width, note.panel.frame.size.height, note.floating,
               note.panel != self.panel, ((YSRoundedPanelView *)note.panel.contentView).nominalCornerRadius);
        printf("restoredPin=%d restoredPinStatic=%d\n", note.dragHandle.isSticky,
               !note.dragHandle.arrivalAnimated && note.dragHandle.logoView.layer.animationKeys.count == 0);
        printf("restoredG3Mask=%d\n", YSPanelHasContinuousOutline((YSRoundedPanelView *)note.panel.contentView));
        fflush(stdout);
        [NSApp terminate:nil];
    }
    if ([[NSProcessInfo processInfo].arguments containsObject:@"--glass-check"]) {
        [self openSettings:nil];
        [self showStickyFromMenu:nil];
        YSStickyNote *first = self.stickyNotes.lastObject;
        [self showEditor];
        self.textView.string = @"切换便签时采用独立外观";
        [self pinEditor:nil];
        YSStickyNote *second = self.stickyNotes.lastObject;
        BOOL switched = SurfaceMatchesGlassAppearance(self.panelSurfaceView, self.panelContentView, self.quickGlass) &&
            SurfaceMatchesGlassAppearance(second.surfaceView, second.contentView, self.stickyGlass);
        self.quickGlassControls.style.selectedSegment = 0;
        self.quickGlassControls.interactive.state = NSControlStateValueOff;
        self.quickGlassControls.tint.doubleValue = 0.12;
        [self glassOptionsChanged:self.quickGlassControls.tint];
        YSGlassAppearance quick = self.quickGlass;
        BOOL quickOnly = SurfaceMatchesGlassAppearance(self.panelSurfaceView, self.panelContentView, quick) &&
            SurfaceMatchesGlassAppearance(first.surfaceView, first.contentView, DefaultGlassAppearance(YES)) &&
            SurfaceMatchesGlassAppearance(second.surfaceView, second.contentView, DefaultGlassAppearance(YES));
        self.stickyGlassControls.style.selectedSegment = 1;
        self.stickyGlassControls.interactive.state = NSControlStateValueOn;
        self.stickyGlassControls.tint.doubleValue = 0.23;
        [self glassOptionsChanged:self.stickyGlassControls.tint];
        YSGlassAppearance sticky = self.stickyGlass;
        BOOL stickyOnly = SurfaceMatchesGlassAppearance(first.surfaceView, first.contentView, sticky) &&
            SurfaceMatchesGlassAppearance(second.surfaceView, second.contentView, sticky) &&
            SurfaceMatchesGlassAppearance(self.panelSurfaceView, self.panelContentView, quick);
        [self loadPreferences];
        [self showStickyFromMenu:nil];
        YSStickyNote *third = self.stickyNotes.lastObject;
        BOOL newNote = SurfaceMatchesGlassAppearance(third.surfaceView, third.contentView, sticky);
        [self resetGlassOptions:self.quickGlassControls.style];
        BOOL separateReset = SurfaceMatchesGlassAppearance(self.panelSurfaceView, self.panelContentView, DefaultGlassAppearance(NO)) &&
            SurfaceMatchesGlassAppearance(third.surfaceView, third.contentView, sticky);
        [self resetGlassOptions:self.stickyGlassControls.style];
        BOOL resetNotes = SurfaceMatchesGlassAppearance(first.surfaceView, first.contentView, DefaultGlassAppearance(YES)) &&
            SurfaceMatchesGlassAppearance(second.surfaceView, second.contentView, DefaultGlassAppearance(YES));
        NSVisualEffectView *fallback = [NSVisualEffectView new];
        NSView *fallbackContent = [NSView new];
        [self applyGlassAppearance:sticky toSurface:fallback content:fallbackContent];
        BOOL fallbackTint = SurfaceMatchesGlassAppearance(fallback, fallbackContent, sticky);
        printf("glassPinSwitch=%d glassQuickOnly=%d glassStickyOnly=%d glassNewNote=%d glassSeparateReset=%d glassResetNotes=%d glassFallbackTint=%d\n",
               switched, quickOnly, stickyOnly, newNote, separateReset, resetNotes, fallbackTint);
        fflush(stdout);
        [NSApp terminate:nil];
    }
    if ([[NSProcessInfo processInfo].arguments containsObject:@"--save-button-check"]) {
        [self showEditor];
        NSUInteger before = CountMarkdownNotes();
        self.textView.string = @"通过软盘按钮保存的速记";
        [self.saveButton performClick:nil];
        NSString *written = [NSString stringWithContentsOfURL:self.lastNoteURL encoding:NSUTF8StringEncoding error:nil];
        BOOL saved = [written isEqualToString:@"通过软盘按钮保存的速记\n"] && self.textView.string.length == 0 &&
            !self.panel.isVisible && CountMarkdownNotes() == before + 1;
        [self showEditor];
        self.textView.string = @"便签关闭时另存的正文";
        [self.pinButton performClick:nil];
        YSStickyNote *note = self.stickyNotes.lastObject;
        BOOL pinOnly = CountMarkdownNotes() == before + 1 && [note.textView.string isEqualToString:@"便签关闭时另存的正文"];
        [self requestCloseSticky:note];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BOOL asks = note.panel.attachedSheet != nil;
            if (asks) [note.panel endSheet:note.panel.attachedSheet returnCode:NSAlertThirdButtonReturn];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *copy = [NSString stringWithContentsOfURL:weakSelf.lastNoteURL encoding:NSUTF8StringEncoding error:nil];
                BOOL savedOnClose = ![weakSelf.stickyNotes containsObject:note] && CountMarkdownNotes() == before + 2 &&
                    [copy isEqualToString:@"便签关闭时另存的正文\n"];
                [weakSelf showEditor];
                weakSelf.textView.string = @"打开失败仍保留正文";
                weakSelf.pendingOpenText = weakSelf.textView.string;
                weakSelf.pendingOpenNoteURL = [NSURL fileURLWithPath:@"/private/tmp/YinSu-save-button-missing.md"];
                [weakSelf.saveButton performClick:nil];
                BOOL retry = [weakSelf.textView.string isEqualToString:weakSelf.pendingOpenText] && CountMarkdownNotes() == before + 2;
                printf("saveButtonWrites=%d pinDoesNotWriteMarkdown=%d stickyCloseAsks=%d stickyCloseSaves=%d saveButtonRetryNoDuplicate=%d\n",
                       saved, pinOnly, asks, savedOnClose, retry);
                fflush(stdout);
                if (weakSelf.panel.attachedSheet) [weakSelf.panel endSheet:weakSelf.panel.attachedSheet returnCode:NSAlertFirstButtonReturn];
                [NSApp terminate:nil];
            });
        });
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--pin-check"]) {
        [self showEditor];
        self.textView.string = @"便签状态与空间关系测试";
        NSRect editorFrame = self.panel.frame;
        [self pinEditor:nil];
        YSStickyNote *note = self.stickyNotes.lastObject;
        BOOL anchored = fabs(NSMaxY(editorFrame) - NSMaxY(note.panel.frame)) < 0.01 &&
            fabs(NSMinX(editorFrame) - NSMinX(note.panel.frame)) < 0.01;
        [note.panel setFrame:NSMakeRect(120, 180, 280, 180) display:YES];
        __weak typeof(self) weakSelf = self;
        __block BOOL moving = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.09 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CALayer *presentation = note.dragHandle.logoView.layer.presentationLayer;
            CGFloat scale = presentation ? presentation.transform.m11 : 1;
            moving = presentation && (fabs(scale - 1) > 0.002 || presentation.opacity < 0.99);
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSRect pin = note.dragHandle.frame;
            NSRect bounds = note.panel.contentView.bounds;
            BOOL geometry = fabs(NSMinX(pin) - DragHandleInset) < 0.01 &&
                fabs(NSHeight(bounds) - NSMidY(pin) - 26) < 0.01;
            BOOL draggable = [note.dragHandle.superview hitTest:NSMakePoint(NSMidX(pin), NSMidY(pin))] == note.dragHandle;
            BOOL noCentralPin = !ViewContainsIdentifier(note.panel.contentView, @"sticky-pin");
            BOOL motion = note.dragHandle.arrivalAnimated != YSReducePinMotion();
            BOOL settled = [note.dragHandle.logoView.layer animationForKey:@"pinAttachment"] == nil;
            BOOL content = [note.textView.string isEqualToString:@"便签状态与空间关系测试"] && !weakSelf.panel.isVisible;
            BOOL sample = YSReducePinMotion() ? !moving : moving;
            printf("pinGeometry=%d pinDragTarget=%d pinMotionRespected=%d pinAnimationSettled=%d pinMotionSample=%d pinContentPreserved=%d pinTransitionAnchor=%d centralPinAbsent=%d\n",
                   geometry, draggable, motion, settled, sample, content, anchored, noCentralPin);
            fflush(stdout);
            [NSApp terminate:nil];
        });
    }
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--localization-check"]) {
        if (![NSProcessInfo.processInfo.environment[@"YIN_SU_ISOLATED"] boolValue]) {
            fprintf(stderr,"localization-check requires an isolated app\n");
            exit(EXIT_FAILURE);
        }
        [self showEditor];
        NSString *body = @"A passing thought / 临时想法\nKeep the original text. 保留原文。";
        self.textView.string = body;
        self.hintText = @"My custom hint · 自定义提示";
        [YSPreferences() setObject:self.hintText forKey:@"hintText"];
        YSStickyNote *note = [self createStickyWithText:body frame:NSMakeRect(100,100,360,240) floating:YES];
        NSRect stickyFrame = note.panel.frame;
        NSPanel *editor = self.panel, *sticky = note.panel;
        NSStatusItem *statusItem = self.statusItem;
        NSMutableDictionary *before = [[YSPreferences() persistentDomainForName:YSPreferencesDomain] mutableCopy];
        [before removeObjectForKey:@"uiLanguage"];
        [self openSettings:nil];
        BOOL strings = YES, content = YES, layout = YES, preserved = YES, defaultsTranslate = YES;
        for (NSString *language in @[@"en", @"zh-Hans"]) {
            for (NSMenuItem *item in self.settingsLanguagePopup.itemArray) {
                if ([item.representedObject isEqual:language]) { [self.settingsLanguagePopup selectItem:item]; break; }
            }
            [self languageChanged:self.settingsLanguagePopup];
            BOOL english = [language isEqualToString:@"en"];
            strings = strings && [YSCurrentLanguage() isEqualToString:language] &&
                [self.settingsWindow.title isEqualToString:english ? @"2ndJot Settings" : @"双轨记设置"] &&
                [self.settingsPageControl labelForSegment:0] &&
                [[self.settingsPageControl labelForSegment:0] isEqualToString:english ? @"General" : @"通用"] &&
                [self.statusMenu itemWithTitle:english ? @"Quit" : @"退出"] != nil &&
                [note.levelButton.accessibilityLabel isEqualToString:YSL(@"切换置顶／置底")] &&
                [self.settingsLanguagePopup.selectedItem.representedObject isEqual:language];
            content = content && self.panel == editor && note.panel == sticky && self.statusItem == statusItem &&
                [self.textView.string isEqualToString:body] && [note.textView.string isEqualToString:body] &&
                NSEqualRects(note.panel.frame,stickyFrame) && [self.settingsHintField.stringValue isEqualToString:self.hintText];
            [self.settingsWindow setContentSize:NSMakeSize(560,480)];
            for (NSInteger page=0; page<2; page++) {
                self.settingsPageControl.selectedSegment = page;
                [self settingsPageChanged:nil];
                [self.settingsWindow.contentView layoutSubtreeIfNeeded];
                layout = layout && YSLocalizedSettingsFit(self.settingsWindow.contentView);
            }
            NSMutableDictionary *after = [[YSPreferences() persistentDomainForName:YSPreferencesDomain] mutableCopy];
            [after removeObjectForKey:@"uiLanguage"];
            preserved = preserved && [after isEqual:before];
            NSString *custom = self.hintText;
            self.hintText = YSLocalizedInLanguage(@"回车或软盘存盘 · 图钉变便签",@"zh-Hans");
            [self restoreHintText];
            if (english) defaultsTranslate = defaultsTranslate &&
                [self.statusLabel.stringValue rangeOfString:@"[一-龥]" options:NSRegularExpressionSearch].location == NSNotFound;
            else defaultsTranslate = defaultsTranslate && [self.statusLabel.stringValue isEqualToString:self.hintText];
            self.hintText = custom;
            [self restoreHintText];
        }
        [YSPreferences() synchronize];
        NSUserDefaults *reload = [[NSUserDefaults alloc] initWithSuiteName:YSPreferencesDomain];
        BOOL persisted = [[reload stringForKey:@"uiLanguage"] isEqualToString:YSLanguagePreference()];
        YSSetLanguagePreference(@"system");
        BOOL system = [YSLanguagePreference() isEqualToString:@"system"] &&
            [@[@"en",@"zh-Hans"] containsObject:YSCurrentLanguage()];
        printf("localizedStrings=%d languageSwitchKeepsContent=%d languageSwitchKeepsSettings=%d localizedLayout=%d localizedDefaultHint=%d languagePreferencePersists=%d systemLanguageFallback=%d\n",
            strings, content, preserved, layout, defaultsTranslate, persisted, system);
        fflush(stdout);
        if (!(strings && content && preserved && layout && defaultsTranslate && persisted && system)) exit(EXIT_FAILURE);
        [NSApp terminate:nil];
    }
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--brand-check"]) {
        [self showEditor];
        BOOL quickBrand = !self.editorDragHandle.isSticky && self.editorDragHandle.logoView.image.isTemplate &&
            [self.editorDragHandle.logoView.image.accessibilityDescription isEqualToString:YSL(@"双轨记错位双轨")];
        BOOL menuBrand = self.statusItem.button.image.isTemplate && NSEqualSizes(self.statusItem.button.image.size, NSMakeSize(18,18)) &&
            [self.statusItem.button.image.accessibilityDescription isEqualToString:YSL(@"双轨记错位双轨")];
        BOOL appBrand = [NSBundle.mainBundle.infoDictionary[@"CFBundleIconFile"] isEqualToString:@"AppIcon"] && appIcon != nil;
        BOOL nameUnified = [NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] hasPrefix:@"2ndJot"] &&
            [NSBundle.mainBundle.infoDictionary[@"CFBundleName"] hasPrefix:@"2ndJot"] &&
            [self.panel.title isEqualToString:YSL(@"双轨记快捷输入")];
        BOOL identityKept = [NSBundle.mainBundle.infoDictionary[@"CFBundleExecutable"] isEqualToString:@"YinSu"] &&
            [NSBundle.mainBundle.bundleIdentifier hasPrefix:@"com.sinyve.YinSu"];
        self.textView.string = @"新品牌和便签拖动标记";
        [self pinEditor:nil];
        YSStickyNote *note = self.stickyNotes.lastObject;
        BOOL stickyPin = note.dragHandle.isSticky && ViewContainsIdentifier(note.contentView, @"sticky-drag-handle") &&
            !ViewContainsIdentifier(note.contentView, @"sticky-pin");
        NSArray<NSBezierPath *> *arcs = YSResizeArcPaths(note.resizeHandle.bounds, PanelCornerRadius, note.resizeHandle.arcCount);
        BOOL curved = arcs.count == 2;
        for (NSBezierPath *arc in arcs) {
            NSBezierPathElement element = [arc elementAtIndex:1];
            curved = curved && arc.elementCount >= 2 && element != NSBezierPathElementMoveTo &&
                element != NSBezierPathElementLineTo && element != NSBezierPathElementClosePath;
        }
        printf("quickBrand=%d menuBrand=%d appIconBundled=%d stickyPinReplacesLogo=%d curvedResizeHandle=%d appNameUnified=%d legacyIdentityKept=%d\n",
               quickBrand, menuBrand, appBrand, stickyPin, curved, nameUnified, identityKept);
        fflush(stdout);
        [NSApp terminate:nil];
    }
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--resize-check"]) {
        YSStickyNote *note = [self createStickyWithText:@"缩放光标与拖动事件检查"
            frame:NSMakeRect(100, 200, 420, 260) floating:YES];
        NSWindow *window = note.panel;
        YSResizeHandle *handle = note.resizeHandle;
        [window makeKeyAndOrderFront:nil];
        [window resetCursorRects];
        NSRect original = window.frame;
        NSPoint start = [window convertPointToScreen:[handle convertPoint:NSMakePoint(16, 16) toView:nil]];
        NSEvent *(^eventAt)(NSEventType, NSPoint) = ^NSEvent *(NSEventType type, NSPoint point) {
            return [NSEvent mouseEventWithType:type location:[window convertPointFromScreen:point]
                modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime
                windowNumber:window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
        };
        NSCursor *cursor = YSBottomRightResizeCursor();
        BOOL diagonal = cursor != NSCursor.crosshairCursor && cursor == YSBottomRightResizeCursor() &&
            NSEqualSizes(YSFallbackDiagonalResizeCursor().image.size, NSMakeSize(24, 24)) &&
            NSEqualPoints(YSFallbackDiagonalResizeCursor().hotSpot, NSMakePoint(12, 12));
        if (@available(macOS 15.0, *)) {
            diagonal = diagonal && [cursor isEqual:[NSCursor frameResizeCursorFromPosition:NSCursorFrameResizePositionBottomRight
                inDirections:NSCursorFrameResizeDirectionsAll]];
        }
        [handle mouseDown:eventAt(NSEventTypeLeftMouseDown, start)];
        BOOL held = handle.resizing && !window.areCursorRectsEnabled && NSCursor.currentCursor == cursor;
        BOOL anchored = YES, clamped = YES;
        NSPoint deltas[] = { {70,-40}, {-90,30}, {0,0}, {-1000,1000}, {30,-80} };
        for (NSUInteger index = 0; index < sizeof(deltas)/sizeof(deltas[0]); index++) {
            NSPoint point = NSMakePoint(start.x+deltas[index].x, start.y+deltas[index].y);
            [handle mouseDragged:eventAt(NSEventTypeLeftMouseDragged, point)];
            NSRect actual = window.frame;
            anchored = anchored && fabs(NSMinX(actual)-NSMinX(original))<0.01 &&
                fabs(NSMaxY(actual)-NSMaxY(original))<0.01;
            clamped = clamped && fabs(NSWidth(actual)-MAX(window.minSize.width, MIN(window.maxSize.width,
                NSWidth(original)+deltas[index].x)))<0.01 &&
                fabs(NSHeight(actual)-MAX(window.minSize.height, MIN(window.maxSize.height,
                NSHeight(original)-deltas[index].y)))<0.01;
            [handle resetCursorRects];
            held = held && NSCursor.currentCursor == cursor && !window.areCursorRectsEnabled;
        }
        [handle mouseUp:eventAt(NSEventTypeLeftMouseUp, start)];
        BOOL released = !handle.resizing && window.areCursorRectsEnabled;
        [window disableCursorRects];
        [handle mouseDown:eventAt(NSEventTypeLeftMouseDown, start)];
        [handle mouseUp:eventAt(NSEventTypeLeftMouseUp, start)];
        BOOL disabledKept = !handle.resizing && !window.areCursorRectsEnabled;
        [window enableCursorRects];
        [handle mouseDown:eventAt(NSEventTypeLeftMouseDown, start)];
        [handle cancelOperation:nil];
        BOOL cancelled = !handle.resizing && window.areCursorRectsEnabled;
        [handle mouseDown:eventAt(NSEventTypeLeftMouseDown, start)];
        [handle removeFromSuperview];
        BOOL detached = !handle.resizing && window.areCursorRectsEnabled;
        printf("resizeCursorDiagonal=%d resizeCursorHeld=%d resizeCursorReleased=%d resizeDragAnchored=%d resizeDragClamped=%d resizeCancelCleanup=%d resizeDetachCleanup=%d resizeDisabledStateKept=%d\n",
            diagonal, held, released, anchored, clamped, cancelled, detached, disabledKept);
        fflush(stdout);
        if (!(diagonal && held && released && anchored && clamped && cancelled && detached && disabledKept)) exit(EXIT_FAILURE);
        [NSApp terminate:nil];
    }
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--corner-check"]) {
        [self showEditor];
        YSRoundedPanelView *quickRoot = (YSRoundedPanelView *)self.panel.contentView;
        BOOL quick = YSPanelHasContinuousOutline(quickRoot);
        NSRect frame = self.panel.frame;
        frame.size.height = PanelMaximumHeight;
        [self.panel setFrame:frame display:YES];
        BOOL quickResized = YSPanelHasContinuousOutline(quickRoot);
        YSStickyNote *note = [self createStickyWithText:@"G3 轮廓缩放与命中检查"
            frame:NSMakeRect(100, 100, 420, 260) floating:YES];
        YSRoundedPanelView *noteRoot = (YSRoundedPanelView *)note.panel.contentView;
        BOOL sticky = YSPanelHasContinuousOutline(noteRoot);
        [note.panel setFrame:NSMakeRect(100, 100, StickyMinimumWidth, StickyMinimumHeight) display:YES];
        BOOL stickyResized = YSPanelHasContinuousOutline(noteRoot);
        [note.panel setFrame:NSMakeRect(100, 100, StickyMinimumWidth, 520) display:YES];
        BOOL stickyPortrait = YSPanelHasContinuousOutline(noteRoot);
        NSRect handleFrame = note.dragHandle.frame;
        NSPoint center = NSMakePoint(NSMidX(handleFrame), NSMidY(handleFrame));
        BOOL dragTarget = [note.dragHandle.superview hitTest:center] == note.dragHandle &&
            fabs(NSHeight(note.contentView.bounds)-NSMaxY(handleFrame)-DragHandleInset)<0.01;
        BOOL material = YES;
        if (@available(macOS 26.0, *)) {
            material = ((NSGlassEffectView *)self.glassEffectView).cornerRadius == 0 &&
                ((NSGlassEffectView *)note.glassEffectView).cornerRadius == 0;
        } else {
            material = self.panelSurfaceView.layer.cornerRadius == 0 && note.surfaceView.layer.cornerRadius == 0;
        }
        printf("g3QuickMask=%d g3QuickResize=%d g3StickyMask=%d g3StickyResize=%d g3StickyPortrait=%d g3SingleMaterialOutline=%d g3DragTarget=%d noWindowShadow=%d\n",
               quick, quickResized, sticky, stickyResized, stickyPortrait, material, dragTarget,
               !self.panel.hasShadow && !note.panel.hasShadow);
        fflush(stdout);
        [NSApp terminate:nil];
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--hotkey-switch-check"]) {
        CGKeyCode oldCode = self.hotkeyKeyCode;
        NSEventModifierFlags oldModifiers = self.hotkeyModifiers;
        [self unregisterHotKey];
        BOOL alternate = [self registerHotKeyForKeyCode:38
                                               modifiers:NSEventModifierFlagControl | NSEventModifierFlagOption];
        [self unregisterHotKey];
        BOOL restored = [self registerHotKeyForKeyCode:oldCode modifiers:oldModifiers];
        printf("alternateRegistered=%d originalRestored=%d\n", alternate, restored);
        fflush(stdout);
        [NSApp terminate:nil];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self saveEditorDraft];
    [self.draftSaveTimer invalidate];
    [self.stickySaveTimer invalidate];
    [self saveStickyNotes];
    [self.chordTimer invalidate];
    if (self.hotKeyRef) UnregisterEventHotKey(self.hotKeyRef);
    if (self.hotKeyHandlerRef) RemoveEventHandler(self.hotKeyHandlerRef);
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    for (NSString *argument in [[NSProcessInfo processInfo] arguments]) {
        if ([argument hasPrefix:@"--"] && ![argument isEqualToString:@"--open-settings"]) return NSTerminateNow;
    }
    if (!self.panel.isVisible) return NSTerminateNow;
    NSString *text = [self.textView.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return NSTerminateNow;
    [self saveEditorDraft];
    NSAlert *alert = [NSAlert new];
    alert.messageText = YSL(@"退出双轨记？");
    alert.informativeText = YSL(@"未保存的正文已暂存，下次呼出双轨记时可以继续编辑。");
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:YSL(@"取消")];
    [alert addButtonWithTitle:YSL(@"退出并放弃")];
    NSModalResponse response = [alert runModal];
    return response == NSAlertSecondButtonReturn ? NSTerminateNow : NSTerminateCancel;
}

- (void)loadPreferences {
    NSUserDefaults *defaults = YSPreferences();
    self.hotkeyKeyCode = (CGKeyCode)[defaults integerForKey:@"hotkeyKeyCode"];
    self.hotkeyModifiers = (NSEventModifierFlags)[defaults integerForKey:@"hotkeyModifiers"] & SupportedHotkeyModifiers();
    self.hotkeyKeyLabel = [defaults stringForKey:@"hotkeyKeyLabel"];
    if (self.hotkeyKeyLabel.length == 0) {
        self.hotkeyKeyLabel = KeyLabelForKeyCode(self.hotkeyKeyCode, nil);
    }
    if (self.hotkeyKeyCode == 0) self.hotkeyKeyCode = DefaultHotkeyKeyCode;
    if (self.hotkeyModifiers == 0) self.hotkeyModifiers = DefaultHotkeyModifiers;
    self.autoCopy = [defaults boolForKey:@"autoCopy"];
    self.autoOpen = [defaults boolForKey:@"autoOpen"];
    self.closeAfterSave = [defaults boolForKey:@"closeAfterSave"];
    self.stickyDefaultLevel = MAX(0, MIN(1, [defaults integerForKey:@"stickyDefaultLevel"]));
    self.stickyCloseAction = MAX(0, MIN(2, [defaults integerForKey:@"stickyCloseAction"]));
    self.hintText = [defaults stringForKey:@"hintText"] ?: DefaultHintText;
    self.hintPlacement = [defaults integerForKey:@"hintPlacement"];
    self.hintAlignment = [defaults integerForKey:@"hintAlignment"];
    self.hintPlacement = MAX(0, MIN(2, self.hintPlacement));
    self.hintAlignment = MAX(0, MIN(2, self.hintAlignment));
    self.quickGlass = ReadGlassAppearance(defaults, NO);
    self.stickyGlass = ReadGlassAppearance(defaults, YES);
    self.inputFontFamily = [defaults stringForKey:@"inputFontFamily"] ?: @"";
    self.inputFontSize = [defaults doubleForKey:@"inputFontSize"];
    if (self.inputFontSize < 12 || self.inputFontSize > 48) self.inputFontSize = 21;
    self.inputFontSize = round(self.inputFontSize);
    if (self.inputFontFamily.length > 0 &&
        ![[[NSFontManager sharedFontManager] availableFontFamilies] containsObject:self.inputFontFamily]) {
        self.inputFontFamily = @"";
    }
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    if (environment[@"VOICE_NOTE_FONT_FAMILY"]) {
        self.inputFontFamily = environment[@"VOICE_NOTE_FONT_FAMILY"];
    }
    if (environment[@"VOICE_NOTE_FONT_SIZE"]) {
        CGFloat overrideSize = [(NSString *)environment[@"VOICE_NOTE_FONT_SIZE"] doubleValue];
        if (overrideSize >= 8 && overrideSize <= 96) self.inputFontSize = round(overrideSize);
    }
}

- (NSString *)hotkeyDisplayString {
    return HotkeyDisplayString(self.hotkeyKeyCode, self.hotkeyModifiers, self.hotkeyKeyLabel);
}

- (NSFont *)inputFont {
    NSFont *font = nil;
    if (self.inputFontFamily.length > 0) {
        font = [[NSFontManager sharedFontManager] fontWithFamily:self.inputFontFamily
                                                          traits:0
                                                          weight:5
                                                            size:self.inputFontSize];
    }
    return font ?: [NSFont systemFontOfSize:self.inputFontSize];
}

- (void)buildMainMenu {
    NSMenu *mainMenu = [NSMenu new];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:YSL(@"双轨记") action:nil keyEquivalent:@""];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:YSL(@"双轨记")];
    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:YSL(@"关于双轨记") action:@selector(showAbout:) keyEquivalent:@""];
    aboutItem.target = self;
    [appMenu addItem:aboutItem];
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:YSL(@"设置…") action:@selector(openSettings:) keyEquivalent:@","];
    settingsItem.target = self;
    [appMenu addItem:settingsItem];
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:YSL(@"退出双轨记") action:@selector(quit) keyEquivalent:@"q"];
    quitItem.target = self;
    [appMenu addItem:quitItem];
    appMenuItem.submenu = appMenu;
    [mainMenu addItem:appMenuItem];

    NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:YSL(@"编辑") action:nil keyEquivalent:@""];
    NSMenu *editMenu = [NSMenu new];
    [editMenu addItemWithTitle:YSL(@"撤销") action:@selector(undo:) keyEquivalent:@"z"];
    NSMenuItem *redo = [editMenu addItemWithTitle:YSL(@"重做") action:@selector(redo:) keyEquivalent:@"z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:YSL(@"剪切") action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:YSL(@"复制") action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:YSL(@"粘贴") action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:YSL(@"全选") action:@selector(selectAll:) keyEquivalent:@"a"];
    editMenuItem.submenu = editMenu;
    [mainMenu addItem:editMenuItem];
    NSApp.mainMenu = mainMenu;
}

- (void)refreshHotkeyUI {
    NSString *display = [self hotkeyDisplayString];
    self.hotkeyMenuTitleItem.title = [NSString stringWithFormat:YSL(@"按住 %@ 呼出输入框"), display];
    self.statusItem.button.toolTip = [NSString stringWithFormat:YSL(@"左键打开输入框，右键打开菜单（%@）"), display];
    if (self.settingsHotkeyButton && !self.recordingHotkey) {
        [self.settingsHotkeyButton setTitle:display];
    }
}

- (void)buildStatusItem {
    if (!self.statusItem) self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    NSStatusBarButton *button = self.statusItem.button;
    NSImage *image = YSBrandImage(NSMakeSize(18, 18));
    button.image = image;
    button.toolTip = [NSString stringWithFormat:YSL(@"左键打开输入框，右键打开菜单（%@）"), [self hotkeyDisplayString]];
    button.target = self;
    button.action = @selector(handleStatusItemClick:);
    [button sendActionOn:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp];

    NSMenu *menu = [NSMenu new];
    NSMenuItem *openItem = [[NSMenuItem alloc] initWithTitle:YSL(@"打开输入框") action:@selector(showEditorFromMenu:) keyEquivalent:@""];
    openItem.target = self;
    [menu addItem:openItem];
    NSMenuItem *newStickyItem = [[NSMenuItem alloc] initWithTitle:YSL(@"新建空白便签") action:@selector(showStickyFromMenu:) keyEquivalent:@""];
    newStickyItem.target = self;
    [menu addItem:newStickyItem];
    NSMenuItem *showStickiesItem = [[NSMenuItem alloc] initWithTitle:YSL(@"显示全部便签") action:@selector(showAllStickies:) keyEquivalent:@""];
    showStickiesItem.target = self;
    [menu addItem:showStickiesItem];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *title = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:YSL(@"按住 %@ 呼出输入框"), [self hotkeyDisplayString]]
                                                    action:nil
                                             keyEquivalent:@""];
    title.enabled = NO;
    [menu addItem:title];
    self.hotkeyMenuTitleItem = title;
    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:YSL(@"设置…") action:@selector(openSettings:) keyEquivalent:@""];
    settingsItem.target = self;
    [menu addItem:settingsItem];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *folderItem = [[NSMenuItem alloc] initWithTitle:YSL(@"打开速记文件夹") action:@selector(openNotesFolder) keyEquivalent:@""];
    folderItem.target = self;
    [menu addItem:folderItem];
    NSMenuItem *lastItem = [[NSMenuItem alloc] initWithTitle:YSL(@"打开最近一条") action:@selector(openLastNote) keyEquivalent:@""];
    lastItem.target = self;
    [menu addItem:lastItem];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *loginItem = [[NSMenuItem alloc] initWithTitle:YSL(@"登录时启动") action:@selector(toggleLoginItem) keyEquivalent:@""];
    loginItem.target = self;
    loginItem.state = [SMAppService mainAppService].status == SMAppServiceStatusEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:loginItem];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:YSL(@"退出") action:@selector(quit) keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];
    self.statusMenu = menu;
}

- (void)showEditorFromMenu:(id)sender {
    [self showEditor];
}

- (void)handleStatusItemClick:(id)sender {
    NSEvent *event = [NSApp currentEvent];
    BOOL secondary = event.type == NSEventTypeRightMouseUp ||
                     (event.type == NSEventTypeLeftMouseUp && (event.modifierFlags & NSEventModifierFlagControl));
    if (secondary) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.statusItem popUpStatusItemMenu:self.statusMenu];
#pragma clang diagnostic pop
    } else {
        [self showEditor];
    }
}

- (void)buildPanel {
    NSSize size = NSMakeSize(PanelWidth, PanelMinimumHeight);
    self.panel = [[YSEditorPanel alloc] initWithContentRect:NSMakeRect(0, 0, size.width, size.height)
                                                  styleMask:NSWindowStyleMaskBorderless
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    self.panel.opaque = NO;
    self.panel.title = YSL(@"双轨记快捷输入");
    self.panel.backgroundColor = [NSColor clearColor];
    self.panel.hasShadow = NO;
    self.panel.level = NSFloatingWindowLevel;
    self.panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                    NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.panel.releasedWhenClosed = NO;
    self.panel.hidesOnDeactivate = NO;
    self.panel.movableByWindowBackground = NO;
    self.panel.delegate = self;
    self.panel.minSize = NSMakeSize(PanelWidth, PanelMinimumHeight);

    NSView *surfaceView = nil;
    NSView *contentView = nil;
    if (@available(macOS 26.0, *)) {
        NSGlassEffectView *glass = [[NSGlassEffectView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
        glass.cornerRadius = 0; // The root view supplies the complete G3 outline.
        glass.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        contentView = [[NSView alloc] initWithFrame:glass.bounds];
        contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        glass.contentView = contentView;
        self.glassEffectView = glass;
        surfaceView = glass;
    } else {
        NSVisualEffectView *visual = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
        visual.material = NSVisualEffectMaterialHUDWindow;
        visual.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        visual.state = NSVisualEffectStateActive;
        visual.wantsLayer = YES;
        visual.layer.cornerRadius = 0;
        visual.layer.masksToBounds = YES;
        visual.layer.borderWidth = 0;
        visual.layer.borderColor = [[NSColor colorWithWhite:1 alpha:0.18] CGColor];
        visual.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        contentView = [[NSView alloc] initWithFrame:visual.bounds];
        contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [visual addSubview:contentView];
        surfaceView = visual;
    }
    self.panelSurfaceView = surfaceView;
    self.panelContentView = contentView;
    [self applyGlassPreferences];

    self.statusLabel = [NSTextField labelWithString:self.hintText ?: @""];
    self.statusLabel.font = [NSFont systemFontOfSize:12];
    self.statusLabel.textColor = [NSColor colorWithWhite:1 alpha:0.55];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.statusLabel.maximumNumberOfLines = 1;

    NSScrollView *scrollView = [NSScrollView new];
    self.textScrollView = scrollView;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.drawsBackground = NO;
    scrollView.borderType = NSNoBorder;
    scrollView.hasVerticalScroller = NO;
    scrollView.autohidesScrollers = YES;

    self.textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, PanelWidth - 40, 84)];
    self.textView.delegate = self;
    self.textView.editable = YES;
    self.textView.selectable = YES;
    self.textView.richText = NO;
    self.textView.allowsUndo = YES;
    self.textView.automaticQuoteSubstitutionEnabled = NO;
    self.textView.automaticDashSubstitutionEnabled = NO;
    self.textView.automaticTextReplacementEnabled = NO;
    self.textView.continuousSpellCheckingEnabled = NO;
    self.textView.grammarCheckingEnabled = NO;
    self.textView.drawsBackground = NO;
    self.textView.backgroundColor = [NSColor clearColor];
    self.textView.textColor = [NSColor whiteColor];
    self.textView.insertionPointColor = [NSColor whiteColor];
    self.textView.font = [self inputFont];
    self.textView.textContainerInset = NSMakeSize(2, 6);
    self.textView.verticallyResizable = YES;
    self.textView.horizontallyResizable = NO;
    self.textView.autoresizingMask = NSViewWidthSizable;
    self.textView.textContainer.widthTracksTextView = YES;
    self.textView.textContainer.containerSize = NSMakeSize(PanelWidth - 44, CGFLOAT_MAX);
    scrollView.documentView = self.textView;

    [contentView addSubview:self.statusLabel];
    [contentView addSubview:scrollView];
    YSDragHandle *handle = [[YSDragHandle alloc] initWithFrame:NSMakeRect(0, 0, DragHandleDiameter, DragHandleDiameter)];
    self.editorDragHandle = handle;
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.toolTip = YSL(@"拖动左上圆点移动窗口");
    [contentView addSubview:handle];
    self.pinButton = YSSymbolButton(@"pin", YSL(@"钉为桌面便签（保留文本并独立保存）"), self, @selector(pinEditor:));
    self.pinButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.pinButton setAccessibilityIdentifier:@"pin-editor"];
    [contentView addSubview:self.pinButton];
    self.saveButton = YSImageButton(YSFloppyDiskImage(), YSL(@"存盘：保存为 Markdown（回车）"), self, @selector(commitEditor));
    self.saveButton.refusesFirstResponder = YES;
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.saveButton setAccessibilityIdentifier:@"save-editor"];
    [contentView addSubview:self.saveButton];
    [NSLayoutConstraint activateConstraints:@[
        [handle.widthAnchor constraintEqualToConstant:DragHandleDiameter],
        [handle.heightAnchor constraintEqualToConstant:DragHandleDiameter],
        [handle.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:DragHandleInset],
        [handle.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:DragHandleInset],
    ]];
    self.hintTopConstraint = [self.statusLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:18];
    self.hintBottomConstraint = [self.statusLabel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-12];
    self.hintLeadingFullConstraint = [self.statusLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20];
    self.hintLeadingAfterLogoConstraint = [self.statusLabel.leadingAnchor
        constraintEqualToAnchor:contentView.leadingAnchor
                       constant:DragHandleInset + DragHandleDiameter + 12];
    self.hintTrailingFullConstraint = [self.statusLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20];
    self.hintTrailingBeforeActionsConstraint = [self.statusLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-90];
    self.scrollBottomToVisualConstraint = [scrollView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-12];
    self.scrollBottomToHintConstraint = [scrollView.bottomAnchor constraintEqualToAnchor:self.statusLabel.topAnchor constant:-4];
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [scrollView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [scrollView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:PanelHeaderHeight],
        [self.pinButton.widthAnchor constraintEqualToConstant:30],
        [self.pinButton.heightAnchor constraintEqualToConstant:30],
        [self.pinButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-12],
        [self.pinButton.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:11],
        [self.saveButton.widthAnchor constraintEqualToConstant:30],
        [self.saveButton.heightAnchor constraintEqualToConstant:30],
        [self.saveButton.trailingAnchor constraintEqualToAnchor:self.pinButton.leadingAnchor constant:-6],
        [self.saveButton.centerYAnchor constraintEqualToAnchor:self.pinButton.centerYAnchor],
    ]];
    YSRoundedPanelView *roundedRoot = [[YSRoundedPanelView alloc] initWithFrame:surfaceView.bounds];
    roundedRoot.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [roundedRoot addSubview:surfaceView];
    self.panel.contentView = roundedRoot;
    [self updateHintLayout];
}

- (void)applyGlassAppearance:(YSGlassAppearance)appearance toSurface:(NSView *)surface content:(NSView *)content {
    if (!surface) return;
    NSColor *tint = appearance.tintStrength > 0
        ? [NSColor colorWithWhite:0.16 alpha:appearance.tintStrength] : nil;
    if (@available(macOS 26.0, *)) {
        if ([surface isKindOfClass:NSGlassEffectView.class]) {
            NSGlassEffectView *glass = (NSGlassEffectView *)surface;
            glass.style = appearance.style == 1 ? NSGlassEffectViewStyleClear : NSGlassEffectViewStyleRegular;
            glass.tintColor = tint;
            if (@available(macOS 27.0, *)) {
                SEL setter = NSSelectorFromString(@"setEffectIsInteractive:");
                if ([glass respondsToSelector:setter])
                    ((void (*)(id, SEL, BOOL))objc_msgSend)(glass, setter, appearance.interactive);
            }
            return;
        }
    }
    // Earlier systems still get distinct, separately adjustable native vibrancy.
    content.wantsLayer = YES;
    content.layer.backgroundColor = (tint ?: NSColor.clearColor).CGColor;
}

- (void)applyGlassPreferences {
    [self applyGlassAppearance:self.quickGlass toSurface:self.panelSurfaceView content:self.panelContentView];
    for (YSStickyNote *note in self.stickyNotes)
        [self applyGlassAppearance:self.stickyGlass toSurface:note.surfaceView content:note.contentView];
}

- (void)startInputMonitor {
    EventTypeSpec eventTypes[] = {
        { kEventClassKeyboard, kEventHotKeyPressed },
        { kEventClassKeyboard, kEventHotKeyReleased },
    };
    OSStatus handlerStatus = InstallApplicationEventHandler(&YSHotKeyHandler,
                                                            GetEventTypeCount(eventTypes),
                                                            eventTypes,
                                                            (__bridge void *)self,
                                                            &_hotKeyHandlerRef);
    if (handlerStatus != noErr) {
        YSLog(@"failed to install hotkey handler: %d", (int)handlerStatus);
    }
    BOOL registered = NO;
    if (handlerStatus == noErr) {
        registered = [self registerHotKeyForKeyCode:self.hotkeyKeyCode modifiers:self.hotkeyModifiers];
    }
    if (!registered) {
        YSLog(@"carbon hotkey registration failed; using key-state polling for %@", [self hotkeyDisplayString]);
    }
    self.carbonHotKeyRegistered = registered;

    __weak typeof(self) weakSelf = self;
    self.chordTimer = [NSTimer timerWithTimeInterval:0.02 repeats:YES block:^(NSTimer *timer) {
        [weakSelf checkPhysicalChord];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.chordTimer forMode:NSRunLoopCommonModes];
}

- (void)unregisterHotKey {
    if (self.hotKeyRef) {
        UnregisterEventHotKey(self.hotKeyRef);
        self.hotKeyRef = NULL;
    }
    self.carbonHotKeyRegistered = NO;
}

- (BOOL)registerHotKeyForKeyCode:(CGKeyCode)keyCode modifiers:(NSEventModifierFlags)modifiers {
    if (keyCode == 0 || !(modifiers & (NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand))) {
        return NO;
    }
    EventHotKeyID hotKeyID = { YSHotKeySignature, 1 };
    EventHotKeyRef newRef = NULL;
    OSStatus status = RegisterEventHotKey(keyCode, CarbonModifiersForFlags(modifiers), hotKeyID,
                                          GetApplicationEventTarget(), kEventHotKeyNoOptions, &newRef);
    if (status != noErr) return NO;
    self.hotKeyRef = newRef;
    self.carbonHotKeyRegistered = YES;
    return YES;
}

- (void)saveHotkeyPreferences {
    NSUserDefaults *defaults = YSPreferences();
    [defaults setInteger:self.hotkeyKeyCode forKey:@"hotkeyKeyCode"];
    [defaults setInteger:self.hotkeyModifiers forKey:@"hotkeyModifiers"];
    [defaults setObject:self.hotkeyKeyLabel ?: @"" forKey:@"hotkeyKeyLabel"];
}

- (BOOL)isPhysicalChordDown {
    CGEventSourceStateID state = kCGEventSourceStateCombinedSessionState;
    if (!CGEventSourceKeyState(state, self.hotkeyKeyCode)) return NO;
    if ((self.hotkeyModifiers & NSEventModifierFlagControl) &&
        !CGEventSourceKeyState(state, 59) && !CGEventSourceKeyState(state, 62)) return NO;
    if ((self.hotkeyModifiers & NSEventModifierFlagOption) &&
        !CGEventSourceKeyState(state, 58) && !CGEventSourceKeyState(state, 61)) return NO;
    if ((self.hotkeyModifiers & NSEventModifierFlagShift) &&
        !CGEventSourceKeyState(state, 56) && !CGEventSourceKeyState(state, 60)) return NO;
    if ((self.hotkeyModifiers & NSEventModifierFlagCommand) &&
        !CGEventSourceKeyState(state, 55) && !CGEventSourceKeyState(state, 54)) return NO;
    return YES;
}

- (void)checkPhysicalChord {
    if (self.carbonHotKeyRegistered || self.recordingHotkey) return;
    BOOL down = [self isPhysicalChordDown];
    if (down && !self.shortcutDown) {
        YSLog(@"physical chord pressed");
        [self handleHotkeyPressed];
    } else if (!down && self.shortcutDown) {
        YSLog(@"physical chord released");
        [self handleHotkeyReleased];
    }
}

- (void)handleHotkeyPressed {
    if (self.shortcutDown) return;
    self.shortcutDown = YES;
    if (self.recordingHotkey) return;
    if (self.panel.isVisible) {
        [self requestCloseEditor];
    } else {
        [self showEditor];
    }
}

- (void)handleHotkeyReleased {
    self.shortcutDown = NO;
}

- (void)showEditor {
    YSLog(@"show editor");
    self.isConfirmingClose = NO;
    if (!self.panel.isVisible) {
        self.textView.string = @"";
        NSString *draft = [NSString stringWithContentsOfURL:EditorDraftURL() encoding:NSUTF8StringEncoding error:nil];
        if (draft.length) self.textView.string = draft;
        [self updatePanelSizeForContent];
        [self positionPanelIfNeeded];
    }
    [self restoreHintText];
    [NSApp activateIgnoringOtherApps:YES];
    [self.panel makeKeyAndOrderFront:nil];
    [self.panel makeFirstResponder:self.textView];
    [self.panel orderFrontRegardless];
    [self updatePanelSizeForContent];
}

- (void)discardEditor {
    self.textView.string = @"";
    [self restoreHintText];
    self.isConfirmingClose = NO;
    [self.panel orderOut:nil];
    [self updatePanelSizeForContent];
}

- (void)saveEditorDraft {
    NSString *text = self.pendingOpenText ?: self.textView.string ?: @"";
    if (text.length == 0 && self.pendingOpenNoteURL) return;
    NSURL *url = EditorDraftURL();
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager createDirectoryAtURL:url.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil]) return;
    NSError *error = nil;
    if (text.length) {
        if (![text writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error]) YSLog(@"cannot save editor draft: %@", error);
    } else if ([manager fileExistsAtPath:url.path]) {
        if (![manager removeItemAtURL:url error:&error]) YSLog(@"cannot clear editor draft: %@", error);
    }
}

- (void)requestCloseEditor {
    if (!self.panel.isVisible || self.isConfirmingClose) return;
    NSString *text = [self.textView.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) {
        [self discardEditor];
        return;
    }
    self.isConfirmingClose = YES;
    [NSApp activateIgnoringOtherApps:YES];
    [self.panel makeKeyAndOrderFront:nil];
    NSAlert *alert = [NSAlert new];
    alert.messageText = YSL(@"放弃这次输入？");
    alert.informativeText = YSL(@"输入框里还有未保存的内容，关闭后会丢失。");
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:YSL(@"继续编辑")];
    [alert addButtonWithTitle:YSL(@"放弃并关闭")];
    __weak typeof(self) weakSelf = self;
    [alert beginSheetModalForWindow:self.panel completionHandler:^(NSModalResponse response) {
        weakSelf.isConfirmingClose = NO;
        if (response == NSAlertSecondButtonReturn) {
            [weakSelf discardEditor];
        } else {
            [weakSelf.panel makeFirstResponder:weakSelf.textView];
        }
    }];
}

- (void)commitEditor {
    if (self.pendingOpenNoteURL) {
        [self openSavedNote:self.pendingOpenNoteURL];
        return;
    }
    if (self.openingNote) {
        self.statusLabel.stringValue = YSL(@"已保存，正在打开 Obsidian…");
        return;
    }
    NSString *text = [self.textView.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) {
        self.statusLabel.stringValue = YSL(@"还没有输入内容");
        NSBeep();
        return;
    }
    NSURL *notesFolderURL = ConfiguredNotesFolder();
    NSURL *vaultURL = ObsidianVaultRootForFolder(notesFolderURL);
    NSError *error = nil;
    NSURL *noteURL = WriteNote(text, notesFolderURL, &error);
    if (!noteURL) {
        [self showFailure:error.localizedDescription];
        return;
    }
    self.lastNoteURL = noteURL;
    YSLog(@"note saved path=%@ chars=%lu", noteURL.path, (unsigned long)text.length);
    [YSPreferences() setObject:noteURL.path forKey:@"lastNotePath"];

    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    if (self.autoCopy && !environment[@"VOICE_NOTE_NO_CLIPBOARD"]) {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        [pasteboard setString:text forType:NSPasteboardTypeString];
    }

    if (self.autoOpen && vaultURL && !environment[@"VOICE_NOTE_NO_OPEN"]) {
        self.pendingOpenText = self.textView.string ?: text;
        self.pendingOpenNoteURL = noteURL;
        [self openSavedNote:noteURL];
        return;
    }
    [self finishSavedEditor:self.autoCopy ? YSL(@"已保存并复制") : YSL(@"已保存")];
}

- (void)finishSavedEditor:(NSString *)message {
    self.textView.string = @"";
    self.pendingOpenText = nil;
    self.pendingOpenNoteURL = nil;
    self.openingNote = NO;
    [self.draftSaveTimer invalidate];
    [self saveEditorDraft];
    self.statusLabel.stringValue = message;
    [self updatePanelSizeForContent];
    if (self.closeAfterSave) {
        [self.panel orderOut:nil];
    } else {
        [self.panel makeFirstResponder:self.textView];
    }
}

- (void)openSavedNote:(NSURL *)noteURL {
    if (self.openingNote) return;
    if (![[NSFileManager defaultManager] fileExistsAtPath:noteURL.path]) {
        [self noteOpenFailed:YSL(@"找不到刚保存的文件，正文仍保留在输入框。")];
        return;
    }
    NSURL *obsidianURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"md.obsidian"];
    if (!obsidianURL) {
        [self noteOpenFailed:YSL(@"没有找到 Obsidian，文件已保存，正文仍保留。")];
        return;
    }
    self.openingNote = YES;
    self.statusLabel.stringValue = YSL(@"已保存，正在打开 Obsidian…");
    [self.panel makeKeyAndOrderFront:nil];
    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration new];
    configuration.activates = YES;
    YSLog(@"request Obsidian open saved file path=%@", noteURL.path);
    __weak typeof(self) weakSelf = self;
    [[NSWorkspace sharedWorkspace] openURLs:@[noteURL]
                     withApplicationAtURL:obsidianURL
                            configuration:configuration
                        completionHandler:^(NSRunningApplication *app, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!app || error) {
                YSLog(@"Obsidian open rejected path=%@ error=%@", noteURL.path, error);
                [weakSelf noteOpenFailed:error.localizedDescription];
                return;
            }
            YSLog(@"Obsidian accepted saved file path=%@", noteURL.path);
            [weakSelf finishSavedEditor:weakSelf.autoCopy ? YSL(@"已保存并复制") : YSL(@"已保存")];
        });
    }];
}

- (void)noteOpenFailed:(NSString *)message {
    self.openingNote = NO;
    if (self.pendingOpenText) self.textView.string = self.pendingOpenText;
    [self updatePanelSizeForContent];
    [NSApp activateIgnoringOtherApps:YES];
    [self.panel makeKeyAndOrderFront:nil];
    self.statusLabel.stringValue = YSL(@"文件已保存，但未能打开。回车重试，原文仍在。");
    NSAlert *alert = [NSAlert new];
    alert.messageText = YSL(@"笔记已保存，但 Obsidian 未能打开");
    alert.informativeText = [NSString stringWithFormat:YSL(@"%@\n\n文件：%@\n\n原文已保留；回到输入框按回车可重试打开，不会重复保存。"),
                              message.length ? message : YSL(@"系统没有接受打开请求。"), self.pendingOpenNoteURL.path ?: @""];
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:YSL(@"返回原文")];
    [alert beginSheetModalForWindow:self.panel completionHandler:nil];
}

- (void)showFailure:(NSString *)message {
    self.statusLabel.stringValue = message.length ? message : YSL(@"语音笔记保存失败");
    NSBeep();
}

#pragma mark - Sticky notes

- (YSStickyNote *)stickyForTextView:(NSTextView *)textView {
    for (YSStickyNote *note in self.stickyNotes) if (note.textView == textView) return note;
    return nil;
}

- (void)applyStickyLevel:(YSStickyNote *)note {
    [note.levelButton setAccessibilityLabel:YSL(@"切换置顶／置底")];
    note.panel.level = note.floating ? NSFloatingWindowLevel : NSNormalWindowLevel - 1;
    NSImageSymbolConfiguration *configuration =
        [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium];
    note.levelButton.image = [[NSImage imageWithSystemSymbolName:note.floating ? @"arrow.up.to.line" : @"arrow.down.to.line"
                                                               accessibilityDescription:YSL(@"切换便签层级")]
        imageWithSymbolConfiguration:configuration];
    note.levelButton.toolTip = note.floating ? YSL(@"当前置顶；点击放到普通窗口下方") : YSL(@"当前置底；点击置顶显示");
}

- (NSView *)glassSurfaceForSticky:(YSStickyNote *)note size:(NSSize)size content:(NSView **)contentOut {
    NSView *surface = nil;
    NSView *content = nil;
    if (@available(macOS 26.0, *)) {
        NSGlassEffectView *glass = [[NSGlassEffectView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
        glass.cornerRadius = 0; // The root view supplies the complete G3 outline.
        note.glassEffectView = glass;
        content = [[NSView alloc] initWithFrame:glass.bounds];
        glass.contentView = content;
        surface = glass;
    } else {
        NSVisualEffectView *visual = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
        visual.material = NSVisualEffectMaterialHUDWindow;
        visual.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        visual.state = NSVisualEffectStateActive;
        content = [[NSView alloc] initWithFrame:visual.bounds];
        [visual addSubview:content];
        surface = visual;
    }
    surface.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    content.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    if (!note.glassEffectView) {
        surface.wantsLayer = YES;
        surface.layer.cornerRadius = 0;
        surface.layer.masksToBounds = YES;
    }
    *contentOut = content;
    note.surfaceView = surface;
    note.contentView = content;
    return surface;
}

- (YSStickyNote *)createStickyWithText:(NSString *)text frame:(NSRect)frame floating:(BOOL)floating {
    YSStickyNote *note = [YSStickyNote new];
    note.identifier = [NSUUID UUID].UUIDString;
    note.floating = floating;
    note.panel = [[YSEditorPanel alloc] initWithContentRect:frame
                                                  styleMask:NSWindowStyleMaskBorderless
                                                    backing:NSBackingStoreBuffered defer:NO];
    note.panel.opaque = NO;
    note.panel.title = YSL(@"双轨记便签");
    note.panel.backgroundColor = [NSColor clearColor];
    note.panel.hasShadow = NO;
    note.panel.releasedWhenClosed = NO;
    note.panel.hidesOnDeactivate = NO;
    note.panel.movableByWindowBackground = NO;
    note.panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    note.panel.minSize = NSMakeSize(StickyMinimumWidth, StickyMinimumHeight);
    note.panel.delegate = self;
    NSView *content = nil;
    NSView *surface = [self glassSurfaceForSticky:note size:frame.size content:&content];

    note.textScrollView = [NSScrollView new];
    note.textScrollView.drawsBackground = NO;
    note.textScrollView.borderType = NSNoBorder;
    note.textScrollView.hasVerticalScroller = YES;
    note.textScrollView.autohidesScrollers = YES;
    note.textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, NSWidth(frame) - 40, 100)];
    note.textView.delegate = self;
    note.textView.richText = NO;
    note.textView.allowsUndo = YES;
    note.textView.automaticQuoteSubstitutionEnabled = NO;
    note.textView.automaticDashSubstitutionEnabled = NO;
    note.textView.automaticTextReplacementEnabled = NO;
    note.textView.continuousSpellCheckingEnabled = NO;
    note.textView.drawsBackground = NO;
    note.textView.textColor = [NSColor whiteColor];
    note.textView.insertionPointColor = [NSColor whiteColor];
    note.textView.font = [self inputFont];
    note.textView.textContainerInset = NSMakeSize(2, 6);
    note.textView.verticallyResizable = YES;
    note.textView.horizontallyResizable = NO;
    note.textView.autoresizingMask = NSViewWidthSizable;
    note.textView.textContainer.widthTracksTextView = YES;
    note.textView.textContainer.containerSize = NSMakeSize(NSWidth(frame) - 44, CGFLOAT_MAX);
    note.textView.string = text ?: @"";
    note.textScrollView.documentView = note.textView;
    [content addSubview:note.textScrollView];
    note.statusLabel = YSLabel(@"", NSMakeRect(20, 5, NSWidth(frame) - 60, 18),
                               [NSFont systemFontOfSize:10], [NSColor colorWithWhite:1 alpha:0.65]);
    note.statusLabel.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    [content addSubview:note.statusLabel];

    YSDragHandle *handle = [[YSDragHandle alloc] initWithFrame:NSMakeRect(DragHandleInset, NSHeight(frame) - DragHandleInset - DragHandleDiameter,
                                                                          DragHandleDiameter, DragHandleDiameter)];
    handle.autoresizingMask = NSViewMinYMargin;
    note.dragHandle = handle;
    handle.sticky = YES;
    handle.toolTip = YSL(@"拖动左上圆点移动便签");
    [content addSubview:handle];
    note.levelButton = YSSymbolButton(@"arrow.up.to.line", YSL(@"切换置顶／置底"), self, @selector(toggleStickyLevel:));
    note.levelButton.frame = NSMakeRect(NSWidth(frame) - 78, NSHeight(frame) - 41, 30, 30);
    note.levelButton.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    [note.levelButton setAccessibilityIdentifier:@"sticky-level"];
    [content addSubview:note.levelButton];
    NSButton *close = YSSymbolButton(@"xmark", YSL(@"关闭便签"), self, @selector(closeSticky:));
    close.frame = NSMakeRect(NSWidth(frame) - 42, NSHeight(frame) - 41, 30, 30);
    close.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    [close setAccessibilityIdentifier:@"sticky-close"];
    [content addSubview:close];
    YSResizeHandle *resize = [[YSResizeHandle alloc] initWithFrame:NSMakeRect(NSWidth(frame) - 28, 4, 24, 24)];
    note.resizeHandle = resize;
    resize.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
    resize.toolTip = YSL(@"拖动调整便签大小");
    [resize setAccessibilityLabel:YSL(@"调整便签大小")];
    [content addSubview:resize];

    note.textScrollView.frame = NSMakeRect(20, 28, NSWidth(frame) - 40, NSHeight(frame) - PanelHeaderHeight - 28);
    note.textScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    YSRoundedPanelView *root = [[YSRoundedPanelView alloc] initWithFrame:surface.bounds];
    root.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:surface];
    note.panel.contentView = root;
    [self.stickyNotes addObject:note];
    [self applyStickyLevel:note];
    [self applyGlassPreferences];
    return note;
}

- (void)saveStickyNotes {
    if (self.savingStickies) return;
    self.savingStickies = YES;
    NSURL *url = StickyStoreURL();
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:url.URLByDeletingLastPathComponent
                                  withIntermediateDirectories:YES attributes:nil error:&error]) {
        YSLog(@"cannot create sticky store directory: %@", error);
        self.savingStickies = NO;
        return;
    }
    NSMutableArray *records = [NSMutableArray array];
    for (YSStickyNote *note in self.stickyNotes) [records addObject:note.dictionaryRepresentation];
    NSDictionary *store = @{@"version": @1, @"notes": records};
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:store format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    if (!data || ![data writeToURL:url options:NSDataWritingAtomic error:&error]) YSLog(@"cannot save stickies: %@", error);
    self.savingStickies = NO;
    [self refreshStickyCount];
}

- (void)refreshStickyCount {
    self.settingsStickyCountLabel.stringValue = [NSString stringWithFormat:YSL(@"当前有 %lu 张便签；文本、位置和尺寸会自动保存。"), (unsigned long)self.stickyNotes.count];
}

- (void)restoreStickyNotes {
    NSDictionary *store = ReadStickyStore();
    NSArray *records = [store[@"notes"] isKindOfClass:[NSArray class]] ? store[@"notes"] : nil;
    if (!records) return;
    for (NSDictionary *record in records) {
        if (![record isKindOfClass:[NSDictionary class]] || ![record[@"id"] isKindOfClass:[NSString class]] ||
            ![record[@"text"] isKindOfClass:[NSString class]]) continue;
        NSRect frame = NSMakeRect([record[@"x"] doubleValue], [record[@"y"] doubleValue],
                                  MAX(StickyMinimumWidth, [record[@"width"] doubleValue]),
                                  MAX(StickyMinimumHeight, [record[@"height"] doubleValue]));
        if (!isfinite(frame.origin.x) || !isfinite(frame.origin.y) || !isfinite(frame.size.width) || !isfinite(frame.size.height)) continue;
        YSStickyNote *note = [self createStickyWithText:record[@"text"] frame:frame floating:[record[@"floating"] boolValue]];
        note.identifier = record[@"id"];
        note.restoredTopLeft = NSStringFromPoint(NSMakePoint(NSMinX(frame), NSMaxY(frame)));
        [note.panel orderFront:nil];
    }
    [self constrainRestoredStickies];
    [self saveStickyNotes];
}

- (void)constrainRestoredStickies {
    for (YSStickyNote *note in self.stickyNotes) {
        if (!note.restoredTopLeft) continue;
        NSPoint topLeft = NSPointFromString(note.restoredTopLeft);
        NSScreen *screen = nil;
        for (NSScreen *candidate in NSScreen.screens) {
            if (NSPointInRect(topLeft, candidate.visibleFrame)) { screen = candidate; break; }
        }
        if (!screen) screen = NSScreen.mainScreen;
        NSRect visible = screen.visibleFrame;
        NSSize size = NSMakeSize(MIN(note.panel.frame.size.width, NSWidth(visible) - 24),
                                 MIN(note.panel.frame.size.height, NSHeight(visible) - 24));
        NSPoint origin = NSMakePoint(MAX(NSMinX(visible) + 12, MIN(topLeft.x, NSMaxX(visible) - size.width - 12)),
                                     MAX(NSMinY(visible) + 12, MIN(topLeft.y - size.height, NSMaxY(visible) - size.height - 12)));
        note.suppressCallbacks = YES;
        [note.panel setFrame:NSMakeRect(origin.x, origin.y, size.width, size.height) display:NO];
        note.suppressCallbacks = NO;
        note.restoredTopLeft = nil;
    }
}

- (void)pinEditor:(id)sender {
    NSString *text = self.textView.string ?: @"";
    NSRect frame = self.panel.frame;
    CGFloat top = NSMaxY(frame);
    frame.size.width = MAX(frame.size.width, StickyMinimumWidth);
    frame.size.height = MAX(frame.size.height, StickyMinimumHeight);
    frame.origin.y = top - frame.size.height;
    YSStickyNote *note = [self createStickyWithText:text frame:frame floating:self.stickyDefaultLevel == 0];
    [note.panel makeKeyAndOrderFront:nil];
    [note.panel makeFirstResponder:note.textView];
    [self saveStickyNotes];
    [self discardEditor];
    [note.dragHandle animateAttachment];
    YSLog(@"pinned editor as sticky %@", note.identifier);
}

- (void)showStickyFromMenu:(id)sender {
    NSScreen *screen = [self panelScreen];
    NSRect visible = screen.visibleFrame;
    CGFloat offset = (self.stickyNotes.count % 8) * 24;
    NSRect frame = NSMakeRect(NSMidX(visible) - 160 + offset, NSMidY(visible) - 120 - offset, 320, 240);
    YSStickyNote *note = [self createStickyWithText:@"" frame:frame floating:self.stickyDefaultLevel == 0];
    [self saveStickyNotes];
    [NSApp activateIgnoringOtherApps:YES];
    [note.panel makeKeyAndOrderFront:nil];
    [note.panel makeFirstResponder:note.textView];
    [note.dragHandle animateAttachment];
}

- (void)showAllStickies:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    for (YSStickyNote *note in self.stickyNotes) {
        [note.panel orderFront:nil];
        note.panel.level = NSFloatingWindowLevel;
        [note.panel orderFront:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([self.stickyNotes containsObject:note]) [self applyStickyLevel:note];
        });
    }
}

- (void)toggleStickyLevel:(NSButton *)sender {
    for (YSStickyNote *note in self.stickyNotes) {
        if (note.levelButton != sender) continue;
        note.floating = !note.floating;
        [self applyStickyLevel:note];
        [self saveStickyNotes];
        break;
    }
}

- (void)commitSticky:(YSStickyNote *)note {
    if (![note.textView.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length) { NSBeep(); return; }
    if (![self saveStickyCopy:note]) return;
    note.statusLabel.stringValue = YSL(@"已另存到速记库；便签仍保留");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self.stickyNotes containsObject:note]) note.statusLabel.stringValue = @"";
    });
}

- (void)showStickyError:(NSString *)message forNote:(YSStickyNote *)note {
    NSAlert *alert = [NSAlert new];
    alert.messageText = YSL(@"无法保存便签内容");
    alert.informativeText = message ?: YSL(@"请稍后重试。便签仍保留。");
    [alert beginSheetModalForWindow:note.panel completionHandler:nil];
}

- (BOOL)saveStickyCopy:(YSStickyNote *)note {
    NSString *text = [note.textView.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length) return YES;
    NSError *error = nil;
    NSURL *url = WriteNote(text, ConfiguredNotesFolder(), &error);
    if (!url) { [self showStickyError:error.localizedDescription forNote:note]; return NO; }
    self.lastNoteURL = url;
    [YSPreferences() setObject:url.path forKey:@"lastNotePath"];
    return YES;
}

- (void)removeSticky:(YSStickyNote *)note saveCopy:(BOOL)saveCopy {
    if (saveCopy && ![self saveStickyCopy:note]) return;
    [self.stickyNotes removeObjectIdenticalTo:note];
    note.panel.delegate = nil;
    [note.panel close];
    [self saveStickyNotes];
}

- (void)requestCloseSticky:(YSStickyNote *)note {
    if (note.panel.attachedSheet) return;
    BOOL save = self.stickyCloseAction == 2;
    if (self.stickyCloseAction != 0) { [self removeSticky:note saveCopy:save]; return; }
    NSAlert *alert = [NSAlert new];
    alert.messageText = YSL(@"关闭这张便签？");
    alert.informativeText = YSL(@"关闭后这张便签不会再恢复。也可先把正文另存一份到速记库。");
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:YSL(@"取消")];
    [alert addButtonWithTitle:YSL(@"仅关闭")];
    [alert addButtonWithTitle:YSL(@"另存速记并关闭")];
    [alert beginSheetModalForWindow:note.panel completionHandler:^(NSModalResponse response) {
        if (response == NSAlertSecondButtonReturn || response == NSAlertThirdButtonReturn) {
            [self removeSticky:note saveCopy:response == NSAlertThirdButtonReturn];
        }
    }];
}

- (void)closeSticky:(NSButton *)sender {
    for (YSStickyNote *note in [self.stickyNotes copy]) {
        if ([sender isDescendantOf:note.panel.contentView]) { [self requestCloseSticky:note]; break; }
    }
}

- (BOOL)isHintVisible {
    return self.hintPlacement != 2 && self.hintText.length > 0;
}

- (NSString *)effectiveHintText {
    NSString *text = self.hintText ?: @"";
    NSString *key = @"回车或软盘存盘 · 图钉变便签";
    if ([text isEqualToString:YSLocalizedInLanguage(key, @"zh-Hans")] ||
        [text isEqualToString:YSLocalizedInLanguage(key, @"en")]) return YSL(key);
    return text;
}

- (void)restoreHintText {
    self.statusLabel.stringValue = [self effectiveHintText];
    self.statusLabel.toolTip = [self effectiveHintText];
}

- (void)updateHintLayout {
    if (!self.statusLabel) return;
    BOOL visible = [self isHintVisible];
    [NSLayoutConstraint deactivateConstraints:@[
        self.hintTopConstraint,
        self.hintBottomConstraint,
        self.hintLeadingFullConstraint,
        self.hintLeadingAfterLogoConstraint,
        self.hintTrailingFullConstraint,
        self.hintTrailingBeforeActionsConstraint,
        self.scrollBottomToVisualConstraint,
        self.scrollBottomToHintConstraint,
    ]];

    self.statusLabel.hidden = !visible;
    if (visible) {
        if (self.hintPlacement == 1) {
            [NSLayoutConstraint activateConstraints:@[
                self.hintBottomConstraint,
                self.hintLeadingFullConstraint,
                self.hintTrailingFullConstraint,
                self.scrollBottomToHintConstraint,
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                self.hintTopConstraint,
                self.hintLeadingAfterLogoConstraint,
                self.hintTrailingBeforeActionsConstraint,
                self.scrollBottomToVisualConstraint,
            ]];
        }
    } else {
        [NSLayoutConstraint activateConstraints:@[self.scrollBottomToVisualConstraint]];
    }

    if (self.hintAlignment == 1) {
        self.statusLabel.alignment = NSTextAlignmentCenter;
    } else if (self.hintAlignment == 2) {
        self.statusLabel.alignment = NSTextAlignmentRight;
    } else {
        self.statusLabel.alignment = NSTextAlignmentLeft;
    }
    [self restoreHintText];
    [self updatePanelSizeForContent];
}

- (void)updatePanelSizeForContent {
    if (!self.panel) return;
    NSTextContainer *container = self.textView.textContainer;
    CGFloat textWidth = PanelWidth - 44;
    container.containerSize = NSMakeSize(textWidth, CGFLOAT_MAX);
    [self.textView.layoutManager ensureLayoutForTextContainer:container];
    CGFloat usedHeight = ceil([self.textView.layoutManager usedRectForTextContainer:container].size.height);
    CGFloat textHeight = usedHeight + self.textView.textContainerInset.height * 2;
    CGFloat chromeHeight = PanelHeaderHeight + 12;
    if ([self isHintVisible] && self.hintPlacement == 1) chromeHeight += 19;
    CGFloat rawHeight = chromeHeight + textHeight + 6;
    CGFloat desiredHeight = MAX(PanelMinimumHeight, MIN(PanelMaximumHeight, rawHeight));
    BOOL needsScroller = rawHeight > PanelMaximumHeight;
    if (self.textScrollView.hasVerticalScroller != needsScroller) {
        self.textScrollView.hasVerticalScroller = needsScroller;
    }

    NSRect frame = self.panel.frame;
    CGFloat top = NSMaxY(frame);
    NSRect newFrame = NSMakeRect(frame.origin.x, top - desiredHeight, PanelWidth, desiredHeight);
    NSScreen *screen = [self panelScreen];
    if (screen) {
        NSRect visible = screen.visibleFrame;
        CGFloat minY = NSMinY(visible) + 16;
        if (NSMinY(newFrame) < minY) newFrame.origin.y = minY;
    }
    if (!NSEqualRects(frame, newFrame)) {
        self.suppressWindowMoveSave = YES;
        [self.panel setFrame:newFrame display:YES animate:NO];
        self.suppressWindowMoveSave = NO;
    }
    [self.textView scrollRangeToVisible:self.textView.selectedRange];
}

- (NSScreen *)panelScreen {
    if (self.panel.isVisible) {
        NSScreen *screen = self.panel.screen;
        if (screen) return screen;
    }
    NSPoint mouse = [NSEvent mouseLocation];
    for (NSScreen *candidate in [NSScreen screens]) {
        if (NSMouseInRect(mouse, candidate.frame, NO)) return candidate;
    }
    return [NSScreen mainScreen];
}

- (void)positionPanelIfNeeded {
    NSScreen *screen = [self panelScreen];
    if (!screen) return;
    NSUserDefaults *defaults = YSPreferences();
    NSRect frame = self.panel.frame;
    BOOL restored = NO;
    if ([defaults objectForKey:@"panelTopLeftX"] && [defaults objectForKey:@"panelTopLeftY"]) {
        CGFloat x = [defaults doubleForKey:@"panelTopLeftX"];
        CGFloat top = [defaults doubleForKey:@"panelTopLeftY"];
        for (NSScreen *candidate in [NSScreen screens]) {
            NSRect visible = candidate.visibleFrame;
            if (x >= NSMinX(visible) && x <= NSMaxX(visible) && top >= NSMinY(visible) && top <= NSMaxY(visible)) {
                frame.origin.x = x;
                frame.origin.y = top - frame.size.height;
                screen = candidate;
                restored = YES;
                break;
            }
        }
    }
    if (!restored) {
        NSRect visible = screen.visibleFrame;
        frame.origin.x = NSMidX(visible) - frame.size.width / 2;
        frame.origin.y = NSMinY(visible) + NSHeight(visible) * 0.65 - frame.size.height / 2;
    }
    NSRect visible = screen.visibleFrame;
    CGFloat minX = NSMinX(visible) + 16;
    CGFloat maxX = NSMaxX(visible) - frame.size.width - 16;
    CGFloat minY = NSMinY(visible) + 16;
    CGFloat maxY = NSMaxY(visible) - frame.size.height - 16;
    frame.origin.x = MAX(minX, MIN(maxX, frame.origin.x));
    frame.origin.y = MAX(minY, MIN(maxY, frame.origin.y));
    self.suppressWindowMoveSave = YES;
    [self.panel setFrameOrigin:frame.origin];
    self.suppressWindowMoveSave = NO;
}

- (void)windowDidResize:(NSNotification *)notification {
    for (YSStickyNote *note in self.stickyNotes) {
        if (note.panel == notification.object) {
            note.dragHandle.frame = NSMakeRect(DragHandleInset,
                NSHeight(note.panel.contentView.bounds) - DragHandleInset - DragHandleDiameter,
                DragHandleDiameter, DragHandleDiameter);

        }
        if (note.panel == notification.object && !note.suppressCallbacks) { [self saveStickyNotes]; break; }
    }
}

- (void)windowDidMove:(NSNotification *)notification {
    if (notification.object == self.panel && !self.suppressWindowMoveSave && self.panel.isVisible) {
        NSRect frame = self.panel.frame;
        NSUserDefaults *defaults = YSPreferences();
        [defaults setDouble:NSMinX(frame) forKey:@"panelTopLeftX"];
        [defaults setDouble:NSMaxY(frame) forKey:@"panelTopLeftY"];
    }
    for (YSStickyNote *note in self.stickyNotes) {
        if (note.panel == notification.object && !note.suppressCallbacks) { [self saveStickyNotes]; break; }
    }
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    if (sender == self.panel) {
        [self requestCloseEditor];
        return NO;
    }
    for (YSStickyNote *note in self.stickyNotes) {
        if (sender == note.panel) { [self requestCloseSticky:note]; return NO; }
    }
    return YES;
}

- (void)textDidChange:(NSNotification *)notification {
    if (notification.object != self.textView) {
        if ([self stickyForTextView:notification.object]) {
            [self.stickySaveTimer invalidate];
            self.stickySaveTimer = [NSTimer scheduledTimerWithTimeInterval:0.35 repeats:NO block:^(NSTimer *timer) {
                [self saveStickyNotes];
            }];
        }
        return;
    }
    if (self.panel.isVisible) {
        [self restoreHintText];
    }
    [self updatePanelSizeForContent];
    [self.draftSaveTimer invalidate];
    self.draftSaveTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:NO block:^(NSTimer *timer) {
        [self saveEditorDraft];
    }];
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (textView.hasMarkedText) return NO;
    YSStickyNote *note = [self stickyForTextView:textView];
    if (note) {
        if (commandSelector == @selector(insertNewline:)) {
            if ([NSApp currentEvent].modifierFlags & NSEventModifierFlagCommand) {
                [self commitSticky:note];
                return YES;
            }
            return NO;
        }
        if (commandSelector == @selector(cancelOperation:)) {
            [note.panel makeFirstResponder:nil];
            return YES;
        }
        return NO;
    }
    if (textView != self.textView) return NO;
    if (commandSelector == @selector(insertNewline:)) {
        NSEvent *event = [NSApp currentEvent];
        if (event.modifierFlags & NSEventModifierFlagShift) {
            return NO;
        }
        [self commitEditor];
        return YES;
    }
    if (commandSelector == @selector(cancelOperation:)) {
        [self requestCloseEditor];
        return YES;
    }
    return NO;
}

- (void)openSettings:(id)sender {
    if (!self.settingsWindow) [self buildSettingsWindow];
    [self refreshSettingsUI];
    [NSApp activateIgnoringOtherApps:YES];
    [self.settingsWindow makeKeyAndOrderFront:nil];
}

- (void)showAbout:(id)sender {
    [NSApp orderFrontStandardAboutPanelWithOptions:@{NSAboutPanelOptionApplicationName:YSL(@"双轨记")}];
}

- (void)languageChanged:(NSPopUpButton *)sender {
    NSString *language = sender.selectedItem.representedObject ?: @"system";
    if ([language isEqualToString:YSLanguagePreference()]) return;
    if (self.recordingHotkey) [self cancelHotkeyCapture];
    YSSetLanguagePreference(language);
    [self refreshInterfaceLanguage];
}

- (void)refreshInterfaceLanguage {
    // Keep the editor and every sticky intact: only their interface strings
    // change. In particular, never replace note text or re-register shortcuts.
    [self buildMainMenu];
    [self buildStatusItem];
    self.panel.title = YSL(@"双轨记快捷输入");
    self.editorDragHandle.sticky = NO;
    self.editorDragHandle.toolTip = YSL(@"拖动左上圆点移动窗口");
    self.pinButton.toolTip = YSL(@"钉为桌面便签（保留文本并独立保存）");
    [self.pinButton setAccessibilityLabel:self.pinButton.toolTip];
    self.saveButton.toolTip = YSL(@"存盘：保存为 Markdown（回车）");
    [self.saveButton setAccessibilityLabel:self.saveButton.toolTip];
    for (YSStickyNote *note in self.stickyNotes) {
        note.panel.title = YSL(@"双轨记便签");
        note.dragHandle.sticky = YES;
        note.dragHandle.toolTip = YSL(@"拖动左上圆点移动便签");
        note.resizeHandle.toolTip = YSL(@"拖动调整便签大小");
        [note.resizeHandle setAccessibilityLabel:YSL(@"调整便签大小")];
        [self applyStickyLevel:note];
        for (NSView *view in note.contentView.subviews) {
            if ([view.accessibilityIdentifier isEqualToString:@"sticky-close"]) {
                view.toolTip = YSL(@"关闭便签");
                [view setAccessibilityLabel:view.toolTip];
            }
        }
    }
    [self restoreHintText];
    [self refreshStickyCount];
    if (self.settingsWindow) {
        NSWindow *previous = self.settingsWindow;
        BOOL visible = previous.isVisible;
        NSRect frame = previous.frame;
        NSInteger page = self.settingsPageControl.selectedSegment;
        [previous makeFirstResponder:nil];
        [previous setFrameAutosaveName:@""];
        previous.delegate = nil;
        [previous orderOut:nil];
        [previous close];
        [self buildSettingsWindow];
        [self.settingsWindow setFrame:frame display:NO];
        self.settingsPageControl.selectedSegment = MAX(0,MIN(1,page));
        [self settingsPageChanged:nil];
        [self refreshSettingsUI];
        if (visible) [self.settingsWindow makeKeyAndOrderFront:nil];
    }
}

- (NSView *)glassSettingsSectionForSticky:(BOOL)sticky {
    YSGlassControls *controls = [YSGlassControls new];
    if (sticky) self.stickyGlassControls = controls; else self.quickGlassControls = controls;
    NSString *name = sticky ? YSL(@"桌面便签") : YSL(@"快捷输入框");
    NSString *identifier = sticky ? @"sticky-glass" : @"quick-glass";
    controls.style = YSSegmentedControl(@[YSL(@"标准"), YSL(@"通透")], NSMakeRect(0, 0, 200, 26), self, @selector(glassOptionsChanged:));
    controls.style.tag = sticky;
    [controls.style setAccessibilityLabel:[NSString stringWithFormat:YSL(@"%@玻璃风格"), name]];
    [controls.style setAccessibilityIdentifier:[identifier stringByAppendingString:@"-style"]];
    controls.interactive = [NSButton checkboxWithTitle:YSL(@"交互光效") target:self action:@selector(glassOptionsChanged:)];
    controls.interactive.tag = sticky;
    controls.interactive.toolTip = YSL(@"macOS 27 起可用");
    [controls.interactive setAccessibilityLabel:[NSString stringWithFormat:YSL(@"%@交互光效"), name]];
    controls.tint = [NSSlider sliderWithValue:0 minValue:0 maxValue:0.60 target:self action:@selector(glassOptionsChanged:)];
    controls.tint.tag = sticky;
    controls.tint.continuous = YES;
    [controls.tint.widthAnchor constraintEqualToConstant:230].active = YES;
    [controls.tint setAccessibilityLabel:[NSString stringWithFormat:YSL(@"%@染色强度"), name]];
    [controls.tint setAccessibilityIdentifier:[identifier stringByAppendingString:@"-tint"]];
    controls.tint.toolTip = YSL(@"加深玻璃的灰色调，提升文字对比度；不改变窗口尺寸。");
    controls.tintValue = YSLabel(@"", NSZeroRect, [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular], NSColor.secondaryLabelColor);
    [controls.tintValue.widthAnchor constraintEqualToConstant:42].active = YES;
    controls.availabilityHint = YSHelp(@"");
    NSButton *reset = [NSButton buttonWithTitle:YSL(@"恢复默认外观") target:self action:@selector(resetGlassOptions:)];
    reset.tag = sticky;
    reset.bezelStyle = NSBezelStyleRounded;
    [reset setAccessibilityLabel:[NSString stringWithFormat:YSL(@"%@恢复默认外观"), name]];
    NSString *scope = sticky ? YSL(@"仅影响桌面便签；当前和新建便签会一起更新。") : YSL(@"仅影响快捷输入框；钉成便签后会切换为便签外观。");
    return YSSection([NSString stringWithFormat:YSL(@"%@ · 玻璃外观"), name], @[
        YSRow(YSL(@"风格"), controls.style),
        YSRow(YSL(@"染色"), YSStack(@[controls.tint, controls.tintValue], NSUserInterfaceLayoutOrientationHorizontal, 12)),
        YSStack(@[controls.interactive, reset], NSUserInterfaceLayoutOrientationHorizontal, 24),
        YSHelp(scope), controls.availabilityHint]);
}

- (void)refreshGlassControls {
    BOOL glassAvailable = NO, interactiveAvailable = NO;
    if (@available(macOS 26.0, *)) glassAvailable = YES;
    if (@available(macOS 27.0, *)) interactiveAvailable = YES;
    for (NSUInteger index = 0; index < 2; index++) {
        YSGlassControls *controls = index == 0 ? self.quickGlassControls : self.stickyGlassControls;
        YSGlassAppearance appearance = index == 0 ? self.quickGlass : self.stickyGlass;
        controls.style.selectedSegment = appearance.style;
        controls.style.enabled = glassAvailable;
        controls.interactive.enabled = interactiveAvailable;
        controls.interactive.state = interactiveAvailable && appearance.interactive ? NSControlStateValueOn : NSControlStateValueOff;
        controls.tint.doubleValue = appearance.tintStrength;
        controls.tintValue.stringValue = [NSString stringWithFormat:@"%.0f%%", appearance.tintStrength * 100];
        controls.availabilityHint.stringValue = glassAvailable
            ? (interactiveAvailable ? YSL(@"浅色背景推荐标准玻璃；通透适合深色或彩色背景。") : YSL(@"液态玻璃已启用；交互光效需 macOS 27。"))
            : YSL(@"当前使用原生磨砂材质，仍可分别调整染色强度。");
    }
}

- (void)resetGlassOptions:(NSControl *)sender {
    BOOL sticky = sender.tag == 1;
    YSGlassAppearance appearance = DefaultGlassAppearance(sticky);
    if (sticky) self.stickyGlass = appearance; else self.quickGlass = appearance;
    WriteGlassAppearance(YSPreferences(), sticky, appearance);
    [self applyGlassPreferences];
    [self refreshGlassControls];
}

- (void)buildSettingsWindow {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 620, 740)
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered defer:NO];
    window.title = YSL(@"双轨记设置");
    window.contentMinSize = NSMakeSize(560, 480);
    window.releasedWhenClosed = NO;
    window.delegate = self;
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    [window center];
    if (![[NSProcessInfo processInfo].environment[@"YIN_SU_ISOLATED"] boolValue]) {
        [window setFrameUsingName:@"YinSuSettingsWindowV6"];
        [window setFrameAutosaveName:@"YinSuSettingsWindowV6"];
    }
    self.settingsWindow = window;
    NSView *root = window.contentView;
    [root.widthAnchor constraintGreaterThanOrEqualToConstant:560].active = YES;
    [root.heightAnchor constraintGreaterThanOrEqualToConstant:480].active = YES;
    NSTextField *title = YSLabel(YSL(@"双轨记"), NSZeroRect, [NSFont systemFontOfSize:22 weight:NSFontWeightSemibold], [NSColor labelColor]);
    NSTextField *subtitle = YSHelp(YSL(@"主线继续，灵感先记。") );
    NSStackView *identity = YSStack(@[title, subtitle], NSUserInterfaceLayoutOrientationVertical, 4);
    [root addSubview:identity];
    self.settingsPageControl = YSSegmentedControl(@[YSL(@"通用"), YSL(@"便签")], NSMakeRect(0, 0, 152, 30), self, @selector(settingsPageChanged:));
    self.settingsPageControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.settingsPageControl.segmentStyle = NSSegmentStyleRounded;
    self.settingsPageControl.font = [NSFont systemFontOfSize:13];
    [root addSubview:self.settingsPageControl];

    self.settingsLanguagePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.settingsLanguagePopup.target = self;
    self.settingsLanguagePopup.action = @selector(languageChanged:);
    for (NSString *language in @[@"system", @"zh-Hans", @"en"]) {
        NSString *label = [language isEqualToString:@"system"] ? YSL(@"跟随系统") :
            ([language isEqualToString:@"zh-Hans"] ? @"简体中文" : @"English");
        [self.settingsLanguagePopup addItemWithTitle:label];
        self.settingsLanguagePopup.lastItem.representedObject = language;
    }
    [self.settingsLanguagePopup.widthAnchor constraintEqualToConstant:230].active = YES;
    [self.settingsLanguagePopup setAccessibilityLabel:YSL(@"界面语言")];
    [self.settingsLanguagePopup setAccessibilityIdentifier:@"ui-language"];
    NSView *languageSection = YSSection(YSL(@"界面语言"), @[self.settingsLanguagePopup,
        YSHelp(YSL(@"更改语言不会修改笔记或自定义提示文字。"))]);

    self.settingsFolderField = [NSTextField textFieldWithString:@""];
    self.settingsFolderField.editable = NO;
    self.settingsFolderField.selectable = YES;
    self.settingsFolderField.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.settingsFolderField.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.settingsFolderField setAccessibilityLabel:YSL(@"笔记保存文件夹")];
    [self.settingsFolderField setContentCompressionResistancePriority:250 forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSButton *choose = [NSButton buttonWithTitle:YSL(@"选择文件夹…") target:self action:@selector(chooseNotesFolder:)];
    choose.bezelStyle = NSBezelStyleRounded;
    [choose setContentHuggingPriority:750 forOrientation:NSLayoutConstraintOrientationHorizontal];
    self.settingsFolderHint = YSHelp(YSL(@"在 Obsidian 库内选择文件夹，每条速记保存为独立 Markdown。") );
    NSView *folderSection = YSSection(YSL(@"保存位置"), @[
        YSStack(@[self.settingsFolderField, choose], NSUserInterfaceLayoutOrientationHorizontal, 10), self.settingsFolderHint]);

    self.settingsHotkeyButton = [NSButton buttonWithTitle:[self hotkeyDisplayString] target:self action:@selector(recordHotkey:)];
    self.settingsHotkeyButton.bezelStyle = NSBezelStyleRounded;
    self.settingsHotkeyButton.font = [NSFont monospacedSystemFontOfSize:14 weight:NSFontWeightMedium];
    [self.settingsHotkeyButton.widthAnchor constraintEqualToConstant:200].active = YES;
    [self.settingsHotkeyButton setAccessibilityLabel:YSL(@"录制呼出快捷键")];
    NSButton *reset = [NSButton buttonWithTitle:YSL(@"恢复默认") target:self action:@selector(resetHotkey:)];
    reset.bezelStyle = NSBezelStyleRounded;
    NSView *hotkeyRow = YSStack(@[self.settingsHotkeyButton, reset], NSUserInterfaceLayoutOrientationHorizontal, 12);
    self.settingsHotkeyHint = YSHelp(YSL(@"点击按钮录制新组合；Esc 取消。") );
    [self.settingsHotkeyHint.heightAnchor constraintGreaterThanOrEqualToConstant:32].active = YES;
    NSView *hotkeySection = YSSection(YSL(@"呼出快捷键"), @[hotkeyRow, self.settingsHotkeyHint]);

    NSView *quickGlassSection = [self glassSettingsSectionForSticky:NO];
    NSView *stickyGlassSection = [self glassSettingsSectionForSticky:YES];
    self.settingsFontFamilyPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.settingsFontFamilyPopup.target = self;
    self.settingsFontFamilyPopup.action = @selector(fontOptionsChanged:);
    [self.settingsFontFamilyPopup addItemWithTitle:YSL(@"系统默认")];
    self.settingsFontFamilyPopup.lastItem.representedObject = @"";
    for (NSString *family in [[[NSFontManager sharedFontManager] availableFontFamilies] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
        [self.settingsFontFamilyPopup addItemWithTitle:family];
        self.settingsFontFamilyPopup.lastItem.representedObject = family;
    }
    [self.settingsFontFamilyPopup.widthAnchor constraintEqualToConstant:276].active = YES;
    self.settingsFontSizePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.settingsFontSizePopup.target = self;
    self.settingsFontSizePopup.action = @selector(fontOptionsChanged:);
    for (NSInteger size = 12; size <= 48; size++) {
        [self.settingsFontSizePopup addItemWithTitle:[NSString stringWithFormat:@"%ld", (long)size]];
        self.settingsFontSizePopup.lastItem.representedObject = @(size);
    }
    [self.settingsFontSizePopup.widthAnchor constraintEqualToConstant:72].active = YES;
    [self.settingsFontFamilyPopup setAccessibilityLabel:YSL(@"输入字体")];
    [self.settingsFontSizePopup setAccessibilityLabel:YSL(@"输入字号")];
    self.settingsHintField = [NSTextField textFieldWithString:@""];
    self.settingsHintField.placeholderString = YSL(@"输入框提示文字，留空隐藏");
    self.settingsHintField.font = [NSFont systemFontOfSize:12];
    self.settingsHintField.delegate = self;
    [self.settingsHintField setAccessibilityLabel:YSL(@"输入框提示文字")];
    self.settingsHintPlacementControl = YSSegmentedControl(@[YSL(@"顶部"), YSL(@"底部"), YSL(@"隐藏")], NSMakeRect(0, 0, 200, 26), self, @selector(hintOptionsChanged:));
    self.settingsHintAlignmentControl = YSSegmentedControl(@[YSL(@"左"), YSL(@"居中"), YSL(@"右")], NSMakeRect(0, 0, 200, 26), self, @selector(hintOptionsChanged:));
    NSView *appearanceSection = YSSection(YSL(@"输入字体与提示"), @[
        YSRow(YSL(@"字体"), YSStack(@[self.settingsFontFamilyPopup, self.settingsFontSizePopup], NSUserInterfaceLayoutOrientationHorizontal, 10)),
        YSRow(YSL(@"提示"), self.settingsHintField), YSRow(YSL(@"位置"), self.settingsHintPlacementControl),
        YSRow(YSL(@"对齐"), self.settingsHintAlignmentControl)]);

    self.autoCopyCheckbox = [NSButton checkboxWithTitle:YSL(@"保存后复制到剪贴板") target:self action:@selector(optionsChanged:)];
    self.autoOpenCheckbox = [NSButton checkboxWithTitle:YSL(@"保存后在 Obsidian 中打开") target:self action:@selector(optionsChanged:)];
    self.closeAfterSaveCheckbox = [NSButton checkboxWithTitle:YSL(@"保存后收起输入窗口") target:self action:@selector(optionsChanged:)];
    self.loginAtStartupCheckbox = [NSButton checkboxWithTitle:YSL(@"登录时启动双轨记") target:self action:@selector(loginOptionChanged:)];
    NSView *behaviorSection = YSSection(YSL(@"保存与启动"), @[self.autoCopyCheckbox, self.autoOpenCheckbox, self.closeAfterSaveCheckbox, self.loginAtStartupCheckbox]);

    self.settingsStickyCountLabel = YSHelp(@"" );
    self.settingsStickyLevelControl = YSSegmentedControl(@[YSL(@"置顶"), YSL(@"置底")], NSMakeRect(0, 0, 240, 28), self, @selector(stickyOptionsChanged:));
    self.settingsStickyCloseControl = YSSegmentedControl(@[YSL(@"每次询问"), YSL(@"直接关闭"), YSL(@"另存后关闭")], NSMakeRect(0, 0, 390, 28), self, @selector(stickyOptionsChanged:));
    NSView *stickyOptions = YSSection(YSL(@"桌面便签"), @[self.settingsStickyCountLabel,
        YSRow(YSL(@"新便签"), self.settingsStickyLevelControl), YSHelp(YSL(@"显示层级只影响新便签；每张便签右上角可以独立切换。") ),
        YSRow(YSL(@"关闭时"), self.settingsStickyCloseControl), YSHelp(YSL(@"关闭会移除这张便签。“另存后关闭”会先将正文保存到速记库。") )]);
    NSView *stickyGuide = YSSection(YSL(@"留在手边，随时继续"), @[
        YSHelp(YSL(@"点击速记框右上角的图钉，将当前内容转为独立便签。快捷键仍可呼出新的速记框。") ),
        YSHelp(YSL(@"回车换行 · ⌘ 回车另存速记 · Esc 退出编辑\n左上圆点移动 · 右下手柄调整大小") ),
        YSHelp(YSL(@"正文、位置、尺寸与层级自动保存在本机，重新启动后恢复。") )]);
    NSButton *newSticky = [NSButton buttonWithTitle:YSL(@"新建空白便签") target:self action:@selector(showStickyFromMenu:)];
    NSButton *showStickies = [NSButton buttonWithTitle:YSL(@"显示全部便签") target:self action:@selector(showAllStickies:)];
    newSticky.bezelStyle = showStickies.bezelStyle = NSBezelStyleRounded;
    NSView *stickyActions = YSSection(YSL(@"快速操作"), @[YSStack(@[newSticky, showStickies], NSUserInterfaceLayoutOrientationHorizontal, 12)]);

    NSTabView *tabs = [NSTabView new];
    tabs.translatesAutoresizingMaskIntoConstraints = NO;
    tabs.tabViewType = NSNoTabsNoBorder;
    self.settingsTabView = tabs;
    for (NSInteger index = 0; index < 2; index++) {
        NSTabViewItem *tab = [[NSTabViewItem alloc] initWithIdentifier:index == 0 ? @"general" : @"stickies"];
        tab.label = index == 0 ? YSL(@"通用") : YSL(@"便签");
        tab.view = YSSettingsPage(index == 0 ? @[languageSection, folderSection, hotkeySection, quickGlassSection, appearanceSection, behaviorSection] : @[stickyGlassSection, stickyOptions, stickyGuide, stickyActions]);
        [tabs addTabViewItem:tab];
    }
    [root addSubview:tabs];
    NSView *separator = YSSeparator(NSZeroRect);
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:separator];
    NSTextField *footer = YSHelp(YSL(@"修改立即生效") );
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:footer];
    NSButton *done = [NSButton buttonWithTitle:YSL(@"完成") target:self action:@selector(closeSettings:)];
    done.translatesAutoresizingMaskIntoConstraints = NO;
    done.bezelStyle = NSBezelStyleRounded;
    done.keyEquivalent = @"\r";
    [root addSubview:done];
    [NSLayoutConstraint activateConstraints:@[
        [identity.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:28],
        [identity.topAnchor constraintEqualToAnchor:root.topAnchor constant:18],
        [self.settingsPageControl.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-28],
        [self.settingsPageControl.centerYAnchor constraintEqualToAnchor:identity.centerYAnchor],
        [self.settingsPageControl.widthAnchor constraintEqualToConstant:[YSCurrentLanguage() isEqualToString:@"en"] ? 180 : 160],
        [tabs.topAnchor constraintEqualToAnchor:identity.bottomAnchor constant:14],
        [tabs.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [tabs.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [tabs.bottomAnchor constraintEqualToAnchor:separator.topAnchor constant:-4],
        [separator.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [separator.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],
        [separator.heightAnchor constraintEqualToConstant:1],
        [separator.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-54],
        [done.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],
        [done.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-12],
        [done.widthAnchor constraintEqualToConstant:80],
        [footer.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:28],
        [footer.centerYAnchor constraintEqualToAnchor:done.centerYAnchor],
    ]];
}

- (void)settingsPageChanged:(id)sender {
    [self.settingsTabView selectTabViewItemAtIndex:self.settingsPageControl.selectedSegment];
}

- (void)refreshSettingsUI {
    if (!self.settingsWindow) return;
    for (NSMenuItem *item in self.settingsLanguagePopup.itemArray) {
        if ([item.representedObject isEqual:YSLanguagePreference()]) {
            [self.settingsLanguagePopup selectItem:item];
            break;
        }
    }
    self.settingsFolderField.stringValue = ConfiguredNotesFolder().path;
    self.settingsFolderField.toolTip = self.settingsFolderField.stringValue;
    NSURL *vaultURL = ObsidianVaultRootForFolder(ConfiguredNotesFolder());
    self.settingsFolderHint.stringValue = vaultURL ? YSL(@"每条速记保存为独立 Markdown，原文仍保留在你的 Obsidian 库中。") : YSL(@"请先选择 Obsidian 库内的文件夹，才能保存速记。");
    self.settingsFolderHint.textColor = vaultURL ? [NSColor secondaryLabelColor] : [NSColor systemOrangeColor];
    if (!vaultURL) {
        self.settingsFolderField.textColor = [NSColor systemRedColor];
    } else {
        self.settingsFolderField.textColor = [NSColor labelColor];
    }
    self.autoCopyCheckbox.state = self.autoCopy ? NSControlStateValueOn : NSControlStateValueOff;
    self.autoOpenCheckbox.state = self.autoOpen ? NSControlStateValueOn : NSControlStateValueOff;
    self.closeAfterSaveCheckbox.state = self.closeAfterSave ? NSControlStateValueOn : NSControlStateValueOff;
    self.settingsStickyLevelControl.selectedSegment = self.stickyDefaultLevel;
    self.settingsStickyCloseControl.selectedSegment = self.stickyCloseAction;
    self.settingsStickyCountLabel.stringValue = [NSString stringWithFormat:YSL(@"当前有 %lu 张便签；文本、位置和尺寸会自动保存。"), (unsigned long)self.stickyNotes.count];
    self.settingsHintField.stringValue = [self effectiveHintText];
    self.settingsHintPlacementControl.selectedSegment = self.hintPlacement;
    self.settingsHintAlignmentControl.selectedSegment = self.hintAlignment;
    [self refreshGlassControls];
    NSInteger selectedFamilyIndex = 0;
    for (NSInteger index = 0; index < self.settingsFontFamilyPopup.numberOfItems; index++) {
        NSMenuItem *item = [self.settingsFontFamilyPopup itemAtIndex:index];
        id represented = item.representedObject;
        if ([represented isKindOfClass:[NSString class]] &&
            [(NSString *)represented isEqualToString:self.inputFontFamily ?: @""]) {
            selectedFamilyIndex = index;
            break;
        }
    }
    [self.settingsFontFamilyPopup selectItemAtIndex:selectedFamilyIndex];
    [self.settingsFontSizePopup selectItemWithTitle:[NSString stringWithFormat:@"%.0f", self.inputFontSize]];
    self.loginAtStartupCheckbox.state = [SMAppService mainAppService].status == SMAppServiceStatusEnabled
        ? NSControlStateValueOn : NSControlStateValueOff;
    if (!self.recordingHotkey) {
        [self.settingsHotkeyButton setTitle:[self hotkeyDisplayString]];
        NSInteger conflictID = SystemHotkeyConflictID(self.hotkeyKeyCode, self.hotkeyModifiers);
        NSString *reserved = ReservedAppHotkeyReason(self.hotkeyKeyCode, self.hotkeyModifiers);
        if (conflictID > 0 || reserved.length > 0) {
            self.settingsHotkeyHint.stringValue = conflictID > 0
                ? [SystemHotkeyConflictDescription(conflictID) stringByAppendingString:@"。"]
                : reserved;
            self.settingsHotkeyHint.textColor = [NSColor systemRedColor];
        } else {
            self.settingsHotkeyHint.stringValue = YSL(@"点击左侧按钮后按下新组合；至少包含 Control、Option 或 Command。Esc 取消录制。");
            self.settingsHotkeyHint.textColor = [NSColor secondaryLabelColor];
        }
    }
}

- (void)chooseNotesFolder:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = NO;
    panel.canCreateDirectories = YES;
    panel.directoryURL = ConfiguredNotesFolder();
    panel.prompt = YSL(@"选择");
    panel.message = YSL(@"选择一个 Obsidian 库中的保存文件夹");
    __weak typeof(self) weakSelf = self;
    [panel beginSheetModalForWindow:self.settingsWindow completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK || !panel.URL) return;
        NSURL *selected = [panel.URL URLByStandardizingPath];
        if (!ObsidianVaultRootForFolder(selected)) {
            NSAlert *alert = [NSAlert new];
            alert.messageText = YSL(@"这个文件夹不在 Obsidian 库内");
            alert.informativeText = YSL(@"请选择包含 .obsidian 配置目录的库，或库中的子文件夹。");
            alert.alertStyle = NSAlertStyleWarning;
            [alert beginSheetModalForWindow:weakSelf.settingsWindow completionHandler:nil];
            return;
        }
        NSUserDefaults *defaults = YSPreferences();
        [defaults setObject:selected.path forKey:@"notesFolderPath"];
        [defaults removeObjectForKey:@"vaultPath"];
        [defaults removeObjectForKey:@"folderName"];
        [weakSelf refreshSettingsUI];
    }];
}

- (void)optionsChanged:(id)sender {
    NSUserDefaults *defaults = YSPreferences();
    self.autoCopy = self.autoCopyCheckbox.state == NSControlStateValueOn;
    self.autoOpen = self.autoOpenCheckbox.state == NSControlStateValueOn;
    self.closeAfterSave = self.closeAfterSaveCheckbox.state == NSControlStateValueOn;
    [defaults setBool:self.autoCopy forKey:@"autoCopy"];
    [defaults setBool:self.autoOpen forKey:@"autoOpen"];
    [defaults setBool:self.closeAfterSave forKey:@"closeAfterSave"];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if (notification.object != self.settingsHintField) return;
    self.hintText = self.settingsHintField.stringValue ?: @"";
    [YSPreferences() setObject:self.hintText forKey:@"hintText"];
    [self updateHintLayout];
}

- (void)hintOptionsChanged:(id)sender {
    self.hintPlacement = self.settingsHintPlacementControl.selectedSegment;
    self.hintAlignment = self.settingsHintAlignmentControl.selectedSegment;
    NSUserDefaults *defaults = YSPreferences();
    [defaults setInteger:self.hintPlacement forKey:@"hintPlacement"];
    [defaults setInteger:self.hintAlignment forKey:@"hintAlignment"];
    [self updateHintLayout];
}

- (void)glassOptionsChanged:(NSControl *)sender {
    BOOL sticky = sender.tag == 1;
    YSGlassControls *controls = sticky ? self.stickyGlassControls : self.quickGlassControls;
    YSGlassAppearance appearance = {controls.style.selectedSegment,
        controls.interactive.state == NSControlStateValueOn, controls.tint.doubleValue};
    // A disabled interaction control must not erase the preference on older systems.
    if (!controls.interactive.enabled) appearance.interactive = (sticky ? self.stickyGlass : self.quickGlass).interactive;
    if (!controls.style.enabled) appearance.style = (sticky ? self.stickyGlass : self.quickGlass).style;
    if (sticky) self.stickyGlass = appearance; else self.quickGlass = appearance;
    WriteGlassAppearance(YSPreferences(), sticky, appearance);
    [self applyGlassPreferences];
    [self refreshGlassControls];
}

- (void)fontOptionsChanged:(id)sender {
    id representedFamily = self.settingsFontFamilyPopup.selectedItem.representedObject;
    self.inputFontFamily = [representedFamily isKindOfClass:[NSString class]] ? representedFamily : @"";
    CGFloat size = self.settingsFontSizePopup.titleOfSelectedItem.doubleValue;
    if (size < 12 || size > 48) size = 21;
    self.inputFontSize = round(size);
    NSUserDefaults *defaults = YSPreferences();
    [defaults setObject:self.inputFontFamily forKey:@"inputFontFamily"];
    [defaults setDouble:self.inputFontSize forKey:@"inputFontSize"];
    if (self.textView) {
        self.textView.font = [self inputFont];
        [self updatePanelSizeForContent];
    }
    for (YSStickyNote *note in self.stickyNotes) note.textView.font = [self inputFont];
}

- (void)stickyOptionsChanged:(id)sender {
    self.stickyDefaultLevel = self.settingsStickyLevelControl.selectedSegment;
    self.stickyCloseAction = self.settingsStickyCloseControl.selectedSegment;
    NSUserDefaults *defaults = YSPreferences();
    [defaults setInteger:self.stickyDefaultLevel forKey:@"stickyDefaultLevel"];
    [defaults setInteger:self.stickyCloseAction forKey:@"stickyCloseAction"];
}

- (void)removeHotkeyCaptureMonitor {
    if (self.hotkeyCaptureMonitor) {
        [NSEvent removeMonitor:self.hotkeyCaptureMonitor];
        self.hotkeyCaptureMonitor = nil;
    }
}

- (void)setHotkeyHint:(NSString *)message error:(BOOL)isError {
    self.settingsHotkeyHint.stringValue = message;
    self.settingsHotkeyHint.textColor = isError ? [NSColor systemRedColor] : [NSColor systemGreenColor];
}

- (void)recordHotkey:(id)sender {
    if (self.recordingHotkey) {
        [self cancelHotkeyCapture];
        return;
    }
    [self refreshSettingsUI];
    self.previousHotkeyKeyCode = self.hotkeyKeyCode;
    self.previousHotkeyModifiers = self.hotkeyModifiers;
    self.previousHotkeyKeyLabel = self.hotkeyKeyLabel;
    self.recordingHotkey = YES;
    [self unregisterHotKey];
    [self.settingsHotkeyButton setTitle:YSL(@"请按新的组合…")];
    self.settingsHotkeyHint.stringValue = YSL(@"正在录制：请按下包含 Control、Option 或 Command 的新组合。Esc 取消。");
    self.settingsHotkeyHint.textColor = [NSColor systemOrangeColor];
    __weak typeof(self) weakSelf = self;
    self.hotkeyCaptureMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        [weakSelf captureHotkeyEvent:event];
        return nil;
    }];
}

- (void)captureHotkeyEvent:(NSEvent *)event {
    if (!self.recordingHotkey) return;
    if (event.keyCode == 53) {
        [self cancelHotkeyCapture];
        return;
    }
    NSEventModifierFlags modifiers = event.modifierFlags & SupportedHotkeyModifiers();
    if (!(modifiers & (NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand))) {
        [self setHotkeyHint:YSL(@"快捷键至少需要包含 Control、Option 或 Command 中的一个。") error:YES];
        NSBeep();
        return;
    }
    NSString *reserved = ReservedAppHotkeyReason(event.keyCode, modifiers);
    if (reserved.length > 0) {
        [self setHotkeyHint:reserved error:YES];
        NSBeep();
        return;
    }
    NSInteger conflictID = SystemHotkeyConflictID(event.keyCode, modifiers);
    if (conflictID > 0) {
        [self setHotkeyHint:[NSString stringWithFormat:YSL(@"%@，请换一个组合。"), SystemHotkeyConflictDescription(conflictID)] error:YES];
        NSBeep();
        return;
    }

    CGKeyCode keyCode = event.keyCode;
    NSString *keyLabel = KeyLabelForKeyCode(keyCode, event.charactersIgnoringModifiers);
    if (![self registerHotKeyForKeyCode:keyCode modifiers:modifiers]) {
        [self setHotkeyHint:YSL(@"这个组合已被其他程序注册，请换一个组合。") error:YES];
        NSBeep();
        return;
    }

    self.hotkeyKeyCode = keyCode;
    self.hotkeyModifiers = modifiers;
    self.hotkeyKeyLabel = keyLabel;
    [self saveHotkeyPreferences];
    [self removeHotkeyCaptureMonitor];
    self.recordingHotkey = NO;
    [self refreshHotkeyUI];
    [self.settingsHotkeyButton setTitle:[self hotkeyDisplayString]];
    [self setHotkeyHint:[NSString stringWithFormat:YSL(@"已更新为 %@。"), [self hotkeyDisplayString]] error:NO];
    YSLog(@"hotkey changed to %@", [self hotkeyDisplayString]);
}

- (void)cancelHotkeyCapture {
    if (!self.recordingHotkey) return;
    [self removeHotkeyCaptureMonitor];
    self.recordingHotkey = NO;
    if (![self registerHotKeyForKeyCode:self.hotkeyKeyCode modifiers:self.hotkeyModifiers]) {
        [self setHotkeyHint:YSL(@"原快捷键无法重新注册，请在系统设置中检查快捷键冲突。") error:YES];
    } else {
        [self setHotkeyHint:YSL(@"已取消录制，原快捷键保持不变。") error:NO];
    }
    [self refreshHotkeyUI];
}

- (void)resetHotkey:(id)sender {
    if (self.recordingHotkey) {
        [self removeHotkeyCaptureMonitor];
        self.recordingHotkey = NO;
        [self unregisterHotKey];
    }
    NSString *reserved = ReservedAppHotkeyReason(DefaultHotkeyKeyCode, DefaultHotkeyModifiers);
    NSInteger conflictID = SystemHotkeyConflictID(DefaultHotkeyKeyCode, DefaultHotkeyModifiers);
    if (reserved.length > 0 || conflictID > 0) {
        [self setHotkeyHint:YSL(@"默认快捷键当前被系统占用，无法恢复。") error:YES];
        return;
    }
    [self unregisterHotKey];
    if (![self registerHotKeyForKeyCode:DefaultHotkeyKeyCode modifiers:DefaultHotkeyModifiers]) {
        [self registerHotKeyForKeyCode:self.hotkeyKeyCode modifiers:self.hotkeyModifiers];
        [self setHotkeyHint:YSL(@"默认快捷键注册失败，原快捷键已保留。") error:YES];
        return;
    }
    self.hotkeyKeyCode = DefaultHotkeyKeyCode;
    self.hotkeyModifiers = DefaultHotkeyModifiers;
    self.hotkeyKeyLabel = DefaultHotkeyKeyLabel;
    [self saveHotkeyPreferences];
    [self refreshHotkeyUI];
    [self setHotkeyHint:[NSString stringWithFormat:YSL(@"已恢复默认快捷键 %@。"), [self hotkeyDisplayString]] error:NO];
}

- (void)setLoginItemEnabled:(BOOL)enabled {
    SMAppService *service = [SMAppService mainAppService];
    NSError *error = nil;
    BOOL success = YES;
    if (enabled && service.status != SMAppServiceStatusEnabled) {
        success = [service registerAndReturnError:&error];
    } else if (!enabled && service.status == SMAppServiceStatusEnabled) {
        success = [service unregisterAndReturnError:&error];
    }
    if (!success) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = YSL(@"无法更新登录项");
        alert.informativeText = error.localizedDescription ?: YSL(@"未知错误");
        alert.alertStyle = NSAlertStyleWarning;
        [alert runModal];
    }
    BOOL current = service.status == SMAppServiceStatusEnabled;
    self.loginAtStartupCheckbox.state = current ? NSControlStateValueOn : NSControlStateValueOff;
    [self.statusMenu itemWithTitle:YSL(@"登录时启动")].state = current ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)loginOptionChanged:(id)sender {
    [self setLoginItemEnabled:self.loginAtStartupCheckbox.state == NSControlStateValueOn];
}

- (void)closeSettings:(id)sender {
    [self.settingsWindow close];
}

- (void)windowWillClose:(NSNotification *)notification {
    if (notification.object == self.settingsWindow && self.recordingHotkey) {
        [self cancelHotkeyCapture];
    }
}

- (void)windowDidResignKey:(NSNotification *)notification {
    if (notification.object == self.settingsWindow && self.recordingHotkey) {
        [self cancelHotkeyCapture];
    }
}

- (void)openNotesFolder {
    NSURL *folderURL = ConfiguredNotesFolder();
    [[NSFileManager defaultManager] createDirectoryAtURL:folderURL withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSWorkspace sharedWorkspace] openURL:folderURL];
}

- (void)openLastNote {
    if (self.lastNoteURL && [[NSFileManager defaultManager] fileExistsAtPath:self.lastNoteURL.path]) {
        NSURL *vaultURL = ObsidianVaultRootForFolder([self.lastNoteURL URLByDeletingLastPathComponent]);
        if (vaultURL) {
            [[NSWorkspace sharedWorkspace] openURL:ObsidianURLForNote(self.lastNoteURL, vaultURL)];
        } else {
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[self.lastNoteURL]];
        }
    } else {
        [self openNotesFolder];
    }
}

- (void)toggleLoginItem {
    BOOL enabled = [SMAppService mainAppService].status == SMAppServiceStatusEnabled;
    [self setLoginItemEnabled:!enabled];
}

- (void)testCreateNote {
    NSURL *notesFolderURL = ConfiguredNotesFolder();
    NSURL *vaultURL = ObsidianVaultRootForFolder(notesFolderURL);
    NSError *error = nil;
    NSURL *noteURL = WriteNote(@"双轨记测试：Obsidian 写入正常。", notesFolderURL, &error);
    if (noteURL) {
        self.lastNoteURL = noteURL;
        [YSPreferences() setObject:noteURL.path forKey:@"lastNotePath"];
        if (vaultURL) {
            [[NSWorkspace sharedWorkspace] openURL:ObsidianURLForNote(noteURL, vaultURL)];
        }
    } else {
        NSAlert *alert = [NSAlert new];
        alert.messageText = YSL(@"测试失败");
        alert.informativeText = error.localizedDescription ?: YSL(@"未知错误");
        alert.alertStyle = NSAlertStyleWarning;
        [alert runModal];
    }
}

- (void)quit {
    [NSApp terminate:nil];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        ConfigurePreviewEnvironment();
        YSConfigureLocalization(YSPreferences());
        NSArray<NSString *> *arguments = [[NSProcessInfo processInfo] arguments];
        if ([arguments containsObject:@"--preview-isolation-check"]) {
            NSString *directory = [NSBundle.mainBundle objectForInfoDictionaryKey:@"YinSuPreviewDirectory"];
            NSString *prefix = [directory stringByAppendingString:@"/"];
            BOOL safe = directory.isAbsolutePath &&
                [NSProcessInfo.processInfo.environment[@"YIN_SU_ISOLATED"] boolValue] &&
                [ConfiguredNotesFolder().path hasPrefix:prefix] &&
                [StickyStoreURL().path hasPrefix:prefix] && [EditorDraftURL().path hasPrefix:prefix] &&
                [NSProcessInfo.processInfo.environment[@"VOICE_NOTE_NO_OPEN"] boolValue] &&
                [NSProcessInfo.processInfo.environment[@"VOICE_NOTE_NO_CLIPBOARD"] boolValue];
            printf("previewRelaunchIsolated=%d\n", safe);
            return safe ? EXIT_SUCCESS : EXIT_FAILURE;
        }
        if ([arguments containsObject:@"--glass-preferences-check"]) {
            RunGlassPreferencesCheck();
            return EXIT_SUCCESS;
        }
        if ([arguments containsObject:@"--migrate-check"]) {
            MigrateLegacyPreferences();
            NSUserDefaults *defaults = YSPreferences();
            printf("migrated=%d hotkeyKeyCode=%ld hotkeyModifiers=%ld font=%s/%.0f folder=%s\n",
                   [defaults boolForKey:DefaultsMigrationMarker],
                   (long)[defaults integerForKey:@"hotkeyKeyCode"],
                   (long)[defaults integerForKey:@"hotkeyModifiers"],
                   [[defaults stringForKey:@"inputFontFamily"] UTF8String] ?: "",
                   [defaults doubleForKey:@"inputFontSize"],
                   ConfiguredNotesFolder().path.UTF8String ?: "");
            return EXIT_SUCCESS;
        }
        if ([arguments containsObject:@"--register-login"] || [arguments containsObject:@"--login-status"]) {
            SMAppService *service = [SMAppService mainAppService];
            NSError *error = nil;
            if ([arguments containsObject:@"--register-login"] && service.status != SMAppServiceStatusEnabled) {
                if (![service registerAndReturnError:&error]) {
                    fprintf(stderr, "login registration failed: %s\n", error.localizedDescription.UTF8String);
                    return EXIT_FAILURE;
                }
            }
            printf("login status: %ld\n", (long)service.status);
            return EXIT_SUCCESS;
        }
        if ([arguments containsObject:@"--hotkey-check"]) {
            printf("Ctrl+Space=%ld\n", (long)SystemHotkeyConflictID(49, NSEventModifierFlagControl));
            printf("Ctrl+Option+Space=%ld\n", (long)SystemHotkeyConflictID(49, NSEventModifierFlagControl | NSEventModifierFlagOption));
            printf("Command+Space=%ld\n", (long)SystemHotkeyConflictID(49, NSEventModifierFlagCommand));
            printf("Ctrl+Shift+Space=%ld\n", (long)SystemHotkeyConflictID(49, NSEventModifierFlagControl | NSEventModifierFlagShift));
            printf("Ctrl+Command+Space=%ld\n", (long)SystemHotkeyConflictID(49, NSEventModifierFlagControl | NSEventModifierFlagCommand));
            return EXIT_SUCCESS;
        }
        if ([arguments containsObject:@"--self-test"]) {
            RunSelfTest();
            return EXIT_SUCCESS;
        }
        NSApplication *application = [NSApplication sharedApplication];
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        YSAppDelegate *delegate = [YSAppDelegate new];
        application.delegate = delegate;
        [application run];
    }
    return EXIT_SUCCESS;
}
