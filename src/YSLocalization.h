#ifndef YS_LOCALIZATION_H
#define YS_LOCALIZATION_H

#import <Foundation/Foundation.h>

// Shared by the app's single translation unit. Drawing tools that never call
// YSConfigureLocalization keep their original keys and do not touch preferences.
static NSUserDefaults *YSLocalizationDefaults;
static NSBundle *YSLocalizationEnglishBundle;
static NSBundle *YSLocalizationChineseBundle;

static inline BOOL YSLocalizationIsPreference(NSString *language) {
    return [language isEqualToString:@"system"] || [language isEqualToString:@"en"] ||
           [language isEqualToString:@"zh-Hans"];
}

static inline void YSConfigureLocalization(NSUserDefaults *defaults) {
    YSLocalizationDefaults = defaults;
    NSBundle *bundle = defaults ? NSBundle.mainBundle : nil;
    NSString *englishPath = [bundle pathForResource:@"en" ofType:@"lproj"];
    NSString *chinesePath = [bundle pathForResource:@"zh-Hans" ofType:@"lproj"];
    YSLocalizationEnglishBundle = englishPath ? [NSBundle bundleWithPath:englishPath] : nil;
    YSLocalizationChineseBundle = chinesePath ? [NSBundle bundleWithPath:chinesePath] : nil;

    // The caller supplies its disposable defaults suite for isolated runs.
    // Seed once at configuration time; later setters take effect immediately.
    NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;
    NSString *language = environment[@"YIN_SU_UI_LANGUAGE"];
    if ([environment[@"YIN_SU_ISOLATED"] isEqualToString:@"1"] &&
        YSLocalizationIsPreference(language))
        [defaults setObject:language forKey:@"uiLanguage"];
}

static inline NSString *YSLanguagePreference(void) {
    id language = [YSLocalizationDefaults objectForKey:@"uiLanguage"];
    return [language isKindOfClass:NSString.class] && YSLocalizationIsPreference(language)
        ? language : @"system";
}

static inline NSString *YSLocalizationResolveLanguage(NSString *language) {
    if ([language isEqualToString:@"zh-Hans"]) return @"zh-Hans";
    if (![language isEqualToString:@"system"]) return @"en";
    NSArray<NSString *> *matches = [NSBundle preferredLocalizationsFromArray:@[@"en", @"zh-Hans"]
                                                                            forPreferences:NSLocale.preferredLanguages];
    return [matches.firstObject isEqualToString:@"zh-Hans"] ? @"zh-Hans" : @"en";
}

static inline NSString *YSCurrentLanguage(void) {
    return YSLocalizationResolveLanguage(YSLanguagePreference());
}

static inline void YSSetLanguagePreference(NSString *language) {
    [YSLocalizationDefaults setObject:YSLocalizationIsPreference(language) ? language : @"system"
                              forKey:@"uiLanguage"];
}

static inline NSString *YSLocalizedInLanguage(NSString *key, NSString *language) {
    if (!key.length || !YSLocalizationDefaults) return key ?: @"";
    NSBundle *bundle = [YSLocalizationResolveLanguage(language) isEqualToString:@"zh-Hans"]
        ? YSLocalizationChineseBundle : YSLocalizationEnglishBundle;
    NSString *missing = @"\uFDD0YSLocalizationMissing";
    NSString *value = [bundle localizedStringForKey:key value:missing table:@"Localizable"];
    if (!value || [value isEqualToString:missing])
        value = [YSLocalizationEnglishBundle localizedStringForKey:key value:missing table:@"Localizable"];
    return value && ![value isEqualToString:missing] ? value : key;
}

static inline NSString *YSL(NSString *key) {
    return YSLocalizedInLanguage(key, YSCurrentLanguage());
}

#endif
