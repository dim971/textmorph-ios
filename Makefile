SIMULATOR ?= iPhone 17 Pro
DERIVED := .build/showcase
PROJECT := Showcase/TextMorphShowcase.xcodeproj

.PHONY: test build lint format showcase project dashes clean

test:
	swift test

build:
	swift build

lint: dashes
	swiftformat --lint .
	swiftlint lint --quiet

format:
	swiftformat .

# The house rule, checked the same way CI checks it: no em dash, no en dash.
dashes:
	@if git grep -InP '[\x{2014}\x{2013}]' -- . ; then \
		echo "U+2014 or U+2013 found; use a comma, a colon or a full stop"; \
		exit 1; \
	fi

project:
	cd Showcase && xcodegen generate

showcase: project
	xcodebuild -project $(PROJECT) -scheme TextMorphShowcase \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		-derivedDataPath $(DERIVED) build
	xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	xcrun simctl install booted "$(DERIVED)/Build/Products/Debug-iphonesimulator/TextMorphShowcase.app"
	xcrun simctl launch booted io.github.dim971.textmorph.showcase

clean:
	rm -rf .build Showcase/TextMorphShowcase.xcodeproj
