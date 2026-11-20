#import "ProfileCatalog.h"
NSArray<NSDictionary *> *GXProfiles(void) {
    static NSArray *profiles=nil;
    if(!profiles) {
        NSArray *stored=[NSArray arrayWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"GameProfiles" ofType:@"plist"]];
        NSMutableArray *available=[NSMutableArray array];
        for(NSDictionary *profile in stored) {
            NSString *identifier=profile[@"id"];
            if(![identifier isKindOfClass:NSString.class] || [identifier rangeOfString:@"/"].location!=NSNotFound || [identifier containsString:@".."] || !identifier.length)continue;
            NSString *data=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:[NSString stringWithFormat:@"Games/%@/GameData",identifier]];
            BOOL directory=NO;if([[NSFileManager defaultManager] fileExistsAtPath:data isDirectory:&directory] && directory)[available addObject:profile];
        }
        profiles=[available copy];
    }
    return profiles;
}
NSDictionary *GXProfile(NSString *identifier) {for(NSDictionary *profile in GXProfiles())if([profile[@"id"] isEqualToString:identifier])return profile;return nil;}
NSString *GXProfileSupport(NSString *identifier) {return [NSHomeDirectory() stringByAppendingPathComponent:[@"Library/Application Support/GeneralsX/" stringByAppendingString:identifier]];}
