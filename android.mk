#Copyright (c) 2019-2020 <>< Charles Lohr - Under the MIT/x11 or NewBSD License you choose.
# NO WARRANTY! NO GUARANTEE OF SUPPORT! USE AT YOUR OWN RISK

all : build/app.apk

.PHONY : push run

LABEL?=$(APPNAME)
APKFILE ?= build/$(APPNAME).apk

SRC := $(shell find ./src -name '*.c*') ./androidMisc/android_native_app_glue.c
OBJ := $(patsubst %.c*,%.o, $(SRC))

#We've tested it with android version 22, 24, 28, 29 and 30.
#You can target something like Android 28, but if you set ANDROIDVERSION to say 22, then
#Your app should (though not necessarily) support all the way back to Android 22. 
ANDROIDTARGET?=$(ANDROIDVERSION)
#Default is to be strip down, but your app can override it.
CFLAGS?=-ffunction-sections -Os -fdata-sections -Wall -fvisibility=hidden
LDFLAGS?=-Wl,--gc-sections -s
ADB?=adb
UNAME := $(shell uname)

#if you have a custom Android Home location you can add it to this list.  
#This makefile will select the first present folder.


ifeq ($(UNAME), Linux)
OS_NAME = linux-x86_64
endif
ifeq ($(UNAME), Darwin)
OS_NAME = darwin-x86_64
endif
ifeq ($(OS), Windows_NT)
OS_NAME = windows-x86_64
endif

# Search list for where to try to find the SDK
SDK_LOCATIONS += $(ANDROID_HOME) $(ANDROID_SDK_ROOT) ~/Android/Sdk $(HOME)/Library/Android/sdk

