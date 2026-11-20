// GeneralsX @feature Codex 19/11/2026 One selected engine per iOS app session.
#import <UIKit/UIKit.h>
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <dlfcn.h>
#include <unistd.h>
#include "LaunchOptions.h"
#import "SaveTransfer.h"
#import "ProfileCatalog.h"
#import "AppIconPicker.h"

static NSString *GXDocuments(void) { return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]; }
static NSString *GXStatePath(void) { return [GXDocuments() stringByAppendingPathComponent:@"LauncherSession.json"]; }
static NSString *GXEndPath(void) { return [GXDocuments() stringByAppendingPathComponent:@"LauncherSessionEnded.txt"]; }
static NSString *GXSupport(NSString *game) {
    return [NSHomeDirectory() stringByAppendingPathComponent:[@"Library/Application Support/GeneralsX/" stringByAppendingString:game]];
}
static void GXLog(NSString *message) {
    NSString *path = [GXDocuments() stringByAppendingPathComponent:@"launcher.log"];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if ([attributes fileSize] > 256 * 1024) {
        NSString *previous = [path stringByAppendingString:@".previous"];
        [[NSFileManager defaultManager] removeItemAtPath:previous error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:path toPath:previous error:nil];
    }
    FILE *file = fopen(path.fileSystemRepresentation, "a");
    if (file) { fprintf(file, "%s %s\n", [NSDate.date.description UTF8String], message.UTF8String); fclose(file); }
}
static NSInteger GXSaveCount(NSString *game) {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[GXSupport(game) stringByAppendingPathComponent:@"Save"] error:nil];
    NSInteger count = 0;
    for (NSString *name in files) if ([name.pathExtension.lowercaseString isEqualToString:@"sav"]) ++count;
    return count;
}
static NSString *GXReport(void) {
    NSDictionary *build=[NSDictionary dictionaryWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"BuildInfo" ofType:@"plist"]];
    NSMutableString *report=[NSMutableString stringWithFormat:@"Generals Collection %@ (%@)\niPadOS %@\nSigning expires: %@\n",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"],UIDevice.currentDevice.systemVersion,build[@"SigningExpires"] ?: @"Unknown"];
    for(NSDictionary *profile in GXProfiles())[report appendFormat:@"\n%@: %ld saves",profile[@"title"],(long)GXSaveCount(profile[@"id"])];
    [report appendString:@"\n\nOne engine runs per app session. Exit Game closes the app. Reopen to choose a game."];
    return report;
}

// GeneralsX @feature Codex 19/11/2026 Preferences apply to either game at its next cold start.
@interface GXLauncherSettingsController : UITableViewController
@end
@implementation GXLauncherSettingsController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"Launcher Settings";
    self.tableView.rowHeight = UITableViewAutomaticDimension; self.tableView.estimatedRowHeight = 100;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
}
- (void)done { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 3; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Applies to every game the next time one starts. In-game cutscenes, camera movements and mission triggers are unchanged.";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone; cell.detailTextLabel.numberOfLines = 0;
    // GeneralsX @feature Codex 20/11/2026 Icon selection is independent of engine/movie preferences.
    if(indexPath.row==2) {
        cell.textLabel.text=@"Home Screen Icon";cell.detailTextLabel.text=@"Original Generals, Zero Hour, ShockWave, GLA or China.";
        cell.selectionStyle=UITableViewCellSelectionStyleDefault;cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;
    }
    UISwitch *toggle = [[UISwitch alloc] init];
    if (indexPath.row == 0) {
        cell.textLabel.text = @"Static main menu";
        cell.detailTextLabel.text = @"Show a still image instead of the animated battlefield in the main menu.";
        toggle.on = [NSUserDefaults.standardUserDefaults boolForKey:@"GXStaticMenu"];
        toggle.accessibilityIdentifier = @"static-main-menu";
        [toggle addTarget:self action:@selector(staticChanged:) forControlEvents:UIControlEventValueChanged];
    } else {
        cell.textLabel.text = @"Disable movies";
        cell.detailTextLabel.text = @"Skip EA logos, opening movies, mission-loading videos and other video playback. In-game cutscenes still play.";
        toggle.on = [NSUserDefaults.standardUserDefaults boolForKey:@"GXDisableMovies"];
        toggle.accessibilityIdentifier = @"disable-movies";
        [toggle addTarget:self action:@selector(moviesChanged:) forControlEvents:UIControlEventValueChanged];
    }
    cell.accessoryView = toggle; return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if(indexPath.row==2)[self.navigationController pushViewController:[[GXAppIconController alloc] initWithStyle:UITableViewStyleInsetGrouped] animated:YES];
}
- (void)staticChanged:(UISwitch *)toggle { [NSUserDefaults.standardUserDefaults setBool:toggle.on forKey:@"GXStaticMenu"]; }
- (void)moviesChanged:(UISwitch *)toggle { [NSUserDefaults.standardUserDefaults setBool:toggle.on forKey:@"GXDisableMovies"]; }
@end

