# Houston — macOS launchd GUI
# Common development commands

.DEFAULT_GOAL := help

# ──────────────────────────────────────────────
# Build
# ──────────────────────────────────────────────

.PHONY: build
build: ## Build HoustonKit SPM package
	cd HoustonKit && swift build 2>&1 | tail -2

.PHONY: build-release
build-release: ## Build HoustonKit in release mode
	cd HoustonKit && swift build -c release 2>&1 | tail -2

.PHONY: build-app
build-app: ## Build the full Houston app via xcodebuild
	@xcodebuild -scheme Houston -configuration Debug -destination 'platform=macOS,arch=arm64' build -quiet

.PHONY: build-app-release
build-app-release: ## Build the Houston app in release configuration
	@xcodebuild -scheme Houston -configuration Release -destination 'platform=macOS,arch=arm64' build -quiet

.PHONY: install
install: build-app-release ## Build release and copy to /Applications
	@echo ""
	@printf "  Installing to /Applications..."
	@cp -R "$$(xcodebuild -scheme Houston -configuration Release -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$NF}')/Houston.app" /Applications/
	@echo " done."
	@echo ""
	@printf "  \033[1mH O U S T O N   I S   G O\033[0m\n"
	@echo ""

# ──────────────────────────────────────────────
# Test
# ──────────────────────────────────────────────

.PHONY: test
test: ## Run all HoustonKit tests
	@cd HoustonKit && swift test 2>&1 | awk '/tests in .* suites/{print ""; print; next} /Suite .* passed/{next} /Test .* passed/{printf "."; next} /Test .* failed/{printf "F"; print; next} /error:/{print; next}'

.PHONY: test-verbose
test-verbose: ## Run tests with verbose output
	cd HoustonKit && swift test --verbose

.PHONY: test-module
test-module: ## Run tests for a single module (usage: make test-module MOD=Models)
	cd HoustonKit && swift test --filter $(MOD)Tests

# ──────────────────────────────────────────────
# Lint & Format
# ──────────────────────────────────────────────

.PHONY: lint
lint: ## Lint Swift files with swiftlint (if installed)
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --quiet; \
	else \
		echo "swiftlint not found — install with: brew install swiftlint"; \
	fi

.PHONY: format
format: ## Format Swift files with swift-format (if installed)
	@if command -v swift-format >/dev/null 2>&1; then \
		find HoustonKit/Sources HoustonKit/Tests Houston -name '*.swift' | xargs swift-format -i; \
	else \
		echo "swift-format not found — install with: brew install swift-format"; \
	fi

# ──────────────────────────────────────────────
# Clean
# ──────────────────────────────────────────────

.PHONY: clean
clean: ## Clean SPM build artifacts
	cd HoustonKit && swift package clean

.PHONY: clean-all
clean-all: clean ## Clean SPM + Xcode derived data
	@xcodebuild -scheme Houston clean -quiet 2>/dev/null || true
	@rm -rf ~/Library/Developer/Xcode/DerivedData/Houston-*

.PHONY: reset
reset: ## Full reset: clean + resolve packages
	cd HoustonKit && swift package clean && swift package resolve

# ──────────────────────────────────────────────
# Xcode
# ──────────────────────────────────────────────

.PHONY: open
open: ## Open the project in Xcode
	@if [ -d Houston.xcodeproj ]; then \
		open Houston.xcodeproj; \
	else \
		echo "Houston.xcodeproj not found — create it in Xcode first"; \
	fi

.PHONY: resolve
resolve: ## Resolve SPM dependencies
	cd HoustonKit && swift package resolve

# ──────────────────────────────────────────────
# Utilities
# ──────────────────────────────────────────────

.PHONY: fixtures
fixtures: ## Validate test fixture plists
	@echo "Validating test fixtures..."
	@for f in TestFixtures/*.plist; do \
		if plutil -lint "$$f" >/dev/null 2>&1; then \
			echo "  ✓ $$f"; \
		else \
			echo "  ✗ $$f"; \
			plutil -lint "$$f"; \
		fi \
	done

.PHONY: loc
loc: ## Count lines of Swift code
	@echo "HoustonKit:"
	@find HoustonKit/Sources -name '*.swift' | xargs wc -l | tail -1
	@echo "App:"
	@find Houston -name '*.swift' | xargs wc -l | tail -1
	@echo "Tests:"
	@find HoustonKit/Tests -name '*.swift' | xargs wc -l | tail -1

# ──────────────────────────────────────────────
# Help
# ──────────────────────────────────────────────

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