#Just a little Makefile witchcraft to find the first SDK_LOCATION that exists
#Then find an ndk folder and build tools folder in there.
ANDROIDSDK?=$(firstword $(foreach dir, $(SDK_LOCATIONS), $(basename $(dir) ) ) )
NDK?=$(firstword $(ANDROID_NDK) $(ANDROID_NDK_HOME) $(wildcard $(ANDROIDSDK)/ndk/*) $(wildcard $(ANDROIDSDK)/ndk-bundle/*) $(wildcard $(ANDROIDSDK)/ndk/21.3.6528147/*) )
BUILD_TOOLS?=$(lastword $(wildcard $(ANDROIDSDK)/build-tools/*) )

# fall back to default Android SDL installation location if valid NDK was not found
ifeq ($(NDK),)
ANDROIDSDK := ~/Android/Sdk
endif

# Verify if directories are detected
ifeq ($(ANDROIDSDK),)
$(error ANDROIDSDK directory not found)
endif
ifeq ($(NDK),)
$(error NDK directory not found)
endif
ifeq ($(BUILD_TOOLS),)
$(error BUILD_TOOLS directory not found)
endif

testsdk :
	@echo "SDK:\t\t" $(ANDROIDSDK)
	@echo "NDK:\t\t" $(NDK)
	@echo "Build Tools:\t" $(BUILD_TOOLS)

CFLAGS+=-Os -DANDROID -DAPPNAME=\"$(APPNAME)\"
ifeq (ANDROID_FULLSCREEN,y)
CFLAGS +=-DANDROID_FULLSCREEN
endif
CFLAGS+= -I./rawdraw -I./androidMisc -I$(NDK)/sysroot/usr/include -I$(NDK)/sysroot/usr/include/android -I$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/include/android -fPIC -I$(RAWDRAWANDROID) -DANDROIDVERSION=$(ANDROIDVERSION)
LDFLAGS += -lm -lGLESv3 -lEGL -landroid -llog
LDFLAGS += -shared -uANativeActivity_onCreate

CC_ARM64:=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/aarch64-linux-android$(ANDROIDVERSION)-clang
CC_ARM32:=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/armv7a-linux-androideabi$(ANDROIDVERSION)-clang
CC_x86:=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/i686-linux-android$(ANDROIDVERSION)-clang
CC_x86_64=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/x86_64-linux-android$(ANDROIDVERSION)-clang

CXX_ARM64:=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/aarch64-linux-android$(ANDROIDVERSION)-clang++
CXX_ARM32:=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/armv7a-linux-androideabi$(ANDROIDVERSION)-clang++
CXX_x86:=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/i686-linux-android$(ANDROIDVERSION)-clang++
CXX_x86_64=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/x86_64-linux-android$(ANDROIDVERSION)-clang++

AAPT:=$(BUILD_TOOLS)/aapt

# Which binaries to build? Just comment/uncomment these lines:
TARGETS += build/lib/arm64-v8a/lib$(APPNAME).so
TARGETS += build/lib/armeabi-v7a/lib$(APPNAME).so
# TARGETS += build/lib/x86/lib$(APPNAME).so
# TARGETS += build/lib/x86_64/lib$(APPNAME).so

CFLAGS_ARM64:=-m64
CFLAGS_ARM32:=-mfloat-abi=softfp -m32
CFLAGS_x86:=-march=i686 -mtune=intel -mssse3 -mfpmath=sse -m32
CFLAGS_x86_64:=-march=x86-64 -msse4.2 -mpopcnt -m64 -mtune=intel
STOREPASS?=password
DNAME:="CN=example.com, OU=ID, O=Example, L=Doe, S=John, C=GB"
KEYSTOREFILE:=my-release-key.keystore
ALIASNAME?=standkey

keystore : $(KEYSTOREFILE)

$(KEYSTOREFILE) :
	keytool -genkey -v -keystore $(KEYSTOREFILE) -alias $(ALIASNAME) -keyalg RSA -keysize 2048 -validity 10000 -storepass $(STOREPASS) -keypass $(STOREPASS) -dname $(DNAME)

folders:
	mkdir -p build/lib/arm64-v8a
	mkdir -p build/lib/armeabi-v7a
	mkdir -p build/lib/x86
	mkdir -p build/lib/x86_64

arm64-v8a/lib/%.o: androidMisc/%.c
	$(CC_ARM64) $(CFLAGS) $(CFLAGS_ARM64) -c -o $@ $^

armeabi-v7a/lib/%.o: androidMisc/%.c
	$(CC_ARM32) $(CFLAGS) $(CFLAGS_ARM64) -c -o $@ $^

x86/lib/%.o: androidMisc/%.c
	$(CC_x86) $(CFLAGS) $(CFLAGS_ARM64) -c -o $@ $^

x86_64/lib/%.o: androidMisc/%.c
	$(CC_x86_64) $(CFLAGS) $(CFLAGS_ARM64) -c -o $@ $^

arm64-v8a/lib/%.o: src/%.c
	$(CC_ARM64) $(CFLAGS) $(CFLAGS_ARM64) -c -o $@ $^

armeabi-v7a/lib/%.o: src/%.c
	$(CC_ARM32) $(CFLAGS) $(CFLAGS_ARM64) -c -o $@ $^

x86/lib/%.o: src/%.c
	$(CC_x86) $(CFLAGS) $(CFLAGS_ARM64) -c -o $@ $^

x86_64/lib/%.o: src/%.c
	$(CC_x86_64) $(CFLAGS) $(CFLAGS_ARM64) -c -o $@ $^


arm64-v8a/lib/%.o: src/%.cpp
	$(CXX_ARM64) $(CFLAGS) $(CFLAGS_ARM64) -c -o $@ $^

armeabi-v7a/lib/%.o: src/%.cpp
	$(CXX_ARM32) $(CFLAGS) $(CFLAGS_ARM64) -c -o $@ $^

x86/lib/%.o: src/%.cpp
	$(CXX_x86) $(CFLAGS) $(CFLAGS_ARM64) -c -o $@ $^

x86_64/lib/%.o: src/%.cpp
	$(CXX_x86_64) $(CFLAGS) $(CFLAGS_ARM64) -c -o $@ $^
	

build/lib/arm64-v8a/lib$(APPNAME).so : $(patsubst %.o,arm64-v8a/lib/%.o, $(OBJ))
	mkdir -p build/lib/arm64-v8a
	$(CC_ARM64) $(CFLAGS) $(CFLAGS_ARM64) -o $@ $(patsubst %.o,arm64-v8a/lib/%.o, $^) -L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/aarch64-linux-android/$(ANDROIDVERSION) $(LDFLAGS)

build/lib/armeabi-v7a/lib$(APPNAME).so : $(patsubst %.o,armeabi-v7a/lib/%.o, $(OBJ))
	mkdir -p build/lib/armeabi-v7a
	$(CC_ARM32) $(CFLAGS) $(CFLAGS_ARM32) -o $@ $(patsubst %.o,armeabi-v7a/lib/%.o, $^) -L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/arm-linux-androideabi/$(ANDROIDVERSION) $(LDFLAGS)

build/lib/x86/lib$(APPNAME).so : $(patsubst %.o,x86/lib/%.o, $(OBJ))
	mkdir -p build/lib/x86
	$(CC_x86) $(CFLAGS) $(CFLAGS_x86) -o $@ $(patsubst %.o,x86/lib/%.o, $^) -L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/i686-linux-android/$(ANDROIDVERSION) $(LDFLAGS)

build/lib/x86_64/lib$(APPNAME).so : $(patsubst %.o,x86_64/lib/%.o, $(OBJ))
	mkdir -p build/lib/x86_64
	$(CC_x86) $(CFLAGS) $(CFLAGS_x86_64) -o $@ $(patsubst %.o,x86_64/lib/%.o, $^) -L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/x86_64-linux-android/$(ANDROIDVERSION) $(LDFLAGS)

#We're really cutting corners.  You should probably use resource files.. Replace android:label="@string/app_name" and add a resource file.
#Then do this -S Sources/res on the aapt line.
#For icon support, add -S app/res to the aapt line.  also,  android:icon="@mipmap/icon" to your application line in the manifest.
#If you want to strip out about 800 bytes of data you can remove the icon and strings.

#Notes for the past:  These lines used to work, but don't seem to anymore.  Switched to newer jarsigner.
#(zipalign -c -v 8 app.apk)||true #This seems to not work well.
#jarsigner -verify -verbose -certs app.apk



build/app.apk : $(TARGETS) $(EXTRA_ASSETS_TRIGGER) androidMisc/AndroidManifest.xml
	mkdir -p build/assets
	pwd
	cp -r ./assets/* build/assets 2>/dev/null || :
	rm -rf build/temp.apk
	$(AAPT) package -f -F build/temp.apk -I $(ANDROIDSDK)/platforms/android-$(ANDROIDVERSION)/android.jar -M androidMisc/AndroidManifest.xml -S res -A build/assets -v --target-sdk-version $(ANDROIDTARGET)
	unzip -o build/temp.apk -d build/app
	rm -rf $@
	cd build/app && zip -D9r ../../$@ . && zip -D0r ../../$@ ./resources.arsc ./androidMisc/AndroidManifest.xml
	jarsigner -sigalg SHA1withRSA -digestalg SHA1 -verbose -keystore $(KEYSTOREFILE) -storepass $(STOREPASS) $@ $(ALIASNAME)
	rm -rf $(APKFILE)
	$(BUILD_TOOLS)/zipalign -v 4 $@ $(APKFILE)
	#Using the apksigner in this way is only required on Android 30+
	$(BUILD_TOOLS)/apksigner sign --key-pass pass:$(STOREPASS) --ks-pass pass:$(STOREPASS) --ks $(KEYSTOREFILE) $(APKFILE)
	rm -rf build/temp.apk
	rm -rf $@
	@ls -l $(APKFILE)

build/manifest: androidMisc/AndroidManifest.xml

androidMisc/AndroidManifest.xml : androidMisc/AndroidManifest.xml.template
	rm -rf $@
	PACKAGENAME=$(PACKAGENAME) \
		ANDROIDVERSION=$(ANDROIDVERSION) \
		ANDROIDTARGET=$(ANDROIDTARGET) \
		APPNAME=$(APPNAME) \
		LABEL=$(LABEL) envsubst '$$ANDROIDTARGET $$ANDROIDVERSION $$APPNAME $$PACKAGENAME $$LABEL' \
		< $^ > $@


uninstall : 
	($(ADB) uninstall $(PACKAGENAME))||true

push : build/app.apk
	@echo "Installing" $(PACKAGENAME)
	$(ADB) install -r $(APKFILE)

run : push
	$(eval ACTIVITYNAME:=$(shell $(AAPT) dump badging $(APKFILE) | grep "launchable-activity" | cut -f 2 -d"'"))
	$(ADB) shell am start -n $(PACKAGENAME)/$(ACTIVITYNAME)

clean :
	rm -rf build/temp.apk build/app.apk build $(APKFILE) androidMisc/AndroidManifest.xml