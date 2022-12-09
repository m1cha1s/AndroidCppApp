# The name of your app
APPNAME               ?= helloWorld

# Your java package name
PACKAGENAME           ?= org.yourorg.$(APPNAME)


ANDROID_FULLSCREEN    ?= y

# Android SDK version
ANDROIDVERSION        ?= 29

# Include the whole build system
include android.mk