#import <UIKit/UIKit.h>
#import "../PS.h"

//#include "InspCWrapper.m"

@interface UIInputViewAnimationStyle : NSObject
@property BOOL force;
@end

@interface UIKeyboardImpl : NSObject
@property(retain, nonatomic) id changedDelegate;
- (void)setChanged;
- (void)callChanged;
@end

@interface UIKeyboardInputMode : NSObject
+ (UIKeyboardInputMode *)keyboardInputModeWithIdentifier:(NSString *)identifier;
@property(nonatomic, assign) NSString *normalizedIdentifier;
@property(nonatomic, assign) NSString *primaryLanguage;
- (BOOL)isExtensionInputMode;
- (BOOL)defaultLayoutIsASCIICapable;
@end

@interface UIKeyboardInputModeController : NSObject
+ (UIKeyboardInputModeController *)sharedInputModeController;
@property(atomic, strong, readwrite) NSArray *normalizedInputModes;
- (NSArray *)extensionInputModes;
- (NSArray *)allowedExtensions;
- (UIKeyboardInputMode *)currentInputMode;
@end

@interface UICompatibilityInputViewController : NSObject
@property(retain, nonatomic) UIKeyboardInputMode *inputMode;
@end

@interface UIInputViewController (Addition)
- (UICompatibilityInputViewController *)_compatibilityController;
@end

@interface UIInputViewSet : NSObject
- (UIInputViewController *)inputViewController;
@end

@interface UIKeyboardExtensionInputMode : UIKeyboardInputMode
@end

