GO_EASY_ON_ME = 1
SDKVERSION = 8.0
ARCHS = armv7 arm64

include theos/makefiles/common.mk

TWEAK_NAME = exKeyboard
exKeyboard_FILES = Tweak.xm
exKeyboard_FRAMEWORKS = UIKit
#exKeyboard_LIBRARIES = inspectivec

include $(THEOS_MAKE_PATH)/tweak.mk
