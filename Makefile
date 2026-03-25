# Houston

.DEFAULT_GOAL := help

# Allow: make release patch, make release minor, make release major
ifneq ($(filter patch minor major,$(MAKECMDGOALS)),)
  BUMP := $(filter patch minor major,$(MAKECMDGOALS))
endif
patch minor major:; @true

# Build ────────────────────────────────────────

.PHONY: build
build: ## Build the package
	cd HoustonKit && swift build 2>&1 | tail -2

.PHONY: build-release
build-release: ## Build the package (release)
	cd HoustonKit && swift build -c release 2>&1 | tail -2

.PHONY: build-app
build-app: ## Build the app
	@xcodebuild -scheme Houston -configuration Debug -destination 'platform=macOS,arch=arm64' build -quiet

.PHONY: build-app-release
build-app-release: ## Build the app (release)
	@xcodebuild -scheme Houston -configuration Release -destination 'platform=macOS,arch=arm64' build -quiet

.PHONY: install
install: build-app-release ## Build and install to /Applications
	@echo ""
	@printf "  Installing to /Applications..."
	@cp -R "$$(xcodebuild -scheme Houston -configuration Release -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$NF}')/Houston.app" /Applications/
	@echo " done."
	@echo ""
	@printf "  \033[1mHOUSTON IS GO\033[0m\n"
	@echo ""

# Test ─────────────────────────────────────────

.PHONY: test
test: ## Run tests
	@cd HoustonKit && swift test 2>&1 | awk '/tests in .* suites/{print ""; print; next} /Suite .* passed/{next} /Test .* passed/{printf "."; next} /Test .* failed/{printf "F"; print; next} /error:/{print; next}'

.PHONY: test-verbose
test-verbose: ## Run tests (verbose)
	cd HoustonKit && swift test --verbose

.PHONY: test-module
test-module: ## Run one module's tests (MOD=Models)
	cd HoustonKit && swift test --filter $(MOD)Tests

# Lint ─────────────────────────────────────────

.PHONY: lint
lint: ## Lint with swiftlint
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --quiet; \
	else \
		echo "swiftlint not found — brew install swiftlint"; \
	fi

.PHONY: format
format: ## Format with swift-format
	@if command -v swift-format >/dev/null 2>&1; then \
		find HoustonKit/Sources HoustonKit/Tests Houston -name '*.swift' | xargs swift-format -i; \
	else \
		echo "swift-format not found — brew install swift-format"; \
	fi

# Release ─────────────────────────────────────

SCHEME       := Houston
APP_NAME     := Houston
BUILD_DIR    := build
ARCHIVE_PATH := $(BUILD_DIR)/Houston.xcarchive
EXPORT_PATH  := $(BUILD_DIR)/export
VERSION      := $(shell xcodebuild -scheme $(SCHEME) -showBuildSettings 2>/dev/null | grep MARKETING_VERSION | awk '{print $$NF}')
ARCH         := $(shell uname -m)
DMG_NAME     := Houston-$(VERSION)-$(ARCH).dmg
DMG_PATH     := $(BUILD_DIR)/$(DMG_NAME)

.PHONY: archive
archive: ## Archive signed release build
	@mkdir -p $(BUILD_DIR)
	@printf "  Archiving..."
	@xcodebuild archive \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination 'generic/platform=macOS' \
		-archivePath $(ARCHIVE_PATH) \
		-quiet
	@echo " done."

.PHONY: export
export: archive ## Export signed .app from archive
	@printf "  Exporting..."
	@xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist ExportOptions.plist \
		-quiet
	@echo " done."

.PHONY: notarize
notarize: export ## Notarize the exported .app
	@printf "  Notarizing..."
	@ditto -c -k --keepParent "$(EXPORT_PATH)/$(APP_NAME).app" "$(BUILD_DIR)/Houston-notarize.zip"
	@xcrun notarytool submit "$(BUILD_DIR)/Houston-notarize.zip" \
		--keychain-profile "Houston" \
		--wait
	@xcrun stapler staple "$(EXPORT_PATH)/$(APP_NAME).app"
	@rm "$(BUILD_DIR)/Houston-notarize.zip"
	@echo " done."

