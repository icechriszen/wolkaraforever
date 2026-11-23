#import "ForeverUI.h"
#import "../App/WKLocalization.h"
#include <math.h>

NSErrorDomain const TKForeverUIErrorDomain = @"WolkaraForever.ForeverUI";
// The released Forever product. It was `wow_classic_beta` while the game was in
// beta; the rows, backups and Config.wtf rules are the same edition, and Battle.net
// now publishes it as `wowf` in `_forever_` (see Manifest.m).
NSString *const TKForeverUIEdition = @"wowf";

// A Config.wtf is a few kilobytes. Anything near this is not a config file, and
// reading it whole would be the wrong answer to a damaged one anyway.
static const NSUInteger TKForeverConfigLimit = 1024 * 1024;

static NSError *TKError(NSString *message) {
    return [NSError errorWithDomain:TKForeverUIErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

static NSArray<NSString *> *TKTokens(NSString *line) {
    NSMutableArray<NSString *> *tokens = [NSMutableArray new];
    for (NSString *token in [line componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet])
        if (token.length) [tokens addObject:token];
    return tokens;
}

// The CVar name of a `SET name value` line, or nil for anything else. The name
// keeps its case; comparisons are case-insensitive, as the client's are.
static NSString *TKCVarName(NSString *line) {
    NSArray<NSString *> *tokens = TKTokens(line);
    if (tokens.count < 2 || ![tokens[0].uppercaseString isEqualToString:@"SET"]) return nil;
    return tokens[1];
}

// The value of a `SET name value` line with quotes removed, or nil.
static NSString *TKCVarValue(NSString *line) {
    NSArray<NSString *> *tokens = TKTokens(line);
    if (tokens.count < 3) return nil;
    NSString *value = tokens[2];
    if (value.length >= 2 && [value hasPrefix:@"\""] && [value hasSuffix:@"\""])
        value = [value substringWithRange:NSMakeRange(1, value.length - 2)];
    return value;
}

static BOOL TKNameIs(NSString *name, NSString *expected) {
    return name && [name caseInsensitiveCompare:expected] == NSOrderedSame;
}

// The Forever graphics/display CVars a reset removes.
//
// This is an explicit list, not a prefix rule: the client owns far more
// settings than these, and a reset must never guess. Everything else - account,
// portal, locale, audio, UI, input, controller (GamePad*), cache, bindings,
// SavedVariables and any setting not named here - survives untouched. A CVar
// this list misses is preserved rather than guessed at, which is the safe way to
// be incomplete.
NSSet<NSString *> *TKForeverUIGraphicsCVars(void) {
    static NSSet<NSString *> *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[
            // Display and renderer
            @"gxAdapter", @"gxApi", @"gxColorBits", @"gxDepthBits", @"gxCursor",
            @"gxFixLag", @"gxForegroundFPS", @"gxBackgroundFPS", @"gxFullscreenResolution",
            @"gxMaximize", @"gxMaxFrameLatency", @"gxMonitor", @"gxMSAA", @"gxMultisample",
            @"gxMultisampleQuality", @"gxRefresh", @"gxResolution", @"gxScreenshotFormat",
            @"gxTextureCacheSize", @"gxTripleBuffer", @"gxVSync", @"gxWindow",
            @"gxWindowedResolution",
            // Graphics quality
            @"graphicsQuality", @"graphicsTextureResolution", @"graphicsSpellDensity",
            @"graphicsViewDistance", @"graphicsGroundClutter", @"graphicsLiquidDetail",
            @"graphicsSunshafts", @"graphicsParticleDensity", @"graphicsShadowQuality",
            @"graphicsSSAO", @"graphicsDepthEffects", @"graphicsOutlineMode",
            @"graphicsComputeEffects", @"graphicsReflectionQuality", @"graphicsTextureFiltering",
            @"graphicsProjectedTextures", @"graphicsEnvironmentDetail", @"graphicsTripleBuffering",
            @"graphicsMSAA", @"graphicsResampleQuality", @"graphicsGammaAdjustment",
            @"graphicsContrast", @"graphicsBrightness", @"graphicsRaidFramerate",
            // Render scale and the frame cap this app writes for a sustained rate
            @"renderScale", @"vsync",
        ]];
    });
    return set;
}

