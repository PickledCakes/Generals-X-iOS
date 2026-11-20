// GeneralsX @feature Codex 20/11/2026 Import/export original .sav files via Files and the share sheet.
#import "SaveTransfer.h"
#import "ProfileCatalog.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include "SaveTransferStore.h"
static NSString *GXGameSavePath(NSInteger game) {
    NSArray *profiles=GXProfiles();if(game<0 || game>=profiles.count)return nil;
    return [GXProfileSupport(profiles[game][@"id"]) stringByAppendingPathComponent:@"Save"];
}

static NSString *GXSaveTitle(const gxsave::Header &header,NSString *fallback) {
    NSString *text=[[NSString alloc] initWithBytes:header.description.data() length:header.description.size()*sizeof(wchar_t) encoding:NSUTF32LittleEndianStringEncoding];
    return text.length ? text : fallback;
}
@interface GXSaveTransferController () <UIDocumentPickerDelegate>
@property(nonatomic,strong) UISegmentedControl *gameControl;
@property(nonatomic,strong) NSArray<NSDictionary *> *saves;
@property(nonatomic,assign) BOOL busy;
@end
@implementation GXSaveTransferController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"Saved Games";
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"Import…" style:UIBarButtonItemStylePlain target:self action:@selector(importSaves)];
    NSMutableArray *titles=[NSMutableArray array];for(NSDictionary *profile in GXProfiles())[titles addObject:profile[@"title"]];
    self.gameControl=[[UISegmentedControl alloc] initWithItems:titles];self.gameControl.selectedSegmentIndex=0;
    [self.gameControl addTarget:self action:@selector(reloadSaves) forControlEvents:UIControlEventValueChanged];
    UIView *header=[[UIView alloc] initWithFrame:CGRectMake(0,0,500,64)];self.gameControl.frame=CGRectMake(20,12,460,34);self.gameControl.autoresizingMask=UIViewAutoresizingFlexibleWidth;[header addSubview:self.gameControl];self.tableView.tableHeaderView=header;
    self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=80;
    self.toolbarItems=@[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],[[UIBarButtonItem alloc] initWithTitle:@"Export All…" style:UIBarButtonItemStylePlain target:self action:@selector(exportAll)],[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
    [self.navigationController setToolbarHidden:NO animated:NO];[self reloadSaves];
}
// GeneralsX @bugfix Codex 20/11/2026 Size the selector from the presented table, including sheet resizing.
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIView *header=self.tableView.tableHeaderView;
    CGFloat width=CGRectGetWidth(self.tableView.bounds);
    header.frame=CGRectMake(0,0,width,64);
    self.gameControl.frame=CGRectMake(20,12,MAX(0,width-40),34);
}
- (void)done {if(!self.busy)[self dismissViewControllerAnimated:YES completion:nil];}
- (void)notify:(NSString *)title message:(NSString *)message {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:alert animated:YES completion:nil];
}
- (void)reloadSaves {
    NSMutableArray *rows=[NSMutableArray array];NSString *folder=GXGameSavePath(self.gameControl.selectedSegmentIndex);
    NSArray *names=[[[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    for(NSString *name in names) {
        if(![name.pathExtension.lowercaseString isEqualToString:@"sav"])continue;
        NSString *path=[folder stringByAppendingPathComponent:name];
        try {
            auto info=gxsave::inspect(std::filesystem::path(path.fileSystemRepresentation));
            [rows addObject:@{@"path":path,@"title":GXSaveTitle(info.header,name),@"legacy":@(info.header.characterBytes==4),@"valid":@YES,@"map":info.header.fileType==1 ? @"Mission checkpoint" : ([NSString stringWithUTF8String:info.header.map.c_str()] ?: @"")}];
        } catch(const std::exception &error) {
            [rows addObject:@{@"path":path,@"title":name,@"legacy":@NO,@"valid":@NO,@"map":@"Unrecognized save — kept unchanged"}];
        }
    }
    self.saves=rows;[self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {return self.saves.count;}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {return self.saves.count ? @"Tap a save to export" : @"No saves found";}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Import .sav files from Files, or export through the share sheet. Use the same game, patch and mods on PC (Generals 1.08 / Zero Hour 1.04; ShockWave saves require the same ShockWave + SPE version). Older iPad saves must be loaded and saved again before PC use. Original saves are never overwritten by imports.";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];NSDictionary *row=self.saves[indexPath.row];
    cell.textLabel.text=row[@"title"];cell.detailTextLabel.text=[NSString stringWithFormat:@"%@ · %@%@",[row[@"path"] lastPathComponent],row[@"map"],[row[@"legacy"] boolValue] ? @" · Legacy iPad format" : @""];
    cell.detailTextLabel.numberOfLines=0;cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];if(!self.busy)[self exportRows:@[self.saves[indexPath.row]]];
}
- (void)exportAll {if(!self.busy && self.saves.count)[self exportRows:self.saves];}
- (void)exportRows:(NSArray<NSDictionary *> *)rows {
    BOOL legacy=NO;for(NSDictionary *row in rows)if([row[@"legacy"] boolValue])legacy=YES;
    if(legacy) {
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Older iPad save format" message:@"For PC use, load these older saves in the game and save them again with this version, then export the new saves. You can also export the original files now as iPad backups." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Export iPad backups" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self shareRows:rows];}]];
        [self presentViewController:alert animated:YES completion:nil];
    } else [self shareRows:rows];
}
- (void)shareRows:(NSArray<NSDictionary *> *)rows {
    NSString *folder=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"SaveExport-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    NSError *error=nil;[[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:&error];
    NSMutableArray *urls=[NSMutableArray array];
    for(NSDictionary *row in rows) {
        NSString *destination=[folder stringByAppendingPathComponent:[row[@"path"] lastPathComponent]];
        if(![[NSFileManager defaultManager] copyItemAtPath:row[@"path"] toPath:destination error:&error])break;
        [urls addObject:[NSURL fileURLWithPath:destination]];
    }
    if(error || !urls.count){[[NSFileManager defaultManager] removeItemAtPath:folder error:nil];[self notify:@"Export failed" message:error.localizedDescription ?: @"No saves selected."];return;}
    UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:urls applicationActivities:nil];
    share.popoverPresentationController.sourceView=self.view;share.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,self.view.bounds.size.height/2,1,1);
    share.completionWithItemsHandler=^(UIActivityType type,BOOL completed,NSArray *items,NSError *error){[[NSFileManager defaultManager] removeItemAtPath:folder error:nil];};
    // UIAlertAction handlers may still be dismissing their warning panel.
    if(self.presentedViewController)[self dismissViewControllerAnimated:YES completion:^{[self presentViewController:share animated:YES completion:nil];}];
    else [self presentViewController:share animated:YES completion:nil];
}
- (void)importSaves {
    UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData] asCopy:YES];
    picker.allowsMultipleSelection=YES;picker.delegate=self;[self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSInteger game=self.gameControl.selectedSegmentIndex;NSString *directory=GXGameSavePath(game);
    self.busy=YES;self.navigationController.modalInPresentation=YES;self.navigationItem.rightBarButtonItem.enabled=NO;self.navigationItem.leftBarButtonItem.enabled=NO;self.gameControl.enabled=NO;self.tableView.userInteractionEnabled=NO;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSUInteger imported=0;NSMutableArray *errors=[NSMutableArray array];
        for(NSURL *url in urls) {
            BOOL access=[url startAccessingSecurityScopedResource];
            try {gxsave::importFile(std::filesystem::path(url.fileSystemRepresentation),std::filesystem::path(directory.fileSystemRepresentation));++imported;}
            catch(const std::exception &error){[errors addObject:[NSString stringWithFormat:@"%@: %s",url.lastPathComponent,error.what()]];}
            if(access)[url stopAccessingSecurityScopedResource];
        }
        dispatch_async(dispatch_get_main_queue(),^{
            self.busy=NO;self.navigationController.modalInPresentation=NO;self.navigationItem.rightBarButtonItem.enabled=YES;self.navigationItem.leftBarButtonItem.enabled=YES;self.gameControl.enabled=YES;self.tableView.userInteractionEnabled=YES;[self reloadSaves];
            NSString *message=[NSString stringWithFormat:@"Imported %lu save file(s). Existing saves were kept.",(unsigned long)imported];
            if(errors.count)message=[message stringByAppendingFormat:@"\n\n%@",[errors componentsJoinedByString:@"\n"]];
            [self notify:@"Import complete" message:message];
        });
    });
}
@end

