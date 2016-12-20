DEBUG = 0
PACKAGE_VERSION = 1.2

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = exKeyboard
exKeyboard_FILES = Tweak.xm
exKeyboard_FRAMEWORKS = UIKit
exKeyboard_PRIVATE_FRAMEWORKS = TCC

include $(THEOS_MAKE_PATH)/tweak.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp -R Resources $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/exKeyboard$(ECHO_END)
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -name .DS_Store | xargs rm -rf$(ECHO_END)