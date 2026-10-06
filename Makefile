# Plain xcodebuild wrappers so any editor, CI, or coding agent uses the same commands.
SIMULATOR ?= iPhone 17 Pro
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR)
XCODEBUILD := xcodebuild -project CaseTracker.xcodeproj -scheme CaseTracker -derivedDataPath build/DerivedData
APP := build/DerivedData/Build/Products/Debug-iphonesimulator/CaseTracker.app

.PHONY: build test run clean

build:
	$(XCODEBUILD) -destination '$(DESTINATION)' build

test:
	$(XCODEBUILD) -destination '$(DESTINATION)' test

run: build
	xcrun simctl boot '$(SIMULATOR)' 2>/dev/null || true
	open -a Simulator
	xcrun simctl install '$(SIMULATOR)' $(APP)
	xcrun simctl launch '$(SIMULATOR)' com.pushkarravi.CaseTracker

clean:
	rm -rf build
