// Focused tests for the Forever Config.wtf operations. No game, no simulator:
// the rules are about bytes in a file, so this runs wherever the code does.
#import <Foundation/Foundation.h>
// Through the prepared tree's layout, like every other test of layer code: this suite is built
// there too, so the header it tests is the one the app compiles against.
#import "../launcher/WoW/ForeverUI.h"
#import "../launcher/WoW/ControlGeometry.h"
#include <assert.h>

static NSString *Read(NSString *path) {
    return [NSString stringWithContentsOfFile:path encoding:NSISOLatin1StringEncoding error:NULL];
}

static void Write(NSString *path, NSString *text) {
    [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent
                            withIntermediateDirectories:YES attributes:nil error:NULL];
    NSData *data = [text dataUsingEncoding:NSISOLatin1StringEncoding];
    assert([data writeToFile:path atomically:YES]);
}

static NSString *ConfigPath(NSString *root) {
    return [root stringByAppendingPathComponent:@"WTF/Config.wtf"];
}

static void TestTouchStartup(NSString *root) {
    NSFileManager *files = NSFileManager.defaultManager;
    NSError *error = nil;
    NSString *toc = [root stringByAppendingPathComponent:@"Interface/AddOns/WolkaraRoue/WolkaraRoue.toc"];
    NSString *enabled = [root stringByAppendingPathComponent:@"WTF/Account/Test/Realm/Player/AddOns.txt"];
    NSString *second = [root stringByAppendingPathComponent:@"WTF/Account/Test/Realm/Other/AddOns.txt"];
    NSString *saved = [root stringByAppendingPathComponent:@"WTF/Account/Test/Realm/Player/SavedVariables/WolkaraRoue.lua"];
    NSString *language = [toc.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"Language.lua"];
    NSString *configBefore = Read(ConfigPath(root));
    // An uninstalled add-on stays absent, even if its old enabled row survives.
    Write(enabled, @"WolkaraRoue: disabled\r\nOtherAddon: enabled\r\nWolkaraRoueHelper: disabled");
    NSString *enabledBefore = Read(enabled);
    assert([TKForeverUI prepareTouchAddonForPhysicalController:NO inWorkingDirectory:root error:&error]);
    assert(![files fileExistsAtPath:toc] && [Read(enabled) isEqual:enabledBefore]);
    NSString *utf8 = @"\ufeff## Title-zhCN: 触屏轮盘\r\n## Version: 1.0.5-cn.1\r\n## SavedVariablesPerCharacter: WolkaraRoueDB\r\nCore.lua\r\nLanguage.lua\r\n";
    NSString *tocBefore = [[NSString alloc] initWithData:[utf8 dataUsingEncoding:NSUTF8StringEncoding] encoding:NSISOLatin1StringEncoding];
    Write(toc, tocBefore);
    Write(second, @"OtherAddon: disabled\n");
    // Include UTF-8 bytes which Unicode line enumeration could misread.
    NSString *chinese = [[NSString alloc] initWithData:[@"设置：关闭，任务日志\n" dataUsingEncoding:NSUTF8StringEncoding] encoding:NSISOLatin1StringEncoding];
    Write(language, chinese);
    Write(saved, @"WolkaraRoueDB = { language = 'zhCN', freeLeft = { radius = 123 }, buttons = { 'spell:1' } }\n");
    NSString *savedBefore = Read(saved);
    assert([TKForeverUI prepareTouchAddonForPhysicalController:YES inWorkingDirectory:root error:&error]);
    assert([Read(toc) isEqual:[tocBefore stringByReplacingOccurrencesOfString:@"\u00ef\u00bb\u00bf" withString:@"\u00ef\u00bb\u00bf## LoadOnDemand: 1\r\n"]]);
    assert([Read(enabled) isEqual:enabledBefore]);
    assert([Read(second) isEqual:@"WolkaraRoue: disabled\nOtherAddon: disabled\n"]);
    NSDictionary *tocAttributes = [files attributesOfItemAtPath:toc error:NULL];
    assert([TKForeverUI prepareTouchAddonForPhysicalController:YES inWorkingDirectory:root error:&error]);
    assert([[files attributesOfItemAtPath:toc error:NULL][NSFileModificationDate] isEqual:tocAttributes[NSFileModificationDate]]);
    // Unplugged next launch re-enables a previously disabled character; it does
    // not reload/reset saved wheel choices or translation files.
    assert([TKForeverUI prepareTouchAddonForPhysicalController:NO inWorkingDirectory:root error:&error]);
    assert([Read(toc) isEqual:tocBefore]);
    assert([Read(enabled) isEqual:@"WolkaraRoue: enabled\r\nOtherAddon: enabled\r\nWolkaraRoueHelper: disabled"]);
    assert([Read(second) isEqual:@"WolkaraRoue: enabled\nOtherAddon: disabled\n"]);
    assert([Read(saved) isEqual:savedBefore] && [Read(language) isEqual:chinese]);
    assert([Read(ConfigPath(root)) isEqual:configBefore]);
    // All duplicate owned fields converge, without treating another add-on's
    // name prefix or a commented line as our row.
    Write(toc, [@"## LoadOnDemand: 0\n## loadondemand: 1\n" stringByAppendingString:tocBefore]);
    Write(second, @"# WolkaraRoue: disabled\nWolkaraRoue: disabled\nwOlKaRaRoUe: enabled\nOtherAddon: disabled\n");
    assert([TKForeverUI prepareTouchAddonForPhysicalController:NO inWorkingDirectory:root error:&error]);
    assert([Read(toc) isEqual:tocBefore]);
    assert([Read(second) isEqual:@"WolkaraRoue: enabled\n# WolkaraRoue: disabled\nOtherAddon: disabled\n"]);
    // Complete validation precedes all writes, including the TOC.
    NSString *secondBefore = Read(second);
    Write(second, [@"x" stringByPaddingToLength:1024*1024+1 withString:@"x" startingAtIndex:0]);
    assert(![TKForeverUI prepareTouchAddonForPhysicalController:YES inWorkingDirectory:root error:&error]);
    assert([Read(toc) isEqual:tocBefore]);
    Write(second, secondBefore);
    NSString *link = [root stringByAppendingPathComponent:@"WTF/Account/Linked"];
    assert([files createSymbolicLinkAtPath:link withDestinationPath:root error:NULL]);
    assert(![TKForeverUI prepareTouchAddonForPhysicalController:YES inWorkingDirectory:root error:&error]);
    assert([Read(toc) isEqual:tocBefore] && [Read(second) isEqual:secondBefore]);
    assert([files removeItemAtPath:link error:NULL]);
    // A real failed atomic replacement rolls back the already written TOC and
    // any earlier character list. This suite runs as the ordinary build user.
    NSString *enabledCurrent = Read(enabled);
    NSString *parent = second.stringByDeletingLastPathComponent;
    assert([files setAttributes:@{NSFilePosixPermissions:@0500} ofItemAtPath:parent error:NULL]);
    BOOL stored = [TKForeverUI prepareTouchAddonForPhysicalController:YES inWorkingDirectory:root error:&error];
    assert([files setAttributes:@{NSFilePosixPermissions:@0700} ofItemAtPath:parent error:NULL]);
    assert(!stored);
    assert([Read(toc) isEqual:tocBefore] && [Read(enabled) isEqual:enabledCurrent] && [Read(second) isEqual:secondBefore]);
    assert([Read(saved) isEqual:savedBefore] && [Read(language) isEqual:chinese]);

    // A fresh character/account has no AddOns.txt yet. The manifest alone must
    // suppress auto-loading with a controller and restore it without one.
    assert([files removeItemAtPath:[root stringByAppendingPathComponent:@"WTF/Account"] error:NULL]);
    assert([TKForeverUI prepareTouchAddonForPhysicalController:YES inWorkingDirectory:root error:&error]);
    assert([Read(toc) containsString:@"## LoadOnDemand: 1"]);
    assert([TKForeverUI prepareTouchAddonForPhysicalController:NO inWorkingDirectory:root error:&error]);
    assert([Read(toc) isEqual:tocBefore]);
    assert(![files fileExistsAtPath:enabled]);

    NSString *suite = [@"TouchStartupTests." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    [defaults setBool:YES forKey:@"AKTouchControls"];
    [defaults setObject:@{@"scale":@1.25} forKey:@"PlayerLayout"];
    [defaults setVolatileDomain:@{@"OtherArgument":@"kept"} forName:NSArgumentDomain];
    NSDictionary *persisted = [defaults persistentDomainForName:suite];
    [TKForeverUI prepareTouchControlsForPhysicalController:YES defaults:defaults];
    assert(![defaults boolForKey:@"AKTouchControls"]);
    assert([[defaults stringForKey:@"OtherArgument"] isEqual:@"kept"]);
    assert([[defaults persistentDomainForName:suite] isEqual:persisted]);
    [TKForeverUI prepareTouchControlsForPhysicalController:NO defaults:defaults];
    assert([defaults boolForKey:@"AKTouchControls"]);
    assert([[defaults persistentDomainForName:suite] isEqual:persisted]);
    [defaults removeVolatileDomainForName:NSArgumentDomain];
    [defaults removePersistentDomainForName:suite];
    puts("TOUCH_STARTUP_PASS: controller/unplugged/new-character policy, byte-preserved Chinese/configuration, idempotence, invalid-file refusal, write-failure rollback, and nonpersistent toolbar override.");
}

static void TestTouchGeometry(NSString *root) {
    NSString *suite = [@"test.touch.geometry." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    CGRect bounds = CGRectMake(0, 0, 874, 402), safe = CGRectMake(62, 0, 750, 381);
    NSDictionary *geometry = AKTouchExportGeometry(defaults, bounds, safe, YES);
    assert(fabs([geometry[@"leftX"] doubleValue] * 874 - 176) < 0.001);
    assert(fabs([geometry[@"leftY"] doubleValue] * 402 - 135) < 0.001);
    assert(fabs([geometry[@"leftRadius"] doubleValue] * 402 - 52) < 0.001);
    assert([geometry[@"rightMinY"] doubleValue] == 0);
    assert([geometry[@"rightMinX"] doubleValue] < [geometry[@"rightX"] doubleValue]);
    NSString *path = [root stringByAppendingPathComponent:@"Interface/AddOns/WolkaraRoue/HostTouchLayout.lua"];
    NSError *error = nil;
    assert([TKForeverUI prepareTouchGeometry:geometry inWorkingDirectory:root error:&error]);
    assert(![NSFileManager.defaultManager fileExistsAtPath:path]);
    NSString *stub = @"-- Wolkara generated touch geometry v1\nlocal _, ns = ...\nns.HostTouchLayout = nil\n";
    Write(path, stub);
    NSString *config = Read(ConfigPath(root));
    assert([TKForeverUI prepareTouchGeometry:geometry inWorkingDirectory:root error:&error]);
    NSString *exported = Read(path);
    assert([exported containsString:@"leftX = "] && [exported containsString:@"version = 1"]);
    assert([Read(ConfigPath(root)) isEqual:config]);
    assert([TKForeverUI prepareTouchGeometry:geometry inWorkingDirectory:root error:&error]);
    assert([Read(path) isEqual:exported]);
    NSMutableDictionary *bad = [geometry mutableCopy]; bad[@"leftX"] = @"not a number";
    assert(![TKForeverUI prepareTouchGeometry:bad inWorkingDirectory:root error:&error]);
    assert([Read(path) isEqual:exported]);
    assert([TKForeverUI prepareTouchGeometry:nil inWorkingDirectory:root error:&error]);
    assert([Read(path) isEqual:stub]);
    Write(path, @"-- user-owned file\n");
    assert(![TKForeverUI prepareTouchGeometry:geometry inWorkingDirectory:root error:&error]);
    assert([Read(path) isEqual:@"-- user-owned file\n"]);
    [defaults setObject:@{@"version":@2, @"sticksOnly":@YES, @"positions":@{@"left":@[@0.5,@0.5]}} forKey:@"WolkaraForeverTouchLayoutV1"];
    geometry = AKTouchExportGeometry(defaults, bounds, safe, YES);
    assert(fabs([geometry[@"leftX"] doubleValue] - 0.5) < 0.001);
    assert(AKTouchExportGeometry(defaults, bounds, safe, NO) == nil);
    [defaults setObject:@{@"version":@2, @"sticksOnly":@YES, @"floatingSticks":@YES} forKey:@"WolkaraForeverTouchLayoutV1"];
    assert(AKTouchExportGeometry(defaults, bounds, safe, YES) == nil);
    [defaults removePersistentDomainForName:suite];
    puts("TOUCH_GEOMETRY_PASS: native phone geometry, saved positions, bounded export, idempotence, opt-out and configuration preservation.");
}

int main(void) {
    @autoreleasepool {
        NSFileManager *files = NSFileManager.defaultManager;
        NSString *root = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"forever-config-tests"]
                          stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        assert([files createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL]);
        NSString *wtf = [root stringByAppendingPathComponent:@"WTF"];
        assert([files createDirectoryAtPath:wtf withIntermediateDirectories:YES attributes:nil error:NULL]);

        // --- graphics reset removes the allowlist and keeps every other byte
        NSString *input =
            @"SET portal \"eu\"\n"
             "SET textLocale \"enUS\"\n"
             "SET audioLocale \"enUS\"\n"
             "SET accountName \"TESTACCOUNT\"\n"
             "SET gxResolution \"1920x1080\"\n"
             "SET graphicsQuality \"7\"\n"
             "SET Sound_OutputDriverIndex \"0\"\n"
             "SET GamePadEnable \"1\"\n"
             "SET GamePadConfig \"Addons\"\n"
             "SET uiScale \"1\"\n"
             "SET bindingMoveForward \"W\"\n"
             "SET unknownSetting \"keep\"\n"
             "SET cameraDistance \"1.5\"\n";
        NSString *expected =
            @"SET portal \"eu\"\n"
             "SET textLocale \"enUS\"\n"
             "SET audioLocale \"enUS\"\n"
             "SET accountName \"TESTACCOUNT\"\n"
             "SET Sound_OutputDriverIndex \"0\"\n"
             "SET GamePadEnable \"1\"\n"
             "SET GamePadConfig \"Addons\"\n"
             "SET uiScale \"1\"\n"
             "SET bindingMoveForward \"W\"\n"
             "SET unknownSetting \"keep\"\n"
             "SET cameraDistance \"1.5\"\n";
        Write(ConfigPath(root), input);
        NSError *error = nil;
        assert([TKForeverUI resetGraphicsInWorkingDirectory:root error:&error]);        assert([Read(ConfigPath(root)) isEqual:expected]);

        // Nothing else under the UI was touched.
        NSString *addon = [root stringByAppendingPathComponent:@"Interface/AddOns/A/A.toc"];
        Write(addon, @"## Title: A\n");
        assert([TKForeverUI resetGraphicsInWorkingDirectory:root error:&error]);
        assert([Read(addon) isEqual:@"## Title: A\n"]);

        // --- CRLF endings survive, and only the graphics lines go
        NSString *crlf =
            @"SET portal \"us\"\r\n"
             "SET gxRefresh \"60\"\r\n"
             "SET accountName \"ACC\"\r\n";
        Write(ConfigPath(root), crlf);
        assert([TKForeverUI resetGraphicsInWorkingDirectory:root error:&error]);
        assert([Read(ConfigPath(root)) isEqual:@"SET portal \"us\"\r\nSET accountName \"ACC\"\r\n"]);

        // --- a missing config is already at defaults
        NSString *bare = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"forever-config-bare"]
                          stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        assert([files createDirectoryAtPath:[bare stringByAppendingPathComponent:@"WTF"]
                    withIntermediateDirectories:YES attributes:nil error:NULL]);
        assert([TKForeverUI resetGraphicsInWorkingDirectory:bare error:&error]);
        assert(![files fileExistsAtPath:ConfigPath(bare)]);
        assert(![TKForeverUI gamepadEnabledInWorkingDirectory:bare]);

        // --- the gamepad row creates a bounded config when there is none
        assert([TKForeverUI enableGamepadInWorkingDirectory:bare error:&error]);
        assert([Read(ConfigPath(bare)) isEqual:@"SET GamePadEnable \"1\"\n"]);
        assert([TKForeverUI gamepadEnabledInWorkingDirectory:bare]);

        // --- and normalises duplicates rather than appending a second answer
        NSString *duplicates =
            @"SET portal \"eu\"\n"
             "SET GamePadEnable \"0\"\n"
             "SET accountName \"ACC\"\n"
             "SET GamePadEnable \"1\"\n";
        Write(ConfigPath(root), duplicates);
        assert([TKForeverUI enableGamepadInWorkingDirectory:root error:&error]);
        NSString *normalised = Read(ConfigPath(root));
        NSMutableArray<NSString *> *lines = [[normalised componentsSeparatedByString:@"\n"] mutableCopy];
        [lines removeLastObject];   // the trailing newline
        NSUInteger assignments = 0;
        for (NSString *line in lines) if ([line hasPrefix:@"SET GamePadEnable"]) {
            assignments++;
            assert([line isEqual:@"SET GamePadEnable \"1\""]);
        }
        assert(assignments == 1);
        assert([normalised containsString:@"SET portal \"eu\""]);
        assert([normalised containsString:@"SET accountName \"ACC\""]);

        // --- the switch's off position uses the same normalisation
        assert([TKForeverUI setGamepad:NO inWorkingDirectory:root error:&error]);
        NSString *off = Read(ConfigPath(root));
        NSUInteger offAssignments = 0;
        for (NSString *line in [off componentsSeparatedByString:@"\n"]) {
            if (![line hasPrefix:@"SET GamePadEnable"]) continue;
            offAssignments++;
            assert([line isEqual:@"SET GamePadEnable \"0\""]);
        }
        assert(offAssignments == 1);
        assert(![TKForeverUI gamepadEnabledInWorkingDirectory:root]);
        // Turning it back on leaves exactly one "1".
        assert([TKForeverUI setGamepad:YES inWorkingDirectory:root error:&error]);
        assert([TKForeverUI gamepadEnabledInWorkingDirectory:root]);

        // --- setCVars: replaces one, adds the rest, keeps every other byte
        Write(ConfigPath(root),
              @"SET portal \"eu\"\n"
               "SET renderScale \"1.000000\"\n"
               "SET cameraDistance \"1.5\"\n");
        NSDictionary *presetCVars = @{@"renderScale": @"0.75", @"gxForegroundFPS": @"60"};
        assert([TKForeverUI setCVars:presetCVars inWorkingDirectory:root error:&error]);
        NSString *afterCVars = Read(ConfigPath(root));
        assert([afterCVars isEqual:@"SET portal \"eu\"\n"
                                "SET cameraDistance \"1.5\"\n"
                                "SET gxForegroundFPS \"60\"\n"
                                "SET renderScale \"0.75\"\n"]);
        // A second application is stable: no duplicated lines.
        assert([TKForeverUI setCVars:presetCVars inWorkingDirectory:root error:&error]);
        assert([Read(ConfigPath(root)) isEqual:afterCVars]);

        // --- language selection replaces only both locale CVars, including
        // duplicates, and retains line endings and unrelated account settings.
        Write(ConfigPath(root),
              @"SET portal \"eu\"\r\n"
               "SET textLocale \"enUS\"\r\n"
               "SET accountName \"ACC\"\r\n"
               "SET audioLocale \"esES\"\r\n"
               "SET textLocale \"esES\"\r\n");
        assert([TKForeverUI setLocale:@"deDE" inWorkingDirectory:root error:&error]);
        assert([Read(ConfigPath(root)) isEqual:@"SET portal \"eu\"\r\n"
                                              "SET accountName \"ACC\"\r\n"
                                              "SET audioLocale \"deDE\"\n"
                                              "SET textLocale \"deDE\"\n"]);
        assert([TKForeverUI setLocale:@"zhCN" inWorkingDirectory:root error:&error]);
        assert([Read(ConfigPath(root)) containsString:@"SET textLocale \"zhCN\""]);
        assert([Read(ConfigPath(root)) containsString:@"SET audioLocale \"zhCN\""]);
        assert([Read(ConfigPath(root)) containsString:@"SET portal \"eu\""]);
        assert([Read(ConfigPath(root)) containsString:@"SET accountName \"ACC\""]);
        NSString *localeConfig = Read(ConfigPath(root));
        assert(![localeConfig containsString:@"enUS"] && ![localeConfig containsString:@"esES"]);
        assert(![TKForeverUI setLocale:@"invalid" inWorkingDirectory:root error:&error]);
        assert([Read(ConfigPath(root) ) isEqual:localeConfig]);

        // --- names and values that would write an unreadable line are refused
        NSDictionary *badName = @{@"render Scale": @"0.5"};
        NSDictionary *badSpace = @{@"renderScale": @"0.5 0.5"};
        NSDictionary *badQuote = @{@"renderScale": @"\"0.5\""};
        assert(![TKForeverUI setCVars:badName inWorkingDirectory:root error:&error]);
        assert(![TKForeverUI setCVars:badSpace inWorkingDirectory:root error:&error]);
        assert(![TKForeverUI setCVars:badQuote inWorkingDirectory:root error:&error]);
        assert([Read(ConfigPath(root)) isEqual:localeConfig]); // nothing was written

        // --- the performance preset writes exactly its own names
        assert([TKForeverUI applyPerformancePresetInWorkingDirectory:root error:&error]);
        NSString *preset = Read(ConfigPath(root));
        for (NSString *name in TKForeverUI.performancePreset) {
            NSUInteger found = 0;
            for (NSString *line in [preset componentsSeparatedByString:@"\n"])
                if ([line hasPrefix:[NSString stringWithFormat:@"SET %@ ", name]]) found++;
            assert(found == 1);
        }
        assert([preset containsString:@"SET renderScale \"0.75\""]);
        assert([preset containsString:@"SET gxForegroundFPS \"60\""]);

        // --- a graphics reset removes what the preset wrote
        assert([TKForeverUI resetGraphicsInWorkingDirectory:root error:&error]);
        NSString *reset = Read(ConfigPath(root));
        assert(![reset containsString:@"renderScale"]);
        assert(![reset containsString:@"gxForegroundFPS"]);
        assert([reset containsString:@"SET portal \"eu\""]);

        // --- a WTF folder outside the working directory is refused
        NSString *outside = [root stringByAppendingPathComponent:@"../outside-wtf"];
        [files createDirectoryAtPath:outside withIntermediateDirectories:YES attributes:nil error:NULL];
        // The operation resolves WTF under the directory it is given, so the
        // boundary that matters is that it never returns a path outside it.
        NSString *resolved = [TKForeverUI wtfDirectoryInWorkingDirectory:root create:NO error:&error];
        assert(resolved != nil && [resolved hasPrefix:root]);

        TestTouchStartup(root);
        TestTouchGeometry(root);
        [files removeItemAtPath:root error:NULL];
        [files removeItemAtPath:bare error:NULL];
        [files removeItemAtPath:outside error:NULL];
        puts("FOREVER_CONFIG_PASS: graphics allowlist, byte preservation, CRLF, missing config, gamepad normalisation, CVar set/replace/idempotence, refusal of unreadable names and values, performance preset and its reset, and path boundary.");
        return 0;
    }
}