@interface UITextInputTraits : NSObject
@property(nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
@property(nonatomic) UIKeyboardAppearance keyboardAppearance;
@property(nonatomic) NSInteger keyboardType;
+ (BOOL)keyboardTypeRequiresASCIICapable:(NSInteger)keyboardType;
@end

@interface UIPeripheralHost : NSObject
+ (UIPeripheralHost *)sharedInstance;
@property(nonatomic) BOOL automaticAppearanceEnabled;
- (void)_setReloadInputViewsForcedIsAllowed:(BOOL)allowed;
- (BOOL)automaticAppearanceReallyEnabled;
- (UIInputViewSet *)inputViews;
@end

@interface UIKeyboard : UIView
@end

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

@interface PSSystemPolicyForApp : NSObject
@property(copy) NSString *bundleIdentifier;
@end

@interface NSExtension : NSObject
@property(copy) NSString *identifier;
- (NSBundle *)_extensionBundle;
@end

BOOL (*UIKeyboardLayoutDefaultTypeForInputModeIsSecure)(NSString *);
BOOL (*UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapable)(NSString *);
BOOL (*UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapableExtended)(NSString *);

extern "C" BOOL currentKeyboardIsThirdParty()
{
	return [UIKeyboardInputModeController.sharedInputModeController.currentInputMode isExtensionInputMode];
}

extern "C" BOOL has4DigitsPasscode()
{
	BOOL value = NO;
	SBLockScreenManager *manager = (SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance];
	if (manager) {
		SBLockScreenViewController *lockScreenViewController = [manager lockScreenViewController];
		SBLockScreenView *lockScreenView = [lockScreenViewController lockScreenView];
		if ([lockScreenView isKindOfClass:%c(SBLockScreenView)]) {
			SBUIPasscodeLockView *view = MSHookIvar<SBUIPasscodeLockView *>(lockScreenView, "_passcodeView");
			if ([view isKindOfClass:%c(SBUIPasscodeLockViewWithKeyPad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewSimple4DigitKeypad)]) {
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
			if ([view isKindOfClass:%c(SBUIPasscodeLockViewWithKeyPad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewSimple4DigitKeypad)]) {
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
		UIPeripheralHost.sharedInstance.automaticAppearanceEnabled = !has4DigitsPasscode();
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

extern CFStringRef *kTCCServiceKeyboardNetwork;
extern CFStringRef *kTCCInfoGranted;
extern "C" CFArrayRef TCCAccessCopyInformationForBundle(CFBundleRef);

MSHook(CFArrayRef, TCCAccessCopyInformationForBundle, CFBundleRef bundle)
{
	CFArrayRef info = _TCCAccessCopyInformationForBundle(bundle);
	CFStringRef bundleIdentifier = CFBundleGetIdentifier(bundle);
	if (noFullAccess) {
		NSArray *extensions = [[UIKeyboardInputModeController sharedInputModeController] allowedExtensions];
		BOOL enabled = NO;
		for (NSExtension *extension in extensions) {
			if ([extension isKindOfClass:[NSExtension class]]) {
				NSBundle *keyboardBundle = [extension _extensionBundle];
				if (keyboardBundle) {
					NSString *extensionIdentifier = keyboardBundle.bundleIdentifier;
					if ([extensionIdentifier hasPrefix:(NSString *)bundleIdentifier]) {
						enabled = YES;
						break;
					}
				}
			}
		}
		if (enabled) {
			/*NSLog(@"%@", info);
			NSMutableArray *newInfo = [NSMutableArray arrayWithArray:(NSArray *)info];
			NSMutableDictionary *service = [NSMutableDictionary dictionary];
			[service addEntriesFromDictionary:newInfo[0]];
			service[(NSString *)kTCCInfoGranted] = @NO;
			newInfo[0] = service;
			NSLog(@"%@", newInfo);*/
			return (CFArrayRef)@[];
		}
	}
	return info;
}

/*%hook PSSystemPolicyForApp

- (id)_privacyAccessForService:(CFStringRef)service
{
	if (noFullAccess && [UIKeyboardInputModeController.sharedInputModeController.normalizedInputModes containsObject:self.bundleIdentifier])
		return @0;
	return %orig;
}

- (id)privacyAccessForSpecifier:(id)specifier
{
	if (noFullAccess && [UIKeyboardInputModeController.sharedInputModeController.normalizedInputModes containsObject:self.bundleIdentifier])
		return @0;
	return %orig;
}

%end*/

%hook UIKeyboardExtensionInputMode

%group preiOS9

- (BOOL)isAllowedForTraits:(UITextInputTraits *)traits
{
	NSString *identifier = self.normalizedIdentifier;
	BOOL secure = !noPrivate && traits.secureTextEntry;
	BOOL value = YES;
	if (secure) {
		BOOL secure2 = UIKeyboardLayoutDefaultTypeForInputModeIsSecure(identifier);
		if (secure2) {
			if (traits.keyboardType == 1)
				value = UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapableExtended(identifier);
		} else
			value = NO;
	} else {
		if (traits.keyboardType == 1)
			value = UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapableExtended(identifier);
	}
	return value;
}

- (BOOL)isDesiredForTraits:(UITextInputTraits *)traits forceASCIICapable:(BOOL)forceASCII
{
	NSString *identifier = self.normalizedIdentifier;
	BOOL secure = !noPrivate && traits.secureTextEntry;
	BOOL value = NO;
	if (secure)
		value = UIKeyboardLayoutDefaultTypeForInputModeIsSecure(identifier);
	else {
		if (forceASCII)
			value = UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapable(identifier);
		else {
			BOOL requiresASCII = [%c(UITextInputTraits) keyboardTypeRequiresASCIICapable:traits.keyboardType];
			value = YES;
			if (requiresASCII)
				value = UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapableExtended(identifier);
		}
	}
	return value;
}

%end

%group iOS9

- (BOOL)isDesiredForTraits:(UITextInputTraits *)traits
{
	NSString *identifier = self.normalizedIdentifier;
	BOOL secure = !noPrivate && traits.secureTextEntry;
	BOOL value = NO;
	if (secure)
		value = UIKeyboardLayoutDefaultTypeForInputModeIsSecure(identifier);
	else {
		if (![self defaultLayoutIsASCIICapable])
			value = [self.primaryLanguage hasPrefix:@"ko"];
		else {
			BOOL requiresASCII = [%c(UITextInputTraits) keyboardTypeRequiresASCIICapable:traits.keyboardType];
			value = YES;
			if (requiresASCII)
				value = UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapableExtended(identifier);
		}
	}
	return value;
}

%end

%end

%group SpringBoard

%hook SBUIPasscodeTextField

- (void)reloadInputViews
{
	if (allowLS) {
		if (has4DigitsPasscode())
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
			if (isExtensionOrApp || isSpringBoard) {
				letsprefs();
				if (!enabled)
					return;
				if (!isExtension) {
					CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &prefsChanged, PreferencesNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
					MSImageRef UIKIT = MSGetImageByName("/System/Library/Frameworks/UIKit.framework/UIKit");
					UIKeyboardLayoutDefaultTypeForInputModeIsSecure = (BOOL (*)(NSString *))MSFindSymbol(UIKIT, "_UIKeyboardLayoutDefaultTypeForInputModeIsSecure");
					UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapable = (BOOL (*)(NSString *))MSFindSymbol(UIKIT, "_UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapable");
					UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapableExtended = (BOOL (*)(NSString *))MSFindSymbol(UIKIT, "_UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapableExtended");
				}
				MSHookFunction(TCCAccessCopyInformationForBundle, MSHake(TCCAccessCopyInformationForBundle));
				if (isiOS9Up) {
					%init(iOS9);
				} else {
					%init(preiOS9);
				}
				%init;
			}
			if (isSpringBoard) {
				%init(SpringBoard);
				//watchClass(%c(UIInputSetHostView));
			}
			if (isbackboardd) {
				const char *qc = "/System/Library/Frameworks/QuartzCore.framework/QuartzCore";
				MSImageRef qcRef = MSGetImageByName(qc);
				my_allowed_in_secure_update = (BOOL (*)(void *, void *))MSFindSymbol(qcRef, "__ZN2CA6Render6Update24allowed_in_secure_updateEPNS0_7ContextEPKNS0_9LayerHostE");
				MSHookFunction((void *)my_allowed_in_secure_update, (void *)hax_allowed_in_secure_update, (void **)&orig_allowed_in_secure_update);
			}
		}
	}
}
