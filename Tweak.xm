#import "Header.h"

extern CFStringRef *kTCCServiceKeyboardNetwork;
extern CFStringRef *kTCCInfoGranted;
extern "C" CFArrayRef TCCAccessCopyInformationForBundle(CFBundleRef);

BOOL isKeyboardExtension(NSBundle *bundle){
    id val = bundle.infoDictionary[@"NSExtension"][@"NSExtensionPointIdentifier"];
    return val ? [val isEqualToString:@"com.apple.keyboard-service"] : NO;
}

extern "C" BOOL currentKeyboardIsThirdParty(){
    return [UIKeyboardInputModeController.sharedInputModeController.currentInputMode isExtensionInputMode];
}

extern "C" BOOL hasFixedDigitsPasscode(){
    BOOL value = NO;
    SBLockScreenManager *manager = (SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance];
    if (manager) {
        SBLockScreenViewController *lockScreenViewController = [manager lockScreenViewController];
        SBLockScreenView *lockScreenView = [lockScreenViewController lockScreenView];
        if ([lockScreenView isKindOfClass:%c(SBLockScreenView)]) {
            SBUIPasscodeLockView *view = MSHookIvar<SBUIPasscodeLockView *>(lockScreenView, "_passcodeView");
            if ([view isKindOfClass:%c(SBUIPasscodeLockViewWithKeyPad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewSimple4DigitKeypad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewSimpleFixedDigitKeypad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewLongNumericKeypad)]) {
                SBUINumericPasscodeEntryFieldBase *field = (SBUINumericPasscodeEntryFieldBase *)[(SBUIPasscodeLockViewWithKeyPad *) view _entryField];
                if ([field isKindOfClass:%c(SBUINumericPasscodeEntryFieldBase)])
                    value = [field _hasMaxDigitsSpecified];
            }
        }
    }
    return value;
}

