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

@interface PKPlugInCore : NSObject
@property(retain, nonatomic) NSDictionary *attributes;
@property(retain, nonatomic) NSDictionary *plugInDictionary;
@end

@interface PKDPlugIn : PKPlugInCore
- (NSMutableSet *)allowedTCCServices;
@end

extern CFStringRef *kTCCServiceKeyboardNetwork;
extern CFStringRef *kTCCInfoGranted;
extern "C" CFArrayRef TCCAccessCopyInformationForBundle(CFBundleRef);

BOOL isKeyboardExtension(NSBundle *bundle)
{
	id val = bundle.infoDictionary[@"NSExtension"][@"NSExtensionPointIdentifier"];
	return val ? [val isEqualToString:@"com.apple.keyboard-service"] : NO;
}

extern "C" BOOL currentKeyboardIsThirdParty()
{
	return [UIKeyboardInputModeController.sharedInputModeController.currentInputMode isExtensionInputMode];
}

extern "C" BOOL hasFixedDigitsPasscode()
{
	BOOL value = NO;
	SBLockScreenManager *manager = (SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance];
	if (manager) {
		SBLockScreenViewController *lockScreenViewController = [manager lockScreenViewController];
		SBLockScreenView *lockScreenView = [lockScreenViewController lockScreenView];
		if ([lockScreenView isKindOfClass:%c(SBLockScreenView)]) {
			SBUIPasscodeLockView *view = MSHookIvar<SBUIPasscodeLockView *>(lockScreenView, "_passcodeView");
			if ([view isKindOfClass:%c(SBUIPasscodeLockViewWithKeyPad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewSimple4DigitKeypad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewSimpleFixedDigitKeypad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewLongNumericKeypad)]) {
				SBUINumericPasscodeEntryFieldBase *field = (SBUINumericPasscodeEntryFieldBase *)[(SBUIPasscodeLockViewWithKeyPad *)view _entryField];
				if ([field isKindOfClass:%c(SBUINumericPasscodeEntryFieldBase)])
					value = [field _hasMaxDigitsSpecified];
			}
		}
	}
	return value;
}

extern "C" void enableCustomKeyboardIfNecessary(UIPeripheralHost *self)
{
	SBLockScreenManager *manager = (SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance];
	if (manager) {
		SBLockScreenViewController *lockScreenViewController = [manager lockScreenViewController];
		SBLockScreenView *lockScreenView = [lockScreenViewController lockScreenView];
		if ([lockScreenView isKindOfClass:%c(SBLockScreenView)]) {
			SBUIPasscodeLockView *view = MSHookIvar<SBUIPasscodeLockView *>(lockScreenView, "_passcodeView");
			if ([view isKindOfClass:%c(SBUIPasscodeLockViewWithKeyPad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewSimple4DigitKeypad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewSimpleFixedDigitKeypad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewLongNumericKeypad)]) {
				SBUINumericPasscodeEntryFieldBase *field = (SBUINumericPasscodeEntryFieldBase *)[(SBUIPasscodeLockViewWithKeyPad *)view _entryField];
				if ([field isKindOfClass:%c(SBUINumericPasscodeEntryFieldBase)]) {
					BOOL enabled = ![field _hasMaxDigitsSpecified];
					self.automaticAppearanceEnabled = enabled;;
				}
			} else
				self.automaticAppearanceEnabled = YES;
		}
	}
}

BOOL enabled;
BOOL noFullAccess;
BOOL noPrivate;
BOOL allowLS;

%hook UIKeyboardLayoutDictation

- (void)showKeyboardWithInputTraits:(id)inputTraits screenTraits:(id)screenTraits splitTraits:(id)splitTraits
{
	%orig;
	if (allowLS)
		UIPeripheralHost.sharedInstance.automaticAppearanceEnabled = !hasFixedDigitsPasscode();
}

%end

%hook UIPeripheralHost

- (UIInputViewSet *)_inputViewsForResponder:(UIResponder *)responder withAutomaticKeyboard:(id)keyboard
{
	if (allowLS)
		enableCustomKeyboardIfNecessary(self);
	return %orig;
}

- (void)_reloadInputViewsForResponder:(UIResponder *)responder
{
	if (allowLS)
		enableCustomKeyboardIfNecessary(self);
	%orig;
}

- (void)setInputViews:(id)inputViews animationStyle:(UIInputViewAnimationStyle *)style
{
	if (!allowLS) {
		%orig;
		return;
	}
	if (!style.force) {
		BOOL wasNo = !self.automaticAppearanceEnabled;
		enableCustomKeyboardIfNecessary(self);
		style.force = YES;
		%orig;
		style.force = NO;
		if (wasNo)
			self.automaticAppearanceEnabled = NO;
	} else
		%orig;
}

%end

%hook UIKeyboardImpl

- (void)insertText:(id)text
{
	%orig;
	if (text && currentKeyboardIsThirdParty()) {
		if (self.changedDelegate == nil) {
			[self setChanged];
			[self callChanged];
			self.changedDelegate = nil;
		}
	}
}

%end

%group pkd

%hook PKPlugInCore

- (NSDictionary *)attributes
{
	NSDictionary *attrs = %orig;
	if (enabled && noFullAccess && [self.plugInDictionary[@"NSExtensionPointIdentifier"] isEqualToString:@"com.apple.keyboard-service"]) {
		NSMutableDictionary *m_attrs = [NSMutableDictionary dictionary];
		[m_attrs addEntriesFromDictionary:attrs];
		m_attrs[@"RequestsOpenAccess"] = @0;
		return m_attrs;
	}
	return attrs;
}