@interface GXLauncherController : UIViewController
@property(nonatomic,copy) NSString *selection;
@property(nonatomic,strong) UILabel *subtitle;
@end
@implementation GXLauncherController
- (BOOL)prefersStatusBarHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskLandscape; }
- (UIButton *)gameButton:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)icon game:(NSString *)game {
    UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
    config.title = title; config.subtitle = subtitle;
    config.baseBackgroundColor = [UIColor colorWithRed:0.075 green:0.13 blue:0.21 alpha:1];
    config.baseForegroundColor = UIColor.whiteColor;
    config.imagePlacement = NSDirectionalRectEdgeTop;
    config.imagePadding = 18; config.titlePadding = 8;
    config.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    config.contentInsets = NSDirectionalEdgeInsetsMake(24, 18, 24, 18);
    UIImage *original = [UIImage imageWithContentsOfFile:[NSBundle.mainBundle pathForResource:icon ofType:@"png"]];
    if (original) {
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(104,104)];
        config.image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { [original drawInRect:CGRectMake(0,0,104,104)]; }];
    }
    config.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
        NSMutableDictionary *result = attributes.mutableCopy; result[NSFontAttributeName] = [UIFont systemFontOfSize:24 weight:UIFontWeightHeavy]; return result;
    };
    UIButton *button = [UIButton buttonWithConfiguration:config primaryAction:nil];
    button.accessibilityIdentifier = [@"launch-" stringByAppendingString:game];
    button.layer.borderWidth = 1; button.layer.borderColor = [UIColor colorWithWhite:0.5 alpha:0.25].CGColor;
    [button addAction:[UIAction actionWithHandler:^(UIAction *action) {
        if (!self.selection) { self.selection = game; self.subtitle.text = [@"Starting " stringByAppendingString:title]; }
    }] forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (void)loadView {
    self.view = [[UIView alloc] init];
    self.view.backgroundColor = [UIColor colorWithRed:0.025 green:0.04 blue:0.065 alpha:1];
    UILabel *eyebrow = [[UILabel alloc] init]; eyebrow.text = @"COMMAND & CONQUER";
    eyebrow.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold]; eyebrow.textColor = [UIColor colorWithRed:0.88 green:0.71 blue:0.36 alpha:1]; eyebrow.textAlignment = NSTextAlignmentCenter;
    UILabel *title = [[UILabel alloc] init]; title.text = @"GENERALS COLLECTION";
    title.font = [UIFont systemFontOfSize:30 weight:UIFontWeightHeavy]; title.adjustsFontSizeToFitWidth = YES; title.minimumScaleFactor = 0.6; title.textColor = UIColor.whiteColor; title.textAlignment = NSTextAlignmentCenter;
    self.subtitle = [[UILabel alloc] init]; self.subtitle.text = @"Choose your game"; self.subtitle.textColor = UIColor.lightGrayColor; self.subtitle.textAlignment = NSTextAlignmentCenter;
    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[eyebrow,title,self.subtitle]]; heading.axis = UILayoutConstraintAxisVertical; heading.spacing = 6;
    NSMutableArray *buttons=[NSMutableArray array];
    for(NSDictionary *profile in GXProfiles()) [buttons addObject:[self gameButton:profile[@"title"] subtitle:profile[@"subtitle"] icon:profile[@"icon"] game:profile[@"id"]]];
    UIStackView *games=[[UIStackView alloc] initWithArrangedSubviews:buttons];
    games.axis = UILayoutConstraintAxisHorizontal; games.spacing = 22; games.distribution = UIStackViewDistributionFillEqually;
    UIScrollView *gameScroll=[[UIScrollView alloc] init];gameScroll.showsHorizontalScrollIndicator=GXProfiles().count>3;
    games.translatesAutoresizingMaskIntoConstraints=NO;[gameScroll addSubview:games];
    [NSLayoutConstraint activateConstraints:@[[games.leadingAnchor constraintEqualToAnchor:gameScroll.contentLayoutGuide.leadingAnchor],[games.trailingAnchor constraintEqualToAnchor:gameScroll.contentLayoutGuide.trailingAnchor],[games.topAnchor constraintEqualToAnchor:gameScroll.contentLayoutGuide.topAnchor],[games.bottomAnchor constraintEqualToAnchor:gameScroll.contentLayoutGuide.bottomAnchor],[games.heightAnchor constraintEqualToAnchor:gameScroll.frameLayoutGuide.heightAnchor]]];
    if(GXProfiles().count<=3)[games.widthAnchor constraintEqualToAnchor:gameScroll.frameLayoutGuide.widthAnchor].active=YES;
    else [games.widthAnchor constraintEqualToConstant:GXProfiles().count*290+(GXProfiles().count-1)*22].active=YES;
    UILabel *note = [[UILabel alloc] init]; note.text = @"Exit the game, then reopen to choose another."; note.font = [UIFont systemFontOfSize:13]; note.textColor = UIColor.lightGrayColor; note.textAlignment = NSTextAlignmentCenter;
    UIButton *diagnostics = [UIButton buttonWithType:UIButtonTypeSystem]; [diagnostics setTitle:@"Diagnostics" forState:UIControlStateNormal];
    [diagnostics addAction:[UIAction actionWithHandler:^(UIAction *action) { [self showDiagnostics]; }] forControlEvents:UIControlEventTouchUpInside];
    UIButton *settings = [UIButton buttonWithType:UIButtonTypeSystem]; [settings setTitle:@"Settings" forState:UIControlStateNormal];
    [settings addAction:[UIAction actionWithHandler:^(UIAction *action) { [self showSettings]; }] forControlEvents:UIControlEventTouchUpInside];
    UIButton *saves = [UIButton buttonWithType:UIButtonTypeSystem];[saves setTitle:@"Saved Games" forState:UIControlStateNormal];
    [saves addAction:[UIAction actionWithHandler:^(UIAction *action){[self showSavedGames];}] forControlEvents:UIControlEventTouchUpInside];
    UIStackView *tools = [[UIStackView alloc] initWithArrangedSubviews:@[settings,saves,diagnostics]];
    tools.axis = UILayoutConstraintAxisHorizontal; tools.distribution = UIStackViewDistributionFillEqually; tools.spacing = 16;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[heading,gameScroll,note,tools]];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack]; UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint *preferredWidth = [stack.widthAnchor constraintEqualToAnchor:safe.widthAnchor multiplier:0.85];
    preferredWidth.priority = UILayoutPriorityDefaultHigh; preferredWidth.active = YES;
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor], [stack.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:1100], [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:safe.leadingAnchor constant:28],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:safe.trailingAnchor constant:-28],

        [gameScroll.heightAnchor constraintGreaterThanOrEqualToConstant:230], [gameScroll.heightAnchor constraintLessThanOrEqualToConstant:330],
        [stack.topAnchor constraintGreaterThanOrEqualToAnchor:safe.topAnchor constant:12], [stack.bottomAnchor constraintLessThanOrEqualToAnchor:safe.bottomAnchor constant:-12]
    ]];
}
- (void)showSavedGames {
    GXSaveTransferController *saves=[[GXSaveTransferController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *navigation=[[UINavigationController alloc] initWithRootViewController:saves];
    navigation.modalPresentationStyle=UIModalPresentationFormSheet;[self presentViewController:navigation animated:YES completion:nil];
}
- (void)showSettings {
    GXLauncherSettingsController *settings = [[GXLauncherSettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:settings];
    navigation.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:navigation animated:YES completion:nil];
}
- (void)resetSettings:(NSString *)game {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Reset settings?" message:@"Your saved games will be kept. A backup of the current settings will also be kept." preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Reset settings" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *path = [GXSupport(game) stringByAppendingPathComponent:@"Options.ini"];
        NSError *error = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            NSString *backup = [path stringByAppendingFormat:@".backup-%.0f", NSDate.date.timeIntervalSince1970];
            [[NSFileManager defaultManager] moveItemAtPath:path toPath:backup error:&error];
        }
        GXLog(error ? error.localizedDescription : [@"Settings reset: " stringByAppendingString:game]);
        UIAlertController *result = [UIAlertController alertControllerWithTitle:error ? @"Settings were not reset" : @"Settings reset" message:error ? error.localizedDescription : @"Default settings will be restored next time this game starts. Saved games are unchanged." preferredStyle:UIAlertControllerStyleAlert];
        [result addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:result animated:YES completion:nil];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}
- (void)showDiagnostics {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Diagnostics" message:GXReport() preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Export report & logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *path = [GXDocuments() stringByAppendingPathComponent:@"LauncherReport.txt"];
        [GXReport() writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSMutableArray *items = [NSMutableArray arrayWithObject:[NSURL fileURLWithPath:path]];
        NSMutableArray *logNames=[NSMutableArray arrayWithArray:@[@"launcher.log",@"launcher.log.previous"]];
        for(NSDictionary *profile in GXProfiles())for(NSString *suffix in @[@"-stderr.log",@"-stderr-prev.log"])[logNames addObject:[profile[@"id"] stringByAppendingString:suffix]];
        for (NSString *name in logNames) {
            NSString *log = [GXDocuments() stringByAppendingPathComponent:name];
            if ([[NSFileManager defaultManager] fileExistsAtPath:log]) [items addObject:[NSURL fileURLWithPath:log]];
        }
        UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
        share.popoverPresentationController.sourceView = self.view;
        share.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),CGRectGetMidY(self.view.bounds),1,1);
        [self presentViewController:share animated:YES completion:nil];
    }]];
    for(NSDictionary *profile in GXProfiles()) {
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Reset %@ settings",profile[@"title"]] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self resetSettings:profile[@"id"]];}]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:GXDocuments() withIntermediateDirectories:YES attributes:nil error:nil];
        GXLog(@"Launcher started");
        SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight");
        if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) { GXLog([NSString stringWithUTF8String:SDL_GetError()]); return 1; }
        SDL_Window *window = SDL_CreateWindow("Generals Collection", 1133, 744, SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY);
        if (!window) { GXLog([NSString stringWithUTF8String:SDL_GetError()]); return 1; }
        UIWindow *native = (__bridge UIWindow *)SDL_GetPointerProperty(SDL_GetWindowProperties(window), SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, nullptr);
        UIViewController *host = native.rootViewController;
        GXLauncherController *controller = [[GXLauncherController alloc] init];
        [host addChildViewController:controller]; controller.view.frame = host.view.bounds; controller.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [host.view addSubview:controller.view]; [controller didMoveToParentViewController:host];
        GXLog(@"Selector ready");
        GXVerifySaveTransfer();
        GXLog([NSString stringWithFormat:@"Available saves: Generals=%ld ZeroHour=%ld",(long)GXSaveCount(@"Generals"),(long)GXSaveCount(@"GeneralsZH")]);
        Uint64 readyAt = SDL_GetTicks(); bool snapshotTaken = false; bool iconQARun = false;
        if (getenv("GX_LAUNCHER_CAPTURE_SETTINGS")) [controller showSettings];
        if (getenv("GX_LAUNCHER_CAPTURE_SAVES")) [controller showSavedGames];
        if (getenv("GX_LAUNCHER_CAPTURE_ICONS")) {
            UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:[[GXAppIconController alloc] initWithStyle:UITableViewStyleInsetGrouped]];
            nav.modalPresentationStyle=UIModalPresentationFormSheet;[controller presentViewController:nav animated:NO completion:nil];
        }
        // Explicit diagnostic launch override; normal icon launches always show the selector.
        const char *testGame = getenv("GX_LAUNCHER_GAME");
        if (testGame && GXProfile([NSString stringWithUTF8String:testGame])) controller.selection=[NSString stringWithUTF8String:testGame];
        while (true) {
            SDL_Event event;
            while (SDL_PollEvent(&event)) if (event.type == SDL_EVENT_QUIT) { SDL_Quit(); return 0; }
            if (!iconQARun && getenv("GX_QA_APP_ICON") && SDL_GetTicks()-readyAt>2000) {iconQARun=true;GXRunAppIconQA();}
            // An explicit device-QA override captures the real selector for layout verification.
            if (!snapshotTaken && getenv("GX_LAUNCHER_CAPTURE") && SDL_GetTicks()-readyAt > 1000) {
                [native layoutIfNeeded];
                UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:native.bounds];
                UIImage *snapshot = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { [native drawViewHierarchyInRect:native.bounds afterScreenUpdates:YES]; }];
                [UIImagePNGRepresentation(snapshot) writeToFile:[GXDocuments() stringByAppendingPathComponent:@"LauncherPreview.png"] atomically:YES];
                snapshotTaken = true;
            }
            if (!controller.selection || controller.presentedViewController) { SDL_Delay(10); continue; }
            NSString *game = controller.selection;
            NSString *framework=GXProfile(game)[@"engine"];
            NSString *enginePath = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.framework/%@",framework,framework]];
            // Set per-engine registry storage before static initializers can run during dlopen.
            setenv("GX_REGISTRY_DIRECTORY",GXSupport(game).fileSystemRepresentation,1);
            setenv("GX_USER_DATA_DIRECTORY",GXSupport(game).fileSystemRepresentation,1);
            GXLog([@"Loading engine: " stringByAppendingString:game]);
            void *handle = dlopen(enginePath.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
            auto entry = handle ? reinterpret_cast<int (*)(int,char**)>(dlsym(handle,"GXEngineMain")) : nullptr;
            if (!entry) {
                const char *error = dlerror(); NSString *message = error ? [NSString stringWithUTF8String:error] : @"Engine entry point not found"; GXLog(message);
                controller.selection = nil; controller.subtitle.text = @"Choose your game";
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Unable to start game" message:message preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; [controller presentViewController:alert animated:YES completion:nil]; continue;
            }
            [[NSFileManager defaultManager] removeItemAtPath:GXEndPath() error:nil];
            NSDictionary *state = @{@"game":game,@"started":NSDate.date.description,@"status":@"running"};
            [[NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:nil] writeToFile:GXStatePath() atomically:YES];
            setenv("GX_ENGINE_LOG_NAME",game.UTF8String,1); setenv("GX_SESSION_ENDED_PATH",GXEndPath().fileSystemRepresentation,1);
            NSString *anchor = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:[NSString stringWithFormat:@"Games/%@/Engine",game]];
            // The native selector initializes SDL before the engine. Resolve the bundled
            // graphics runtime explicitly rather than relying on standalone startup discovery.
            NSString *vulkan = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"MoltenVK.framework/MoltenVK"];
            SDL_SetHint(SDL_HINT_VULKAN_LIBRARY,vulkan.fileSystemRepresentation);
            GXLog([@"Starting engine: " stringByAppendingString:game]);
            [controller willMoveToParentViewController:nil]; [controller.view removeFromSuperview]; [controller removeFromParentViewController];
            SDL_DestroyWindow(window); SDL_FlushEvents(SDL_EVENT_FIRST,SDL_EVENT_LAST);
            // Keep the same SDL UIApplication lifecycle. The selected engine initializes its video subsystem.
            const bool staticMenu = [NSUserDefaults.standardUserDefaults boolForKey:@"GXStaticMenu"];
            const bool disableMovies = [NSUserDefaults.standardUserDefaults boolForKey:@"GXDisableMovies"];
            GXLog([NSString stringWithFormat:@"Launch options: staticMenu=%d disableMovies=%d",staticMenu,disableMovies]);
            auto arguments = gxLaunchArguments(anchor.UTF8String,argc,argv,staticMenu,disableMovies);
            std::vector<char *> engineArgv;
            for (auto &argument : arguments) engineArgv.push_back(argument.data());
            engineArgv.push_back(nullptr);
            int result = entry(static_cast<int>(arguments.size()),engineArgv.data());
            [[NSString stringWithFormat:@"%d\n",result] writeToFile:GXEndPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
            _exit(result);
        }
    }
}