extern "C" void enableCustomKeyboardIfNecessary(UIPeripheralHost *self){
    if (UIApplication.sharedApplication == nil)
        return;
    SBLockScreenManager *manager = (SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance];
    if (manager) {
        SBLockScreenViewController *lockScreenViewController = [manager lockScreenViewController];
        if (![lockScreenViewController respondsToSelector:@selector(lockScreenView)]) // because it is dashboard (iOS 10) (correct?)
            return;
        SBLockScreenView *lockScreenView = [lockScreenViewController lockScreenView];
        if ([lockScreenView isKindOfClass:%c(SBLockScreenView)]) {
            SBUIPasscodeLockView *view = MSHookIvar<SBUIPasscodeLockView *>(lockScreenView, "_passcodeView");
            if ([view isKindOfClass:%c(SBUIPasscodeLockViewWithKeyPad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewSimple4DigitKeypad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewSimpleFixedDigitKeypad)] || [view isKindOfClass:%c(SBUIPasscodeLockViewLongNumericKeypad)]) {
                SBUINumericPasscodeEntryFieldBase *field = (SBUINumericPasscodeEntryFieldBase *)[(SBUIPasscodeLockViewWithKeyPad *) view _entryField];
                if ([field isKindOfClass:%c(SBUINumericPasscodeEntryFieldBase)])
                    self.automaticAppearanceEnabled = ![field _hasMaxDigitsSpecified];
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

- (void)showKeyboardWithInputTraits: (id)inputTraits screenTraits: (id)screenTraits splitTraits: (id)splitTraits
{
    %orig;
    if (allowLS)
        UIPeripheralHost.sharedInstance.automaticAppearanceEnabled = !hasFixedDigitsPasscode();
}

%end

%hook UIPeripheralHost

- (UIInputViewSet *)_inputViewsForResponder: (UIResponder *)responder withAutomaticKeyboard: (BOOL)keyboard
{
    return %orig(responder, allowLS ? NO : keyboard);
}

- (void)setInputViews:(id)inputViews animationStyle:(UIInputViewAnimationStyle *)style {
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

- (void)insertText: (id)text
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

- (BOOL)isAllowedForTraits: (UITextInputTraits *)traits
{
    return traits.secureTextEntry ? !noPrivate : YES;
}

- (BOOL)isDesiredForTraits:(UITextInputTraits *)traits forceASCIICapable:(BOOL)forceASCII {
    return traits.secureTextEntry ? !noPrivate : YES;
}

%end

%group iOS9Up

- (BOOL)isDesiredForTraits: (UITextInputTraits *)traits
{
    return traits.secureTextEntry ? !noPrivate : YES;
}

%end

%end

%group iOS10Up

BOOL haxAllowExtensions = NO;
BOOL haxAllowExtensions2 = NO;
BOOL haxAllowExtensions3 = NO;

%hook UITextInputTraits

- (BOOL)isSecureTextEntry
{
    return haxAllowExtensions ? NO : %orig;
}

%end

%hook UIKeyboardImpl

- (void)setDelegate: (id)delegate force: (BOOL)force
{
    haxAllowExtensions = !noPrivate;
    %orig;
    haxAllowExtensions = NO;
}

- (NSMutableArray *)desirableInputModesWithExtensions:(BOOL)extensions {
    return %orig(!noPrivate && !extensions ? YES : extensions);
}

%end

%hook UIKeyboardExtensionInputMode

- (BOOL)isExtensionInputMode
{
    return haxAllowExtensions3 ? NO : %orig;
}

%end

%hook UIKeyboardInputModeController

- (BOOL)isLockscreenPasscodeKeyboard
{
    BOOL orig = %orig;
    return haxAllowExtensions2 && orig ? noPrivate : orig;
}

- (NSMutableArray *)extensionInputModes {
    haxAllowExtensions2 = allowLS;
    NSMutableArray *orig = %orig;
    haxAllowExtensions2 = NO;
    return orig;
}

- (NSMutableArray *)enabledInputModeIdentifiers:(BOOL)arg1 {
    haxAllowExtensions2 = allowLS;
    NSMutableArray *orig = %orig;
    haxAllowExtensions2 = NO;
    return orig;
}

- (UIKeyboardInputMode *)currentSystemInputMode {
    haxAllowExtensions3 = YES;
    UIKeyboardInputMode *orig = %orig;
    haxAllowExtensions3 = NO;
    return orig;
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

- (CGRect)_keyboardFrameForInterfaceOrientation: (NSInteger)orientation
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

MSHook(CFArrayRef, TCCAccessCopyInformationForBundle, CFBundleRef bundle){
    CFArrayRef info = _TCCAccessCopyInformationForBundle(bundle);
    //CFStringRef bundleIdentifier = CFBundleGetIdentifier(bundle);
    if (noFullAccess) {
        NSBundle *nsBundle = (NSBundle *)bundle;
        if (enabled && isKeyboardExtension(nsBundle))
            return (CFArrayRef) @[];
    }
    return info;
}

%end

BOOL (*my_allowed_in_secure_update)(void *, void *);
BOOL (*orig_allowed_in_secure_update)(void *, void *);
BOOL hax_allowed_in_secure_update(void *arg1, void *arg2){
    return YES;
}

CFStringRef PreferencesNotification = CFSTR("com.PS.exKeyboard.prefs");

static void letsprefs(){
    #ifdef SIMULATOR
    enabled = allowLS = YES;
    noPrivate = noFullAccess = NO;
    #else
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.PS.exKeyboard.plist"];
    id object = [prefs objectForKey:@"enabled"];
    enabled = object ? [object boolValue] : YES;
    object = [prefs objectForKey:@"noFullAccess"];
    noFullAccess = object ? [object boolValue] : YES;
    object = [prefs objectForKey:@"noPrivate"];
    noPrivate = object ? [object boolValue] : YES;
    object = [prefs objectForKey:@"allowLS"];
    allowLS = [object boolValue];
    #endif
}

static void prefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo){
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
                    if (isiOS10Up) {
                        %init(iOS10Up);
                    }
                    %init(iOS9Up);
                } else {
                    %init(preiOS9);
                }
                %init;
            } else if (ispkd) {
                %init(pkd);
            } else if (istccd) {
                %init(tccd);
                MSHookFunction(TCCAccessCopyInformationForBundle, MSHake(TCCAccessCopyInformationForBundle));
            } else if (isSpringBoard) {
                %init(SpringBoard);
            } else if (isbackboardd) {
                const char *qc = "/System/Library/Frameworks/QuartzCore.framework/QuartzCore";
                MSImageRef qcRef = MSGetImageByName(qc);
                my_allowed_in_secure_update = (BOOL (*)(void *, void *))MSFindSymbol(qcRef, "__ZN2CA6Render6Update24allowed_in_secure_updateEPNS0_7ContextEPKNS0_9LayerHostE");
                MSHookFunction((void *)my_allowed_in_secure_update, (void *)hax_allowed_in_secure_update, (void * *)&orig_allowed_in_secure_update);
            }
        }
    }
}
