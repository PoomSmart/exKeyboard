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

@interface SBUIKeyboardEnablementManager : NSObject
+ (instancetype)sharedInstance;
- (void)enableAutomaticAppearanceForContext:(id)arg1;
- (void)disableAutomaticAppearanceForContext:(id)arg1;
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