static BOOL TKInside(NSString *root, NSString *candidate) {
    NSString *canonicalRoot = [root stringByResolvingSymlinksInPath].stringByStandardizingPath;
    NSString *canonicalPath = [candidate stringByResolvingSymlinksInPath].stringByStandardizingPath;
    return [canonicalPath isEqualToString:canonicalRoot] ||
           [canonicalPath hasPrefix:[canonicalRoot stringByAppendingString:@"/"]];
}

static NSString *TKReadConfig(NSString *path, NSError **error) {
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) return nil;
    if (data.length > TKForeverConfigLimit) {
        if (error) *error = TKError(WKLocalized(@"forever.error.configTooLarge"));
        return nil;
    }
    // Latin-1 maps every byte to one character, so splitting into lines and
    // joining them again reproduces the file byte for byte - including line
    // endings, comments and settings this code does not understand.
    NSString *text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (!text) {
        if (error) *error = TKError(WKLocalized(@"forever.error.configNotText"));
        return nil;
    }
    return text;
}

static BOOL TKWriteConfig(NSString *path, NSString *text, NSError **error) {
    NSData *data = [text dataUsingEncoding:NSISOLatin1StringEncoding];
    if (!data) {
        if (error) *error = TKError(WKLocalized(@"forever.error.configNotWritable"));
        return NO;
    }
    return [data writeToFile:path options:NSDataWritingAtomic error:error];
}

