// Synthetic tickets only. Never access the user's real net.battle preferences:
// this test never calls +beginProcess, so +clear/+gameEnded leave net.battle alone,
// and every handoff goes to an isolated, random preferences domain.
#import <Foundation/Foundation.h>
#import "../launcher/WoW/BattleNetSession.h"
#include <assert.h>

static id Value(NSString *domain, NSString *name) {
    return CFBridgingRelease(CFPreferencesCopyAppValue(
        (__bridge CFStringRef)[@"Launch Options/WoW/" stringByAppendingString:name],
        (__bridge CFStringRef)domain));
}
static void SetValue(NSString *domain, NSString *name, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)[@"Launch Options/WoW/" stringByAppendingString:name],
                             (__bridge CFPropertyListRef)value,(__bridge CFStringRef)domain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)domain);
}
static BOOL Empty(NSString *domain) {
    for (NSString *name in @[@"WEB_TOKEN",@"REGION",@"LOCALE",@"GAME_ACCOUNT",@"ACCOUNT_TS",@"CONNECTION_STRING"])
        if (Value(domain,name)) return NO;
    return YES;
}
static BOOL WaitUntil(BOOL (^condition)(void), NSTimeInterval seconds) {
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!condition()) {
        if (deadline.timeIntervalSinceNow<=0) return NO;
        [NSThread sleepForTimeInterval:0.02];
    }
    return YES;
}
static NSString *Domain(void) {
    return [@"org.wolkaraforever.test.browser-login." stringByAppendingString:NSUUID.UUID.UUIDString];
}
int main(void) { @autoreleasepool {
    NSString *ticket=@"US-0123456789abcdef0123456789abcdef-123456789";
    NSString *callback=[@"http://localhost:0/?ST=" stringByAppendingString:ticket];
    assert([TKBattleNetCallbackTicket([NSURL URLWithString:callback]) isEqual:ticket]);
    for (NSString *bad in @[
        [callback stringByReplacingOccurrencesOfString:@"http:" withString:@"https:"],
        [callback stringByReplacingOccurrencesOfString:@"localhost" withString:@"localhost.evil.test"],
        [callback stringByReplacingOccurrencesOfString:@"localhost" withString:@"user@localhost"],
        [callback stringByReplacingOccurrencesOfString:@":0/" withString:@":80/"],
        [callback stringByReplacingOccurrencesOfString:@"/?" withString:@"/other?"],
        [callback stringByAppendingString:@"#fragment"],
        [callback stringByAppendingFormat:@"&ST=%@",ticket],
        @"http://localhost:0/?ST=", @"http://localhost:0/?ST=not-a-ticket",
        @"http://localhost:0/?ST=US-0123456789abcdef0123456789abcdef-0",
        [callback stringByAppendingString:[@"x" stringByPaddingToLength:8193 withString:@"x" startingAtIndex:0]]])
        assert(!TKBattleNetCallbackTicket([NSURL URLWithString:bad]));
    for (NSString *good in @[@"https://us.battle.net/login/en/", @"https://account.battle.net", @"https://blizzard.com:443/"])
        assert(TKBattleNetTrustedURL([NSURL URLWithString:good]));
    for (NSString *bad in @[@"http://us.battle.net", @"https://battle.net.evil.test", @"https://evilbattle.net", @"https://user@battle.net", @"https://battle.net:80", @"file:///battle.net"])
        assert(!TKBattleNetTrustedURL([NSURL URLWithString:bad]));
    for (NSString *good in @[@"https://accounts.google.com", @"https://login.microsoftonline.com", @"https://appleid.apple.com"])
        assert(TKBattleNetFederatedURL([NSURL URLWithString:good]));
    for (NSString *bad in @[@"http://accounts.google.com", @"https://user@accounts.google.com", @"https://accounts.google.com:8443", @"file:///provider"])
        assert(!TKBattleNetFederatedURL([NSURL URLWithString:bad]));

    assert([TKBattleNetLoginURL(@"cn").absoluteString isEqual:@"https://account.battlenet.com.cn/login/zh/?externalChallenge=login&app=WOW"]);
    assert([TKBattleNetLoginURL(@"CN") isEqual:TKBattleNetLoginURL(@"cn")]);
    assert([TKBattleNetLoginURL(@"eu").host isEqual:@"eu.battle.net"]);
    assert(!TKBattleNetLoginURL(@"cn.evil.test"));
    for (NSString *host in @[@"account.battlenet.com.cn",@"www.battlenet.com.cn",@"blizzard.cn",@"www.blizzard.cn"])
        assert(TKBattleNetTrustedURL([NSURL URLWithString:[@"https://" stringByAppendingString:host]]));
    for (NSString *url in @[@"https://battlenet.com.cn.evil.test",@"https://evilbattlenet.com.cn",
        @"http://account.battlenet.com.cn",@"https://account.battlenet.com.cn:8443",@"https://blizzard.cn.evil.test"])
        assert(!TKBattleNetTrustedURL([NSURL URLWithString:url]));
    // China tickets use the same one-use lifecycle and retain CN / zhCN at handoff.
    NSString *chinaTicket=@"CN-0123456789abcdef0123456789abcdef-123456789";
    assert([TKBattleNetCallbackTicket([NSURL URLWithString:[@"http://localhost:0/?ST=" stringByAppendingString:chinaTicket]]) isEqual:chinaTicket]);
    NSString *chinaDomain=Domain();
    SetValue(chinaDomain,@"CONNECTION_STRING",@"synthetic stale connection");
    SetValue(chinaDomain,@"GAME_ACCOUNT",@"synthetic stale account");
    assert([TKBattleNetSession acceptTicket:chinaTicket region:@"cn" locale:@"zhCN"]);
    assert([TKBattleNetSession handOffForProfile:@"wow-forever" domain:chinaDomain clearAfter:30].count==3);
    assert([Value(chinaDomain,@"REGION") isEqual:@"CN"] && [Value(chinaDomain,@"LOCALE") isEqual:@"zhCN"]);
    assert(!Value(chinaDomain,@"CONNECTION_STRING") && !Value(chinaDomain,@"GAME_ACCOUNT"));
    assert([TKBattleNetSession handOffForProfile:@"wow-forever" domain:chinaDomain clearAfter:30].count==0);
    [TKBattleNetSession gameEnded];
    assert(Empty(chinaDomain));

    // Wire-format fixtures (the game decodes exactly this; not a security boundary).
    NSData *encoded=TKBattleNetEncodeLaunchTicket(ticket,@"testuser");
    NSMutableString *hex=[NSMutableString new];
    const unsigned char *bytes=encoded.bytes;
    for (NSUInteger i=0;i<encoded.length;i++) [hex appendFormat:@"%02x",bytes[i]];
    assert([hex isEqual:@"eaf1d64a585191b2d1544912b0041d0d34b9f4506cc2337d83bf0acb22397d6a4164b9bce5b47562d2de8c1b5c638d92"]);
    assert(!TKBattleNetEncodeLaunchTicket(@"",@"testuser"));
    NSData *emptyUser=TKBattleNetEncodeLaunchTicket(ticket,@"");
    [hex setString:@""];
    bytes=emptyUser.bytes;
    for (NSUInteger i=0;i<emptyUser.length;i++) [hex appendFormat:@"%02x",bytes[i]];
    assert([hex isEqual:@"ef20f055d515ead3a87eb4fc91ab460bcb100a6b61039ea260a762d1f21bd9b17eb8cfe547e0193a5c4d64c6e4fbc222"]);

    // Low-level write/clear in an isolated domain.
    NSString *domain=Domain();
    assert(TKBattleNetWriteTicket(ticket,@"testuser",@"US",@"enUS",domain));
    assert([Value(domain,@"WEB_TOKEN") isEqual:encoded]);
    assert(!TKBattleNetWriteTicket(@"invalid",@"testuser",@"US",@"enUS",domain));
    assert(!TKBattleNetWriteTicket(ticket,@"testuser",@"INVALID",@"enUS",domain));
    assert(!TKBattleNetWriteTicket(ticket,@"testuser",@"US",@"invalid",domain));
    TKBattleNetClearTicket(domain);
    assert(Empty(domain));

    // Accepting a ticket stores nothing anywhere: it is held in memory only.
    NSDictionary *before=[NSUserDefaults.standardUserDefaults dictionaryRepresentation];
    assert(![TKBattleNetSession acceptTicket:@"invalid" region:@"us" locale:@"enUS"]);
    assert(![TKBattleNetSession acceptTicket:ticket region:@"zz" locale:@"enUS"]);
    assert(![TKBattleNetSession isReady]);
    assert([TKBattleNetSession acceptTicket:ticket region:@"us" locale:@"enUS"]);
    assert([TKBattleNetSession isReady]);
    assert(![[NSUserDefaults.standardUserDefaults dictionaryRepresentation].description containsString:@"0123456789abcdef0123456789abcdef"]);
    (void)before;
    // Reading the arguments does not consume the ticket.
    assert([[TKBattleNetSession argumentsForProfile:@"wow-forever"] isEqualToArray:(@[@"-launcherlogin",@"-uid",@"wowf"])]);
    assert([TKBattleNetSession argumentsForProfile:@"another-app"].count==0);
    assert([TKBattleNetSession isReady]);
    // Other profiles never receive or consume the ticket.
    domain=Domain();
    assert([TKBattleNetSession handOffForProfile:@"another-app" domain:domain clearAfter:5].count==0);
    assert(Empty(domain) && [TKBattleNetSession isReady]);

    // Single use: handoff writes prefs once and forgets the ticket.
    NSArray *args=[TKBattleNetSession handOffForProfile:@"wow-forever" domain:domain clearAfter:30];
    assert([args isEqualToArray:(@[@"-launcherlogin",@"-uid",@"wowf"])]);
    // The handoff uses this process's user name, as the game does.
    assert([Value(domain,@"WEB_TOKEN") isEqual:TKBattleNetEncodeLaunchTicket(ticket,NSUserName()?:@"")]);
    assert([Value(domain,@"REGION") isEqual:@"US"] && [Value(domain,@"LOCALE") isEqual:@"enUS"]);
    assert(![TKBattleNetSession isReady]);
    NSString *second=Domain();
    assert([TKBattleNetSession handOffForProfile:@"wow-forever" domain:second clearAfter:30].count==0);
    assert(Empty(second));
    // Game returned: everything goes, including keys the game adds.
    SetValue(domain,@"GAME_ACCOUNT",@"WoW1"); SetValue(domain,@"ACCOUNT_TS",@"1");
    [TKBattleNetSession gameEnded];
    assert(Empty(domain));

    // Deadline: prefs are removed even if the game never takes them.
    assert([TKBattleNetSession acceptTicket:ticket region:@"us" locale:@"enUS"]);
    domain=Domain();
    assert([TKBattleNetSession handOffForProfile:@"wow-forever" domain:domain clearAfter:0.4].count==3);
    assert(!Empty(domain));
    assert(WaitUntil(^{ return Empty(domain); },5.0));

    // Consumed: once the game removes WEB_TOKEN, the rest (GAME_ACCOUNT/ACCOUNT_TS) follow.
    assert([TKBattleNetSession acceptTicket:ticket region:@"us" locale:@"enUS"]);
    domain=Domain();
    assert([TKBattleNetSession handOffForProfile:@"wow-forever" domain:domain clearAfter:1.0].count==3);
    SetValue(domain,@"WEB_TOKEN",nil); SetValue(domain,@"GAME_ACCOUNT",@"WoW1"); SetValue(domain,@"ACCOUNT_TS",@"1");
    assert(WaitUntil(^{ return Empty(domain); },5.0));

    // A new sign-in or clear discards a pending handoff and its prefs.
    assert([TKBattleNetSession acceptTicket:ticket region:@"us" locale:@"enUS"]);
    domain=Domain();
    assert([TKBattleNetSession handOffForProfile:@"wow-forever" domain:domain clearAfter:30].count==3);
    [TKBattleNetSession clear];
    assert(Empty(domain) && ![TKBattleNetSession isReady]);
    puts("PASS Battle.net callback, wire format, memory-only ticket, single-use handoff and launch-pref cleanup");
} return 0; }