.PHONY: dmg
dmg: notarize ## Create notarized DMG
	@printf "  Creating DMG..."
	@mkdir -p "$(BUILD_DIR)/dmg-staging"
	@cp -R "$(EXPORT_PATH)/$(APP_NAME).app" "$(BUILD_DIR)/dmg-staging/"
	@ln -sf /Applications "$(BUILD_DIR)/dmg-staging/Applications"
	@hdiutil create -volname "Houston" \
		-srcfolder "$(BUILD_DIR)/dmg-staging" \
		-ov -format UDZO \
		"$(DMG_PATH)" >/dev/null
	@rm -rf "$(BUILD_DIR)/dmg-staging"
	@xcrun notarytool submit "$(DMG_PATH)" \
		--keychain-profile "Houston" \
		--wait
	@xcrun stapler staple "$(DMG_PATH)"
	@echo " done."
	@echo ""
	@printf "  \033[1m$(DMG_NAME)\033[0m\n"
	@echo ""

BUMP         ?= patch
NEXT_VERSION  = $(shell echo "$(VERSION)" | awk -F. -v bump="$(BUMP)" '{ \
	if (bump == "major") { printf "%d.0.0", $$1+1 } \
	else if (bump == "minor") { printf "%d.%d.0", $$1, $$2+1 } \
	else { printf "%d.%d.%d", $$1, $$2, (NF>=3 ? $$3+1 : 1) } }')

.PHONY: release
release: ## Release: make release [patch|minor|major]
	@printf "  $(VERSION) → $(NEXT_VERSION)\n"
	@sed -i '' 's/MARKETING_VERSION = .*/MARKETING_VERSION = $(NEXT_VERSION);/' Houston.xcodeproj/project.pbxproj
	@git add Houston.xcodeproj/project.pbxproj
	@git commit -m "Bump version to $(NEXT_VERSION)"
	@git tag "v$(NEXT_VERSION)"
	@$(MAKE) dmg VERSION=$(NEXT_VERSION)
	@gh release create "v$(NEXT_VERSION)" "$(BUILD_DIR)/Houston-$(NEXT_VERSION)-$(ARCH).dmg" \
		--title "Houston $(NEXT_VERSION)"
	@printf "\n  \033[32mReleased Houston $(NEXT_VERSION)\033[0m\n\n"

# Clean ────────────────────────────────────────

.PHONY: clean
clean: ## Clean build artifacts
	cd HoustonKit && swift package clean

.PHONY: clean-all
clean-all: clean ## Clean everything
	@xcodebuild -scheme Houston clean -quiet 2>/dev/null || true
	@rm -rf ~/Library/Developer/Xcode/DerivedData/Houston-*
	@rm -rf build

.PHONY: reset
reset: ## Clean + resolve packages
	cd HoustonKit && swift package clean && swift package resolve

# Helpers ──────────────────────────────────────

.PHONY: open
open: ## Open in Xcode
	@open Houston.xcodeproj

.PHONY: resolve
resolve: ## Resolve SPM dependencies
	cd HoustonKit && swift package resolve

.PHONY: loc
loc: ## Count lines of code
	@printf "  package  " && find HoustonKit/Sources -name '*.swift' | xargs wc -l | tail -1 | awk '{print $$1}'
	@printf "  app      " && find Houston -name '*.swift' | xargs wc -l | tail -1 | awk '{print $$1}'
	@printf "  tests    " && find HoustonKit/Tests -name '*.swift' | xargs wc -l | tail -1 | awk '{print $$1}'

# Help ─────────────────────────────────────────

.PHONY: help
help: ## Show commands
	@printf "\n  \033[1mHouston\033[0m\n\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