// ASCII delimiters only: interpreting UTF-8 as Latin-1 preserves every byte,
// but Unicode line enumeration would mistake some UTF-8 bytes for line breaks.
static NSData *TKTouchAddonSettings(NSData *data, BOOL manifest, BOOL connected) {
    NSString *text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    NSString *bom = @"\u00ef\u00bb\u00bf";
    BOOL hasBOM = [text hasPrefix:bom];
    if (hasBOM) text = [text substringFromIndex:3];
    NSString *newline = [text containsString:@"\r\n"] ? @"\r\n" : @"\n";
    NSMutableString *kept = [NSMutableString new];
    NSArray<NSString *> *lines = [text componentsSeparatedByString:@"\n"];
    for (NSUInteger i = 0; i < lines.count; i++) {
        NSString *line = lines[i];
        NSString *field = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (manifest && [field hasPrefix:@"##"]) field = [field substringFromIndex:2];
        else if (manifest) field = @"";
        NSRange colon = [field rangeOfString:@":"];
        NSString *name = colon.location == NSNotFound ? nil :
            [[field substringToIndex:colon.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (TKNameIs(name, manifest ? @"LoadOnDemand" : @"WolkaraRoue")) continue;
        [kept appendString:line];
        if (i + 1 < lines.count) [kept appendString:@"\n"];
    }
    NSString *setting = manifest ? (connected ? @"## LoadOnDemand: 1" : nil) :
        (connected ? @"WolkaraRoue: disabled" : @"WolkaraRoue: enabled");
    NSString *result = [NSString stringWithFormat:@"%@%@%@", hasBOM ? bom : @"",
        setting ? [setting stringByAppendingString:newline] : @"", kept];
    return [result dataUsingEncoding:NSISOLatin1StringEncoding];
}

static BOOL TKTouchAddonFile(NSString *root, NSString *path, NSError **error) {
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:error];
    if (!attributes) return NO;
    if (!TKInside(root, path) || ![attributes[NSFileType] isEqual:NSFileTypeRegular] ||
        [attributes[NSFileSize] unsignedLongLongValue] > TKForeverConfigLimit) {
        if (error) *error = TKError(WKLocalized(@"forever.error.touchAddonSwitch"));
        return NO;
    }
    return YES;
}

@implementation TKForeverUI

+ (BOOL)prepareTouchGeometry:(NSDictionary<NSString *, NSNumber *> *)geometry
         inWorkingDirectory:(NSString *)directory error:(NSError **)error {
    NSString *path = [directory stringByAppendingPathComponent:@"Interface/AddOns/WolkaraRoue/HostTouchLayout.lua"];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) return YES;
    if (!TKTouchAddonFile(directory, path, error)) return NO;
    NSData *before = [NSData dataWithContentsOfFile:path options:0 error:error];
    NSString *marker = @"-- Wolkara generated touch geometry v1\n";
    if (!before || ![[[NSString alloc] initWithData:before encoding:NSUTF8StringEncoding] hasPrefix:marker]) {
        if (error && before) *error = TKError(WKLocalized(@"forever.error.touchAddonSwitch"));
        return NO;
    }
    NSMutableString *text = [NSMutableString stringWithFormat:@"%@local _, ns = ...\nns.HostTouchLayout = ", marker];
    if (!geometry) [text appendString:@"nil\n"];
    else {
        NSArray *keys = @[@"leftX", @"leftY", @"leftRadius", @"leftMinX", @"leftMaxX", @"leftMinY", @"leftMaxY",
            @"rightX", @"rightY", @"rightRadius", @"rightMinX", @"rightMaxX", @"rightMinY", @"rightMaxY", @"bottom"];
        [text appendString:@"{ version = 1,\n"];
        for (NSString *key in keys) {
            id value = geometry[key];
            if (![value isKindOfClass:NSNumber.class] || !isfinite([value doubleValue]) ||
                [value doubleValue] < 0 || [value doubleValue] > 1) {
                if (error) *error = TKError(WKLocalized(@"forever.error.touchAddonSwitch"));
                return NO;
            }
            [text appendFormat:@"    %@ = %.9f,\n", key, [value doubleValue]];
        }
        [text appendString:@"}\n"];
    }
    NSData *after = [text dataUsingEncoding:NSUTF8StringEncoding];
    if ([before isEqual:after]) return YES;
    if (![after writeToFile:path options:NSDataWritingAtomic error:error]) return NO;
    if ([[NSData dataWithContentsOfFile:path options:0 error:error] isEqual:after]) return YES;
    [before writeToFile:path options:NSDataWritingAtomic error:nil];
    if (error && !*error) *error = TKError(WKLocalized(@"forever.error.touchAddonSwitch"));
    return NO;
}

+ (void)prepareTouchControlsForPhysicalController:(BOOL)connected defaults:(NSUserDefaults *)defaults {
    NSMutableDictionary *arguments = [[defaults volatileDomainForName:NSArgumentDomain] mutableCopy] ?: [NSMutableDictionary new];
    // AKTouchControlsDefaultsKey in the separately loaded AppKit adapter. This
    // process-only domain reaches that reader without changing saved preferences.
    arguments[@"AKTouchControls"] = @(!connected);
    [defaults setVolatileDomain:arguments forName:NSArgumentDomain];
}

