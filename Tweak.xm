#import <UIKit/UIKit.h>

//#include "InspCWrapper.m"

@interface UIKeyboardImpl : NSObject
@property(retain, nonatomic) id changedDelegate;
- (void)setChanged;
- (void)callChanged;
@end

@interface UIKeyboardInputMode : NSObject
@property(nonatomic, assign) NSString *normalizedIdentifier;
- (BOOL)isExtensionInputMode;
@end

@interface UIKeyboardInputModeController : NSObject
+ (UIKeyboardInputModeController *)sharedInputModeController;
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
- (BOOL)automaticAppearanceReallyEnabled;
- (UIInputViewSet *)inputViews;
@end

//BOOL (*UIKeyboardLayoutDefaultTypeForInputModeIsSecure)(NSString *);
BOOL (*UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapable)(NSString *);
BOOL (*UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapableExtended)(NSString *);

static BOOL currentKeyboardIsThirdParty()
{
	return [UIKeyboardInputModeController.sharedInputModeController.currentInputMode isExtensionInputMode];
}

%hook UIKeyboardLayoutDictation

- (void)showKeyboardWithInputTraits:(id)inputTraits screenTraits:(id)screenTraits splitTraits:(id)splitTraits
{
	%orig;
	UIPeripheralHost.sharedInstance.automaticAppearanceEnabled = YES;
}

%end

%hook UIPeripheralHost

- (UIInputViewSet *)_inputViewsForResponder:(UIResponder *)responder withAutomaticKeyboard:(id)keyboard
{
	self.automaticAppearanceEnabled = YES;
	return %orig;
}

- (void)_reloadInputViewsForResponder:(UIResponder *)responder
{
	self.automaticAppearanceEnabled = YES;
	%orig;
}

- (BOOL)animationsEnabled
{
	if (MSHookIvar<BOOL>(self, "_springBoardLockStateIsLocked")) {
		MSHookIvar<BOOL>(self, "_springBoardLockStateIsLocked") = NO;
		BOOL orig = %orig;
		MSHookIvar<BOOL>(self, "_springBoardLockStateIsLocked") = YES;
		return orig;
	}
	return %orig;
}

%end

%hook UIKeyboardImpl

- (void)setKeyboardInputMode:(id)inputMode userInitiated:(BOOL)user updateIndicator:(BOOL)ind executionContext:(id)context
{
	%orig;
	if (MSHookIvar<id>(self, "m_delegate") == nil)
		[[UIPeripheralHost sharedInstance].inputViews.inputViewController._compatibilityController setInputMode:[UIKeyboardInputModeController sharedInputModeController].currentInputMode];
}

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

%hook UIKeyboardExtensionInputMode

/*- (BOOL)isDesiredForTraits:(UITextInputTraits *)traits forceASCIICapable:(BOOL)forceASCII
{
	unlock = YES;
	BOOL secure = traits.secureTextEntry;
	UIKeyboardAppearance originalKeyboardAppearance = traits.keyboardAppearance;
	BOOL notLight = originalKeyboardAppearance != UIKeyboardAppearanceLight;
	if (secure)
		MSHookIvar<BOOL>(traits, "secureTextEntry") = NO;
	if (notLight)
		traits.keyboardAppearance = UIKeyboardAppearanceLight;
	BOOL orig = %orig;
	if (secure)	
		MSHookIvar<BOOL>(traits, "secureTextEntry") = YES;
	if (notLight)
		traits.keyboardAppearance = originalKeyboardAppearance;
	unlock = NO;
	return orig;
}*/

- (BOOL)isAllowedForTraits:(UITextInputTraits *)traits
{
	NSString *identifier = self.normalizedIdentifier;
	//BOOL secure = traits.secureTextEntry;
	BOOL value = YES;
	/*if (secure) {
		BOOL secure2 = UIKeyboardLayoutDefaultTypeForInputModeIsSecure(identifier);
		if (secure2) {
			if (traits.keyboardType == 1)
				value = UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapableExtended(identifier);
		} else
			value = NO;
	} else {*/
		if (traits.keyboardType == 1)
			value = UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapableExtended(identifier);
	//}
	return value;
}

- (BOOL)isDesiredForTraits:(UITextInputTraits *)traits forceASCIICapable:(BOOL)forceASCII
{
	NSString *identifier = self.normalizedIdentifier;
	//BOOL secure = traits.secureTextEntry;
	BOOL value = NO;
	/*if (secure) {
		value = UIKeyboardLayoutDefaultTypeForInputModeIsSecure(identifier);
	} else {*/
		if (forceASCII)
			value = UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapable(identifier);
		else {
			BOOL requiresASCII = [%c(UITextInputTraits) keyboardTypeRequiresASCIICapable:traits.keyboardType];
			value = YES;
			if (requiresASCII)
				value = UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapableExtended(identifier);
		}
	//}
	return value;
}

%end

%group SpringBoard

%hook SBUIPasscodeLockViewWithKeyboard

- (CGRect)_keyboardFrameForInterfaceOrientation:(NSInteger)orientation
{
	CGRect oldFrame = %orig;
	if (currentKeyboardIsThirdParty()) {
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
			BOOL isbackboardd = [processName isEqualToString:@"backboardd"];
			if (isExtensionOrApp || isSpringBoard) {
				MSImageRef UIKIT = MSGetImageByName("/System/Library/Frameworks/UIKit.framework/UIKit");
				//UIKeyboardLayoutDefaultTypeForInputModeIsSecure = (BOOL (*)(NSString *))MSFindSymbol(UIKIT, "_UIKeyboardLayoutDefaultTypeForInputModeIsSecure");
				UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapable = (BOOL (*)(NSString *))MSFindSymbol(UIKIT, "_UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapable");
				UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapableExtended = (BOOL (*)(NSString *))MSFindSymbol(UIKIT, "_UIKeyboardLayoutDefaultTypeForInputModeIsASCIICapableExtended");
				%init;
			}
			if (isSpringBoard) {
				%init(SpringBoard);
			}
			if (isbackboardd) {
				const char *qc = "/System/Library/Frameworks/QuartzCore.framework/QuartzCore";
				dlopen(qc, RTLD_LAZY);
				MSImageRef qcRef = MSGetImageByName(qc);		
				my_allowed_in_secure_update = (BOOL (*)(void *, void *))MSFindSymbol(qcRef, "__ZN2CA6Render6Update24allowed_in_secure_updateEPNS0_7ContextEPKNS0_9LayerHostE");
				MSHookFunction((void *)my_allowed_in_secure_update, (void *)hax_allowed_in_secure_update, (void **)&orig_allowed_in_secure_update);
			}
		}
	}
}
