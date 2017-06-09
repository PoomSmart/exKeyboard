#import "Header.h"

BOOL isKeyboardExtension(NSBundle *bundle) {
    id val = bundle.infoDictionary[@"NSExtension"][@"NSExtensionPointIdentifier"];
    return val ? [val isEqualToString:@"com.apple.keyboard-service"] : NO;
}

BOOL currentKeyboardIsThirdParty() {
    return [UIKeyboardInputModeController.sharedInputModeController.currentInputMode isExtensionInputMode];
}

BOOL enabled;
BOOL noPrivate;
BOOL allowLS;

BOOL haxAllowExtensions = NO;
BOOL haxAllowExtensionsLS = NO;
BOOL haxAllowExtensionsNoSecure = NO;

%hook UITextInputTraits

- (BOOL)isSecureTextEntry {
  return haxAllowExtensionsNoSecure ? NO : %orig;
}

%end

%hook UIKeyboardExtensionInputMode

%group preiOS9

- (BOOL)isDesiredForTraits:(UITextInputTraits *)traits forceASCIICapable:(BOOL)forceASCII {
    if (!enabled)
        return %orig;
    return traits.secureTextEntry ? !noPrivate : YES;
}

%end

%group iOS9Up

- (BOOL)isDesiredForTraits: (UITextInputTraits *)traits {
    if (enabled) {
        if (traits.secureTextEntry && !noPrivate)
            haxAllowExtensionsNoSecure = YES;
        if (allowLS)
            haxAllowExtensionsLS = YES;
        BOOL orig = %orig;
        haxAllowExtensionsNoSecure = NO;
        haxAllowExtensionsLS = NO;
        return orig;
    }
    return %orig;
}

%end

%end

%group iOS10Up

%hook UIKeyboardImpl

- (void)setDelegate: (id)delegate force: (BOOL)force {
    if (enabled && !noPrivate && MSHookIvar<BOOL>(MSHookIvar<UITextInputTraits *>(self, "m_traits"), "secureTextEntry")) {
        MSHookIvar<BOOL>(MSHookIvar<UITextInputTraits *>(self, "m_traits"), "secureTextEntry") = NO;
        %orig;
        MSHookIvar<BOOL>(MSHookIvar<UITextInputTraits *>(self, "m_traits"), "secureTextEntry") = YES;
    } else
        %orig;
}

- (void)recomputeActiveInputModesWithExtensions:(BOOL)extensions {
    %orig(enabled && !noPrivate ? YES : extensions);
}

- (NSMutableArray *)desirableInputModesWithExtensions:(BOOL)extensions {
    if (enabled && !noPrivate && MSHookIvar<BOOL>(MSHookIvar<UITextInputTraits *>(self, "m_traits"), "secureTextEntry")) {
        MSHookIvar<BOOL>(MSHookIvar<UITextInputTraits *>(self, "m_traits"), "secureTextEntry") = NO;
        NSMutableArray *orig = %orig(YES);
        MSHookIvar<BOOL>(MSHookIvar<UITextInputTraits *>(self, "m_traits"), "secureTextEntry") = YES;
        return orig;
    }
    return %orig;
}

- (void)setKeyboardInputMode:(UIKeyboardInputMode *)inputMode userInitiated:(BOOL)userInitiated updateIndicator:(BOOL)updateIndicator executionContext:(id)executionContext {
    haxAllowExtensions = enabled;
    %orig;
    haxAllowExtensions = NO;
}

%end

%hook UIKeyboardExtensionInputMode

- (BOOL)isExtensionInputMode {
    return haxAllowExtensions ? NO : %orig;
}

%end

%hook UIKeyboardInputModeController

- (UIKeyboardInputMode *)currentSystemInputMode {
    haxAllowExtensions = enabled;
    UIKeyboardInputMode *orig = %orig;
    haxAllowExtensions = NO;
    return orig;
}

- (BOOL)deviceStateIsLocked {
  return haxAllowExtensionsLS ? NO : %orig;
}

%end

%end

%group SpringBoard

%hook SBUIPasscodeTextField

- (BOOL)becomeFirstResponder {
    BOOL orig = %orig;
    if (allowLS && !noPrivate)
        [[NSClassFromString(@"SBUIKeyboardEnablementManager") sharedInstance] disableAutomaticAppearanceForContext:self];
    return orig;
}

%end

%hook SBUIPasscodeLockViewWithKeyboard

- (CGRect)_keyboardFrameForInterfaceOrientation: (NSInteger)orientation {
    CGRect oldFrame = %orig;
    BOOL external = currentKeyboardIsThirdParty();
    if (allowLS)
        MSHookIvar<SBPasscodeKeyboard *>(self, "_keyboard").hidden = external;
    if (external && allowLS) {
        CGFloat shift = 50.0f;
        CGRect newFrame = CGRectMake(oldFrame.origin.x, oldFrame.origin.y - shift, oldFrame.size.width, oldFrame.size.height + shift);
        return newFrame;
    }
    return oldFrame;
}

%end

%end

%group backboardd

BOOL (*allowed_in_secure_update)(void *, void *);
%hookf(BOOL, allowed_in_secure_update, void *arg1, void *arg2) {
    return YES;
}

%end

CFStringRef PreferencesNotification = CFSTR("com.PS.exKeyboard.prefs");

static void letsprefs(){
    #if TARGET_OS_SIMULATOR
    enabled = allowLS = YES;
    noPrivate = NO;
    #else
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.PS.exKeyboard.plist"];
    id object = [prefs objectForKey:@"enabled"];
    enabled = object ? [object boolValue] : YES;
    if (!enabled)
        return;
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
    if (args.count) {
        NSString *executablePath = args[0];
        if (executablePath) {
            NSString *processName = [executablePath lastPathComponent];
            BOOL isSpringBoard = [processName isEqualToString:@"SpringBoard"];
            BOOL isExtensionOrApp = [executablePath rangeOfString:@"/Application"].location != NSNotFound;
            BOOL isExtension = [executablePath rangeOfString:@"appex"].location != NSNotFound;
            BOOL isbackboardd = [processName isEqualToString:@"backboardd"];
            BOOL isassetsd = [processName isEqualToString:@"assetsd"];
            if (isassetsd)
                return;
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
            } else if (isSpringBoard) {
                %init(SpringBoard);
            } else if (isbackboardd) {
                #if SIMULATOR
                MSImageRef qcRef = MSGetImageByName(realPath2(@"/System/Library/Frameworks/QuartzCore.framework/QuartzCore"));
                #else
                MSImageRef qcRef = MSGetImageByName("/System/Library/Frameworks/QuartzCore.framework/QuartzCore");
                #endif
                allowed_in_secure_update = (BOOL (*)(void *, void *))MSFindSymbol(qcRef, "__ZN2CA6Render6Update24allowed_in_secure_updateEPNS0_7ContextEPKNS0_9LayerHostE");
                %init(backboardd);
            }
        }
    }
}