+ (BOOL)prepareTouchAddonForPhysicalController:(BOOL)connected
                           inWorkingDirectory:(NSString *)directory
                                        error:(NSError **)error {
    NSFileManager *files = NSFileManager.defaultManager;
    NSString *toc = [directory stringByAppendingPathComponent:@"Interface/AddOns/WolkaraRoue/WolkaraRoue.toc"];
    // Do not install an add-on that the player has not installed.
    if (![files fileExistsAtPath:toc]) return YES;
    if (!TKTouchAddonFile(directory, toc, error)) return NO;
    NSMutableArray<NSString *> *paths = [NSMutableArray arrayWithObject:toc];
    NSString *account = [directory stringByAppendingPathComponent:@"WTF/Account"];
    if ([files fileExistsAtPath:account]) {
        if (!TKInside(directory, account) || ![[files attributesOfItemAtPath:account error:error][NSFileType] isEqual:NSFileTypeDirectory]) {
            if (error) *error = TKError(WKLocalized(@"forever.error.touchAddonSwitch"));
            return NO;
        }
        __block NSError *walkError = nil;
        NSDirectoryEnumerator *walk = [files enumeratorAtURL:[NSURL fileURLWithPath:account]
            includingPropertiesForKeys:nil options:0 errorHandler:^BOOL(NSURL *url, NSError *failure) {
                (void)url; walkError = failure; return NO;
            }];
        for (NSURL *url in walk) {
            NSDictionary *attributes = [files attributesOfItemAtPath:url.path error:error];
            if (!attributes) return NO;
            // An account tree with links cannot be enumerated completely without
            // following potentially external files. Refuse before changing anything.
            if ([attributes[NSFileType] isEqual:NSFileTypeSymbolicLink]) {
                if (error) *error = TKError(WKLocalized(@"forever.error.touchAddonSwitch"));
                return NO;
            }
            if ([url.lastPathComponent caseInsensitiveCompare:@"AddOns.txt"] != NSOrderedSame) continue;
            if (!TKTouchAddonFile(directory, url.path, error)) return NO;
            [paths addObject:url.path];
        }
        if (walkError) { if (error) *error = walkError; return NO; }
    }
    // Prepare every replacement before any write. The client is not running, so
    // it cannot rewrite a character's enable list halfway through this operation.
    NSMutableArray<NSDictionary *> *changes = [NSMutableArray new];
    for (NSString *path in paths) {
        NSData *before = [NSData dataWithContentsOfFile:path options:0 error:error];
        if (!before) return NO;
        NSData *after = TKTouchAddonSettings(before, [path isEqual:toc], connected);
        if (![before isEqual:after]) [changes addObject:@{@"path":path, @"before":before, @"after":after}];
    }
    NSMutableArray<NSDictionary *> *written = [NSMutableArray new];
    for (NSDictionary *change in changes) {
        NSError *failure = nil;
        BOOL stored = [change[@"after"] writeToFile:change[@"path"] options:NSDataWritingAtomic error:&failure];
        if (stored) [written addObject:change];
        NSData *readback = stored ? [NSData dataWithContentsOfFile:change[@"path"] options:0 error:&failure] : nil;
        if (stored && [readback isEqual:change[@"after"]]) continue;
        for (NSDictionary *previous in written.reverseObjectEnumerator) {
            NSError *rollbackError = nil;
            if (![previous[@"before"] writeToFile:previous[@"path"] options:NSDataWritingAtomic error:&rollbackError])
                failure = rollbackError;
        }
        if (error) *error = failure ?: TKError(WKLocalized(@"forever.error.touchAddonSwitch"));
        return NO;
    }
    return YES;
}

+ (nullable NSString *)wtfDirectoryInWorkingDirectory:(NSString *)directory
                                               create:(BOOL)create
                                                error:(NSError **)error {
    if (!directory.length) {
        if (error) *error = TKError(WKLocalized(@"forever.error.noWorkingFolder"));
        return nil;
    }
    BOOL isDirectory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:directory isDirectory:&isDirectory] || !isDirectory) {
        if (error) *error = TKError(WKLocalized(@"forever.error.workingFolderMissing"));
        return nil;
    }
    NSString *wtf = [directory stringByAppendingPathComponent:@"WTF"];
    if (!TKInside(directory, wtf)) {
        if (error) *error = TKError(WKLocalized(@"forever.error.wtfOutside"));
        return nil;
    }
    if (![NSFileManager.defaultManager fileExistsAtPath:wtf]) {
        if (!create) {
            if (error) *error = TKError(WKLocalized(@"forever.error.wtfMissing"));
            return nil;
        }
        NSError *failure = nil;
        if (![NSFileManager.defaultManager createDirectoryAtPath:wtf withIntermediateDirectories:NO
                                                      attributes:nil error:&failure]) {
            if (error) *error = failure ?: TKError(WKLocalized(@"forever.error.wtfCreate"));
            return nil;
        }
    }
    return wtf;
}

