APP_NAME := Pellucid
APP_BUNDLE := build/$(APP_NAME).app
CONTENTS := $(APP_BUNDLE)/Contents

.DEFAULT_GOAL := app

app: ## Build release .app bundle
	swift build -c release
	@$(MAKE) --no-print-directory _assemble BINARY=.build/release/$(APP_NAME)

app-debug: ## Build debug .app bundle
	swift build
	@$(MAKE) --no-print-directory _assemble BINARY=.build/debug/$(APP_NAME)

_assemble:
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(CONTENTS)/MacOS" "$(CONTENTS)/Resources"
	cp "$(BINARY)" "$(CONTENTS)/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(CONTENTS)/Info.plist"
	@test -f Resources/AppIcon.icns && cp Resources/AppIcon.icns "$(CONTENTS)/Resources/" || true
	cp -R $$(find .build -name "SwiftMath_SwiftMath.bundle" -type d | head -1) "$(CONTENTS)/Resources/"
	codesign --force --deep --sign - "$(APP_BUNDLE)"
	@echo "Built: $(APP_BUNDLE)"
	@echo "Run:   open $(APP_BUNDLE)"

install: app ## Install to /Applications (replaces existing)
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "Installed: /Applications/$(APP_NAME).app"

open: app ## Launch the built app
	open "$(APP_BUNDLE)"

test: ## Run tests
	swift test

clean: ## Remove build artifacts
	rm -rf .build build

portindex: ## Regenerate MacPorts PortIndex
	cd ports && portindex

checksums: ## Print checksums for a release tarball (VERSION=x.y.z)
	@test -n "$(VERSION)" || { echo "Usage: make checksums VERSION=1.0.3"; exit 1; }
	@bash scripts/update-portfile-checksums.sh "$(VERSION)"

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "  %-15s %s\n", $$1, $$2}'

.PHONY: app app-debug install open test clean portindex checksums help
