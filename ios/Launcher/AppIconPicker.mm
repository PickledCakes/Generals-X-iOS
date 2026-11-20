#import "AppIconPicker.h"
// The launcher runs a nested SDL/UIKit event loop; schedule UI work on its run loop.
static void GXIconOnMain(void (^block)(void)) {
    if(NSThread.isMainThread)block();
    else {CFRunLoopPerformBlock(CFRunLoopGetMain(),kCFRunLoopCommonModes,block);CFRunLoopWakeUp(CFRunLoopGetMain());}
}
static NSArray<NSDictionary *> *GXIconChoices(void) {
    return @[@{@"title":@"Original Generals",@"key":@"",@"image":@"GeneralsIcon"},
             @{@"title":@"Zero Hour",@"key":@"AppIconZeroHour",@"image":@"HomeIconZeroHour"},
             @{@"title":@"ShockWave",@"key":@"AppIconShockWave",@"image":@"HomeIconShockWave"},
             @{@"title":@"GLA",@"key":@"AppIconGLA",@"image":@"HomeIconGLA"},
             @{@"title":@"China",@"key":@"AppIconChina",@"image":@"HomeIconChina"}];
}
@implementation GXAppIconController
- (void)viewDidLoad {
    [super viewDidLoad];self.title=@"Home Screen Icon";self.tableView.rowHeight=76;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {return GXIconChoices().count;}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Changes the Generals X icon on your Home Screen. iPadOS confirms each change. The launcher keeps its Generals Collection title.";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *choice=GXIconChoices()[indexPath.row];UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text=choice[@"title"];NSString *selected=UIApplication.sharedApplication.alternateIconName ?: @"";
    cell.accessoryType=[selected isEqualToString:choice[@"key"]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    UIImage *original=[UIImage imageWithContentsOfFile:[NSBundle.mainBundle pathForResource:choice[@"image"] ofType:@"png"]];
    if(original) {UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(52,52)];cell.imageView.image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx){[original drawInRect:CGRectMake(0,0,52,52)];}];}
    cell.imageView.layer.cornerRadius=10;cell.imageView.clipsToBounds=YES;
    cell.accessibilityIdentifier=[@"app-icon-" stringByAppendingString:choice[@"key"]];return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];NSString *key=GXIconChoices()[indexPath.row][@"key"];
    if([(UIApplication.sharedApplication.alternateIconName ?: @"") isEqualToString:key])return;
    if(!UIApplication.sharedApplication.supportsAlternateIcons) {
        [self showError:@"Home Screen icon changes are unavailable on this device."];return;
    }
    tableView.userInteractionEnabled=NO;
    [UIApplication.sharedApplication setAlternateIconName:key.length ? key : nil completionHandler:^(NSError *error){
        GXIconOnMain(^{tableView.userInteractionEnabled=YES;[tableView reloadData];if(error)[self showError:error.localizedDescription];});
    }];
}
- (void)showError:(NSString *)message {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Unable to Change Icon" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:alert animated:YES completion:nil];
}
@end
// Explicit QA-only environment override; normal launcher starts never change the selected icon.
void GXRunAppIconQA(void) {
    const char *requested=getenv("GX_QA_APP_ICON");if(!requested)return;
    NSString *key=[NSString stringWithUTF8String:requested];if([key isEqualToString:@"primary"])key=@"";
    BOOL recognized=NO;for(NSDictionary *choice in GXIconChoices())if([choice[@"key"] isEqualToString:key])recognized=YES;
    if(!recognized)return;
    NSString *qaPath=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/AppIconQA.json"];
    NSDictionary *requestedState=@{@"phase":@"requested",@"key":key,@"supported":@(UIApplication.sharedApplication.supportsAlternateIcons)};
    [[NSJSONSerialization dataWithJSONObject:requestedState options:0 error:nil] writeToFile:qaPath atomically:YES];
    [UIApplication.sharedApplication setAlternateIconName:key.length ? key : nil completionHandler:^(NSError *error){
        GXIconOnMain(^{
            NSDictionary *result=@{@"supported":@(UIApplication.sharedApplication.supportsAlternateIcons),@"selected":UIApplication.sharedApplication.alternateIconName ?: @"primary",@"error":error.localizedDescription ?: @""};
            NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/AppIconQA.json"];
            [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
        });
    }];
}