+ (BOOL)enableGamepadInWorkingDirectory:(NSString *)directory error:(NSError **)error {
    return [self setGamepad:YES inWorkingDirectory:directory error:error];
}

+ (BOOL)setGamepad:(BOOL)enabled inWorkingDirectory:(NSString *)directory error:(NSError **)error {
    NSString *wtf = [self wtfDirectoryInWorkingDirectory:directory create:YES error:error];
    if (!wtf) return NO;
    NSString *path = [wtf stringByAppendingPathComponent:@"Config.wtf"];
    if (!TKInside(directory, path)) {
        if (error) *error = TKError(WKLocalized(@"forever.error.configOutside"));
        return NO;
    }

    NSString *text = nil;
    if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
        text = TKReadConfig(path, error);
        if (!text) return NO;
    } else {
        // Absent config: create the one bounded document this action needs.
        text = @"";
    }

    NSMutableArray<NSString *> *kept = [NSMutableArray new];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if (TKNameIs(TKCVarName(line), @"GamePadEnable")) continue;
        [kept addObject:line];
    }
    NSString *value = enabled ? @"1" : @"0";
    NSString *normalised = [kept componentsJoinedByString:@"\n"];
    if (normalised.length && ![normalised hasSuffix:@"\n"]) normalised = [normalised stringByAppendingString:@"\n"];
    normalised = [normalised stringByAppendingString:[NSString stringWithFormat:@"SET GamePadEnable \"%@\"\n", value]];

    if (!TKWriteConfig(path, normalised, error)) return NO;

    // Re-read rather than trust the write: exactly one assignment, the value asked for.
    NSError *rereadError = nil;
    NSString *written = TKReadConfig(path, &rereadError);
    if (!written) {
        if (error) *error = rereadError;
        return NO;
    }
    NSUInteger assignments = 0;
    BOOL stored = NO;
    for (NSString *line in [written componentsSeparatedByString:@"\n"]) {
        if (!TKNameIs(TKCVarName(line), @"GamePadEnable")) continue;
        assignments++;
        stored = [TKCVarValue(line) isEqualToString:value];
    }
    if (assignments != 1 || !stored) {
        if (error) *error = TKError(WKLocalized(@"forever.error.gamepadStore"));
        return NO;
    }
    return YES;
}

