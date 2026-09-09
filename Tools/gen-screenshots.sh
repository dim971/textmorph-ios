#!/bin/sh
# Takes the screenshots the README and docs/ use.
#
#   make project
#   Tools/gen-screenshots.sh docs/images
#
# Run by hand, never in CI. A picture of a morph goes stale the moment a demo
# changes, and one that has to be recaptured by hand goes stale and stays
# stale, so the showcase reads SHOWCASE_TAB and SHOWCASE_DEMO from its
# environment and this drives it.

set -eu

OUT=${1:-docs/images}
SIMULATOR=${SIMULATOR:-iPhone 17 Pro}
APP=io.github.dim971.textmorph.showcase
DERIVED=.build/showcase
BUNDLE="$DERIVED/Build/Products/Debug-iphonesimulator/TextMorphShowcase.app"

mkdir -p "$OUT"

xcodebuild build -quiet \
	-project Showcase/TextMorphShowcase.xcodeproj \
	-scheme TextMorphShowcase \
	-destination "platform=iOS Simulator,name=$SIMULATOR" \
	-derivedDataPath "$DERIVED"

xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR" -b
xcrun simctl install booted "$BUNDLE"

shot() {
	name=$1
	shift
	xcrun simctl terminate booted "$APP" 2>/dev/null || true
	# The launch environment is how a screen is chosen; see Launch in the app.
	xcrun simctl launch booted "$APP" >/dev/null
	xcrun simctl spawn booted launchctl setenv "$@" 2>/dev/null || true
	sleep 3
	xcrun simctl io booted screenshot "$OUT/$name.png"
	echo "wrote $OUT/$name.png"
}

# simctl passes the environment through with SIMCTL_CHILD_ prefixed variables.
launch_with() {
	name=$1
	tab=$2
	demo=${3:-}
	xcrun simctl terminate booted "$APP" 2>/dev/null || true
	SIMCTL_CHILD_SHOWCASE_TAB="$tab" SIMCTL_CHILD_SHOWCASE_DEMO="$demo" \
		xcrun simctl launch booted "$APP" >/dev/null
	sleep 3
	xcrun simctl io booted screenshot "$OUT/$name.png"
	echo "wrote $OUT/$name.png"
}

launch_with catalog catalog
launch_with playground playground
launch_with wallet catalog wallet
launch_with ticker catalog ticker
launch_with field catalog field
launch_with reflow catalog reflow
launch_with hero catalog wallet

xcrun simctl terminate booted "$APP" 2>/dev/null || true
