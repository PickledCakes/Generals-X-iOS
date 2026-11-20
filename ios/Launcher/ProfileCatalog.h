// GeneralsX @feature Codex 20/11/2026 Bundle-selected profiles drive launch, save transfer and diagnostics.
#import <Foundation/Foundation.h>
NSArray<NSDictionary *> *GXProfiles(void);
NSDictionary *GXProfile(NSString *identifier);
NSString *GXProfileSupport(NSString *identifier);