+ (BOOL)setCVars:(NSDictionary<NSString *, NSString *> *)values
inWorkingDirectory:(NSString *)directory
           error:(NSError **)error {
    if (values.count == 0) return YES;
    NSString *wtf = [self wtfDirectoryInWorkingDirectory:directory create:YES error:error];
    if (!wtf) return NO;
    NSString *path = [wtf stringByAppendingPathComponent:@"Config.wtf"];
    if (!TKInside(directory, path)) {
        if (error) *error = TKError(WKLocalized(@"forever.error.configOutside"));
        return NO;
    }
    // A name that is not a bare CVar name would write a line the client cannot
    // read, which fails silently. Refuse it here instead.
    NSCharacterSet *space = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    for (NSString *name in values) {
        if (name.length == 0 || [name rangeOfCharacterFromSet:space].location != NSNotFound ||
            [name rangeOfString:@"\""].location != NSNotFound) {
            if (error) *error = TKError(WKLocalized(@"forever.error.settingName"));
            return NO;
        }
        NSString *value = values[name];
        if ([value rangeOfCharacterFromSet:space].location != NSNotFound ||
            [value rangeOfString:@"\""].location != NSNotFound) {
            if (error) *error = TKError(WKLocalized(@"forever.error.settingValue"));
            return NO;
        }
    }

    NSString *text = nil;
    if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
        text = TKReadConfig(path, error);
        if (!text) return NO;
    } else {
        text = @"";
    }

    NSMutableArray<NSString *> *kept = [NSMutableArray new];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        NSString *name = TKCVarName(line);
        BOOL replace = NO;
        if (name) for (NSString *wanted in values) if (TKNameIs(name, wanted)) { replace = YES; break; }
        if (!replace) [kept addObject:line];
    }
    NSString *normalised = [kept componentsJoinedByString:@"\n"];
    if (normalised.length && ![normalised hasSuffix:@"\n"]) normalised = [normalised stringByAppendingString:@"\n"];
    for (NSString *name in [values.allKeys sortedArrayUsingSelector:@selector(compare:)])
        normalised = [normalised stringByAppendingString:
            [NSString stringWithFormat:@"SET %@ \"%@\"\n", name, values[name]]];

    if (!TKWriteConfig(path, normalised, error)) return NO;

    // Re-read rather than trust the write: one assignment per name, right value.
    NSError *rereadError = nil;
    NSString *written = TKReadConfig(path, &rereadError);
    if (!written) {
        if (error) *error = rereadError;
        return NO;
    }
    for (NSString *wanted in values) {
        NSUInteger assignments = 0;
        BOOL stored = NO;
        for (NSString *line in [written componentsSeparatedByString:@"\n"]) {
            if (!TKNameIs(TKCVarName(line), wanted)) continue;
            assignments++;
            stored = [TKCVarValue(line) isEqualToString:values[wanted]];
        }
        if (assignments != 1 || !stored) {
            if (error) *error = TKError(WKLocalized(@"forever.error.settingStore"));
            return NO;
        }
    }
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)performancePreset {
    // The client's own CVars. 0.75 is a starting point measured on this device;
    // the number that holds a frame under 16.7 ms is what the device test is for,
    // and changing it is changing this constant.
    return @{
        @"renderScale": @"0.75",        // internal render resolution, native is 1.0
        @"gxForegroundFPS": @"60",      // never render faster than the panel presents
        @"gxBackgroundFPS": @"30",      // and not at full rate when it is not visible
        @"vsync": @"1",
    };
}

+ (BOOL)applyPerformancePresetInWorkingDirectory:(NSString *)directory error:(NSError **)error {
    return [self setCVars:self.performancePreset inWorkingDirectory:directory error:error];
}

+ (BOOL)setLocale:(NSString *)locale inWorkingDirectory:(NSString *)directory error:(NSError **)error {
    static NSSet<NSString *> *supported;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        supported = [NSSet setWithArray:@[@"enUS", @"esES", @"deDE", @"frFR", @"itIT",
                                            @"esMX", @"ptBR", @"ruRU", @"koKR", @"zhTW", @"zhCN"]];
    });
    if (![supported containsObject:locale]) {
        if (error) *error = TKError(WKLocalized(@"forever.error.unsupportedLanguage"));
        return NO;
    }
    return [self setCVars:@{@"textLocale": locale, @"audioLocale": locale}
  inWorkingDirectory:directory error:error];
}

+ (BOOL)gamepadEnabledInWorkingDirectory:(NSString *)directory {    NSError *error = nil;
    NSString *wtf = [self wtfDirectoryInWorkingDirectory:directory create:NO error:&error];
    if (!wtf) return NO;
    NSString *path = [wtf stringByAppendingPathComponent:@"Config.wtf"];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) return NO;
    NSString *text = TKReadConfig(path, NULL);
    if (!text) return NO;
    NSUInteger assignments = 0;
    BOOL enabled = NO;
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if (!TKNameIs(TKCVarName(line), @"GamePadEnable")) continue;
        assignments++;
        enabled = [TKCVarValue(line) isEqualToString:@"1"];
    }
    return assignments == 1 && enabled;
}