%end

%hook PKDPlugIn

- (NSMutableSet *)allowedTCCServices
{
	NSMutableSet *set = %orig;
	if (enabled && noFullAccess && [self.plugInDictionary[@"NSExtensionPointIdentifier"] isEqualToString:@"com.apple.keyboard-service"])
		[set removeObject:(NSString *)kTCCServiceKeyboardNetwork];
	return set;
}

%end

%end

%hook UIKeyboardExtensionInputMode

%group preiOS9

- (BOOL)isAllowedForTraits:(UITextInputTraits *)traits
{
	BOOL secure = traits.secureTextEntry;
	BOOL value = secure ? !noPrivate : YES;
	return value;
}

- (BOOL)isDesiredForTraits:(UITextInputTraits *)traits forceASCIICapable:(BOOL)forceASCII
{
	BOOL secure = traits.secureTextEntry;
	BOOL value = secure ? !noPrivate : YES;
	return value;
}

%end

%group iOS9

- (BOOL)isDesiredForTraits:(UITextInputTraits *)traits
{
	BOOL secure = traits.secureTextEntry;
	BOOL value = secure ? !noPrivate : YES;
	return value;
}

%end

%end

%group SpringBoard

%hook SBUIPasscodeTextField

- (void)reloadInputViews
{
	if (allowLS) {
		if (hasFixedDigitsPasscode())
			return;
	}
	%orig;
}

%end

%hook SBUIPasscodeLockViewWithKeyboard

- (CGRect)_keyboardFrameForInterfaceOrientation:(NSInteger)orientation
{
	CGRect oldFrame = %orig;
	BOOL external = currentKeyboardIsThirdParty();
	if (allowLS) {
		SBPasscodeKeyboard *keyboard = MSHookIvar<SBPasscodeKeyboard *>(self, "_keyboard");
		keyboard.hidden = external;
	}
	if (external && allowLS) {
		CGFloat shift = 50.0f;
		CGRect newFrame = CGRectMake(oldFrame.origin.x, oldFrame.origin.y - shift, oldFrame.size.width, oldFrame.size.height + shift);
		return newFrame;
	}
	return oldFrame;
}

%end

%end

%group tccd

%hookf(CFArrayRef, TCCAccessCopyInformationForBundle, CFBundleRef bundle)
{
	CFArrayRef info = %orig(bundle);
	//CFStringRef bundleIdentifier = CFBundleGetIdentifier(bundle);
	if (noFullAccess) {
		NSBundle *nsBundle = (NSBundle *)bundle;
		if (enabled && isKeyboardExtension(nsBundle)) {
			NSLog(@"%@", info);
			return (CFArrayRef)@[];
		}
	}
	return info;
}

%end

BOOL (*my_allowed_in_secure_update)(void *, void *);
BOOL (*orig_allowed_in_secure_update)(void *, void *);
BOOL hax_allowed_in_secure_update(void *arg1, void *arg2)
{
	return YES;
}

CFStringRef PreferencesNotification = CFSTR("com.PS.exKeyboard.prefs");

static void letsprefs()
{
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.PS.exKeyboard.plist"];
	id object = [prefs objectForKey:@"enabled"];
	enabled = object ? [object boolValue] : YES;
	object = [prefs objectForKey:@"noFullAccess"];
	noFullAccess = object ? [object boolValue] : YES;
	object = [prefs objectForKey:@"noPrivate"];
	noPrivate = object ? [object boolValue] : YES;
	object = [prefs objectForKey:@"allowLS"];
	allowLS = [object boolValue];
}

static void prefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	letsprefs();
}

%ctor
{
	NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
	NSUInteger count = args.count;
	if (count != 0) {
		NSString *executablePath = args[0];
		if (executablePath) {
			NSString *processName = [executablePath lastPathComponent];
			BOOL isSpringBoard = [processName isEqualToString:@"SpringBoard"];
			BOOL isExtensionOrApp = [executablePath rangeOfString:@"/Application"].location != NSNotFound;
			BOOL isExtension = [executablePath rangeOfString:@"appex"].location != NSNotFound;
			BOOL isbackboardd = [processName isEqualToString:@"backboardd"];
			BOOL ispkd = [processName isEqualToString:@"pkd"];
			BOOL istccd = [processName isEqualToString:@"tccd"];
			if (!isExtension && !isKeyboardExtension(NSBundle.mainBundle))
				CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &prefsChanged, PreferencesNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
			if (isExtensionOrApp || isSpringBoard) {
				letsprefs();
				if (!enabled)
					return;
				if (isiOS9Up) {
					%init(iOS9);
				} else {
					%init(preiOS9);
				}
				%init;
			}
			else if (ispkd) {
				%init(pkd);
			}
			else if (istccd) {
				%init(tccd);
			}
			else if (isSpringBoard) {
				%init(SpringBoard);
			}
			else if (isbackboardd) {
				const char *qc = "/System/Library/Frameworks/QuartzCore.framework/QuartzCore";
				MSImageRef qcRef = MSGetImageByName(qc);
				my_allowed_in_secure_update = (BOOL (*)(void *, void *))MSFindSymbol(qcRef, "__ZN2CA6Render6Update24allowed_in_secure_updateEPNS0_7ContextEPKNS0_9LayerHostE");
				MSHookFunction((void *)my_allowed_in_secure_update, (void *)hax_allowed_in_secure_update, (void **)&orig_allowed_in_secure_update);
			}
		}
	}
}
