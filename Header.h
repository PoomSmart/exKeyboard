#import <UIKit/UIKit.h>
#import "../PS.h"

@interface SBPasscodeKeyboard : UIKeyboard
- (void)minimize;
@end

@interface SBUINumericPasscodeEntryFieldBase : NSObject
- (BOOL)_hasMaxDigitsSpecified;
@end

@interface SBUIPasscodeTextField : UITextField
@end

@interface SBUIPasscodeLockView : UIView
@end

@interface SBUIPasscodeLockViewWithKeyPad : SBUIPasscodeLockView
- (SBUINumericPasscodeEntryFieldBase *)_entryField;
@end

@interface SBLockScreenView : UIView
@end

@interface SBLockScreenViewController : UIViewController
- (SBLockScreenView *)lockScreenView;
@end

@interface SBLockScreenManager : NSObject
+ (SBLockScreenManager *)sharedInstance;
- (SBLockScreenViewController *)lockScreenViewController;
@end

@interface SBDashboardModalPresentationViewController : UIViewController
@end

@interface SBDashBoardViewController : UIViewController
- (BOOL)isPasscodeLockVisible;
@end