+ (BOOL)resetGraphicsInWorkingDirectory:(NSString *)directory error:(NSError **)error {
    NSString *wtf = [self wtfDirectoryInWorkingDirectory:directory create:NO error:error];
    if (!wtf) return NO;
    NSString *path = [wtf stringByAppendingPathComponent:@"Config.wtf"];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) return YES;   // nothing to reset
    NSString *text = TKReadConfig(path, error);
    if (!text) return NO;
    NSSet<NSString *> *graphics = TKForeverUIGraphicsCVars();
    NSMutableArray<NSString *> *kept = [NSMutableArray new];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        NSString *name = TKCVarName(line);
        BOOL remove = NO;
        if (name) for (NSString *cvar in graphics) if (TKNameIs(name, cvar)) { remove = YES; break; }
        if (!remove) [kept addObject:line];
    }
    NSString *reset = [kept componentsJoinedByString:@"\n"];
    if ([reset isEqualToString:text]) return YES;
    return TKWriteConfig(path, reset, error);
}

#pragma mark - Archive bridge

static Class TKArchiveClass(NSError **error) {
    Class archive = NSClassFromString(@"TKForeverUIArchive");
    if (!archive) {
        if (error) *error = TKError(WKLocalized(@"forever.error.noBackupComponent"));
        return Nil;
    }
    return archive;
}

+ (nullable NSString *)createUIBackupInWorkingDirectory:(NSString *)directory
                                               edition:(NSString *)edition
                                                 error:(NSError **)error {
    SEL selector = @selector(createBackupInWorkingDirectory:edition:error:);
    Class archive = TKArchiveClass(error);
    if (!archive || ![archive respondsToSelector:selector]) {
        if (archive && error) *error = TKError(WKLocalized(@"forever.error.backupComponent"));
        return nil;
    }
    IMP implementation = [archive methodForSelector:selector];
    return ((NSString *(*)(id, SEL, NSString *, NSString *, NSError **))implementation)(archive, selector, directory, edition, error);
}

+ (nullable NSString *)newestUIBackupInWorkingDirectory:(NSString *)directory
                                                  error:(NSError **)error {
    SEL selector = @selector(newestBackupInWorkingDirectory:error:);
    Class archive = TKArchiveClass(error);
    if (!archive || ![archive respondsToSelector:selector]) {
        if (archive && error) *error = TKError(WKLocalized(@"forever.error.backupComponent"));
        return nil;
    }
    IMP implementation = [archive methodForSelector:selector];
    return ((NSString *(*)(id, SEL, NSString *, NSError **))implementation)(archive, selector, directory, error);
}

+ (BOOL)restoreUIBackupNamed:(NSString *)name
          inWorkingDirectory:(NSString *)directory
                     edition:(NSString *)edition
                       error:(NSError **)error {
    SEL selector = @selector(restoreBackupNamed:inWorkingDirectory:edition:error:);
    Class archive = TKArchiveClass(error);
    if (!archive || ![archive respondsToSelector:selector]) {
        if (archive && error) *error = TKError(WKLocalized(@"forever.error.backupComponent"));
        return NO;
    }
    IMP implementation = [archive methodForSelector:selector];
    return ((BOOL (*)(id, SEL, NSString *, NSString *, NSString *, NSError **))implementation)(
        archive, selector, name, directory, edition, error);
}

+ (BOOL)recoverInterruptedRestoreInWorkingDirectory:(NSString *)directory
                                             error:(NSError **)error {
    SEL selector = @selector(recoverInterruptedRestoreInWorkingDirectory:error:);
    Class archive = TKArchiveClass(error);
    if (!archive || ![archive respondsToSelector:selector]) {
        if (archive && error) *error = TKError(WKLocalized(@"forever.error.backupComponent"));
        return NO;
    }
    IMP implementation = [archive methodForSelector:selector];
    return ((BOOL (*)(id, SEL, NSString *, NSError **))implementation)(archive, selector, directory, error);
}

@end