void GXVerifySaveTransfer(void) {
    if(!getenv("GX_RUN_SAVE_TRANSFER_QA"))return;
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    NSString *scratch=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"SaveTransferQA-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    try {
        std::filesystem::path source;uintmax_t largest=0;
        for(const auto &entry:std::filesystem::directory_iterator(GXGameSavePath(0).fileSystemRepresentation)) {
            if(entry.path().extension()==".sav" && entry.file_size()>largest){source=entry.path();largest=entry.file_size();}
        }
        if(source.empty())throw std::runtime_error("No source save for QA");
        auto directory=std::filesystem::path(scratch.fileSystemRepresentation);std::filesystem::create_directories(directory);
        std::ofstream(directory/"00000000.SAV")<<"reserved";
        auto a=gxsave::importFile(source,directory),b=gxsave::importFile(source,directory);
        if(a.filename()!="00000001.sav" || b.filename()!="00000002.sav")throw std::runtime_error("Collision check failed");
        NSData *original=[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:source.c_str()]];
        for(const auto &copy:{a,b})if(![original isEqualToData:[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:copy.c_str()]]])throw std::runtime_error("Imported bytes differ");
        NSString *exported=[scratch stringByAppendingPathComponent:@"export.sav"];NSError *error=nil;
        if(![[NSFileManager defaultManager] copyItemAtPath:[NSString stringWithUTF8String:a.c_str()] toPath:exported error:&error] || ![original isEqualToData:[NSData dataWithContentsOfFile:exported]])throw std::runtime_error("Export copy differs");
        result[@"passed"]=@YES;result[@"sourceBytes"]=@(largest);result[@"imports"]=@2;
    } catch(const std::exception &error) {result[@"passed"]=@NO;result[@"error"]=[NSString stringWithUTF8String:error.what()];}
    [[NSFileManager defaultManager] removeItemAtPath:scratch error:nil];
    NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/SaveTransferQA.json"];
    [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
}
