#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <math.h>

// Shared by the launcher export and the native controls. Coordinates are UIKit
// points here; the add-on receives normalized, bottom-origin coordinates.
static inline CGRect AKTouchDefaultStickFrame(CGRect safe, CGFloat frontScale, BOOL right) {
    CGFloat side = MAX(44, MIN(216 * frontScale, MIN(safe.size.height - 70, safe.size.width / 2 - 12)));
    return CGRectMake(right ? CGRectGetMaxX(safe) - 6 - side : CGRectGetMinX(safe) + 6,
                      CGRectGetMaxY(safe) - 6 - side, side, side);
}
static inline CGRect AKTouchSavedFrame(CGRect frame, CGRect bounds, NSArray *position) {
    CGFloat width = MAX(0, MIN(frame.size.width, bounds.size.width));
    CGFloat height = MAX(0, MIN(frame.size.height, bounds.size.height));
    CGFloat dx = MAX(0, bounds.size.width - width), dy = MAX(0, bounds.size.height - height);
    BOOL stored = [position isKindOfClass:NSArray.class] && position.count == 2 &&
        [position[0] isKindOfClass:NSNumber.class] && [position[1] isKindOfClass:NSNumber.class] &&
        isfinite([position[0] doubleValue]) && isfinite([position[1] doubleValue]);
    CGFloat x = stored ? [position[0] doubleValue] * dx : frame.origin.x - bounds.origin.x;
    CGFloat y = stored ? [position[1] doubleValue] * dy : frame.origin.y - bounds.origin.y;
    return CGRectMake(bounds.origin.x + MIN(MAX(x, 0), dx), bounds.origin.y + MIN(MAX(y, 0), dy), width, height);
}
static inline NSDictionary *AKTouchExportGeometry(NSUserDefaults *defaults, CGRect bounds, CGRect safe, BOOL mobile) {
    if (!mobile || bounds.size.width <= 0 || bounds.size.height <= 0) return nil;
    id enabled = [defaults objectForKey:@"TKTouchGamepadEnabled"];
    if (enabled && ![enabled boolValue]) return nil;
    id value = [defaults objectForKey:@"WolkaraForeverTouchLayoutV1"] ?: [defaults objectForKey:@"WowkaraTouchLayoutV1"];
    NSDictionary *saved = [value isKindOfClass:NSDictionary.class] ? value : @{};
    NSInteger version = [saved[@"version"] isKindOfClass:NSNumber.class] ? [saved[@"version"] integerValue] : 0;
    if (version > 2) return nil;
    BOOL compact = [saved[@"sticksOnly"] isKindOfClass:NSNumber.class] ? [saved[@"sticksOnly"] boolValue] : YES;
    BOOL floating = [saved[@"floatingSticks"] isKindOfClass:NSNumber.class] && [saved[@"floatingSticks"] boolValue];
    if (!compact || floating) return nil;
    CGFloat scale = [saved[@"frontScale"] isKindOfClass:NSNumber.class] ? [saved[@"frontScale"] doubleValue] : 1;
    scale = isfinite(scale) ? MIN(MAX(scale, 0.65), 1.4) : 1;
    NSString *key = version >= 2 && [saved[@"mode"] isEqual:@"simple"] ? @"simplePositions" : @"positions";
    NSDictionary *positions = [saved[key] isKindOfClass:NSDictionary.class] ? saved[key] : @{};
    NSMutableDictionary *result = [NSMutableDictionary new];
    CGFloat W = bounds.size.width, H = bounds.size.height;
    for (NSString *side in @[@"left", @"right"]) {
        BOOL right = [side isEqual:@"right"];
        CGRect frame = AKTouchSavedFrame(AKTouchDefaultStickFrame(safe, scale, right), safe, positions[side]);
        CGFloat factor = frame.size.width / 216, cx = CGRectGetMidX(frame) - bounds.origin.x;
        CGFloat cy = H - (CGRectGetMidY(frame) - bounds.origin.y), radius = 52 * factor;
        // The jump's extended hit sector reaches 146 points, 60 degrees either
        // side of down. Reserve its touch area as well as the drawn stick.
        CGFloat reachX = right ? 146 * sin(M_PI / 3) * factor : radius;
        CGFloat reachDown = right ? 146 * factor : radius;
        NSDictionary *values = @{@"X":@(cx / W), @"Y":@(cy / H), @"Radius":@(radius / H),
            @"MinX":@(MAX(0, cx - reachX) / W), @"MaxX":@(MIN(W, cx + reachX) / W),
            @"MinY":@(MAX(0, cy - reachDown) / H), @"MaxY":@(MIN(H, cy + radius) / H)};
        for (NSString *name in values) result[[side stringByAppendingString:name]] = values[name];
    }
    // The keyboard/collapse toolbar stays reachable below fitted windows.
    result[@"bottom"] = @(MIN(1, (H - (CGRectGetMaxY(safe) - bounds.origin.y) + 60) / H));
    return result;
}
