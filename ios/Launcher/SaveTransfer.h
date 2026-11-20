// GeneralsX @feature Codex 20/11/2026 Launcher save management.
#import <UIKit/UIKit.h>
@interface GXSaveTransferController : UITableViewController
@end

// Explicit device QA; works only in a temporary directory, never imports into live saves.
void GXVerifySaveTransfer(void);
