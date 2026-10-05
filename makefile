# Melos owns every workspace task; see the `melos:` section of the root
# pubspec and run them with `fvm exec dart run melos run <script>`. What is
# left here is what Melos does not cover: the reproducible container build,
# the release artefacts, and the dev container.
#
# The Flutter application is one workspace member among several; every
# command that targets it rather than the workspace runs from here.
APP := apps/app

.PHONY: fvm-check deps build-runner ios-pod-update devcontainer devcontainer-create devcontainer-start container-tools container-app apk release debug verify-reproducible

fvm-check:
	@echo "🔍 Checking FVM"
	@if ! command -v fvm >/dev/null 2>&1; then \
		echo "❌ FVM is not installed. See https://fvm.app"; \
		exit 1; \
	fi
	@fvm install

# Thin facades over Melos, kept because Containerfile.app invokes them to
# build the image without reaching into the workspace layout.
deps:
	@echo "🏃 Fetch dependencies"
	@fvm exec dart pub get --enforce-lockfile
	@fvm exec dart run melos bootstrap

build-runner:
	@echo "🏗️ Generate translations and database code"
	@fvm exec dart run melos run generate

ios-pod-update:
	@if [ "$$(uname)" != "Darwin" ]; then echo "Skipping pod update (not macOS)"; exit 0; fi
	@echo "🍎 Fetching iOS dependencies"
	@fvm flutter precache --ios
	@cd $(APP)/ios && pod install --repo-update && cd -

# Container runtime — default podman, override with CONTAINER=docker for
# environments without podman.
CONTAINER ?= podman

container-tools:
	@echo "🔧 Building tools image"
	@$(CONTAINER) build -f Containerfile.tools -t furtive-tools \
		--build-arg FLUTTER_VERSION=$$(python3 -c 'import json; print(json.load(open(".fvmrc"))["flutter"])') \
		--build-arg JVM_TARGET=$$(grep 'android.jvmTarget' $(APP)/android/gradle.properties | cut -d= -f2) \
		--build-arg ANDROID_API_LEVEL=$$(grep 'android.compileSdk' $(APP)/android/gradle.properties | cut -d= -f2) \
		--build-arg ANDROID_BUILD_TOOLS=$$(grep 'android.buildToolsVersion' $(APP)/android/gradle.properties | cut -d= -f2) \
		--build-arg ANDROID_NDK=$$(grep 'android.ndkVersion' $(APP)/android/gradle.properties | cut -d= -f2) \
		.

container-app: container-tools
	@echo "📦 Building app image"
	@$(CONTAINER) build -f Containerfile.app -t furtive-app \
		--build-arg GRADLE_HEAP=$(or $(GRADLE_HEAP),4g) \
		.

MODE ?= release
FORMAT ?= apk

# Allow "make apk release" or "make apk debug" syntax
ifneq (,$(filter release,$(MAKECMDGOALS)))
  MODE := release
endif
ifneq (,$(filter debug,$(MAKECMDGOALS)))
  MODE := debug
endif
release debug:
	@:

# Flutter writes APK and AAB to different paths
ifeq ($(FORMAT),aab)
  CONTAINER_OUTPUT := /app/$(APP)/build/app/outputs/bundle/$(MODE)/app-$(MODE).aab
  HOST_OUTPUT := ./app-$(MODE).aab
  FLUTTER_BUILD := fvm flutter build appbundle --$(MODE)
else
  CONTAINER_OUTPUT := /app/$(APP)/build/app/outputs/flutter-apk/app-$(MODE).apk
  HOST_OUTPUT := ./app-$(MODE).apk
  FLUTTER_BUILD := fvm flutter build apk --$(MODE)
endif

# Pass secrets to the build via --dart-define if they are set in the host
# environment. Empty values produce a build without the secret (CI / FOSS
# reproducible path). Override per-invocation: `make apk PROTOMAPS_KEY=xxx`.
DART_DEFINES :=
ifneq ($(strip $(PROTOMAPS_KEY)),)
  DART_DEFINES += --dart-define=PROTOMAPS_KEY=$(PROTOMAPS_KEY)
endif
ifneq ($(strip $(PROTOMAPS_URL)),)
  DART_DEFINES += --dart-define=PROTOMAPS_URL=$(PROTOMAPS_URL)
endif
ifneq ($(strip $(SHARE_VIEWER_URL)),)
  DART_DEFINES += --dart-define=SHARE_VIEWER_URL=$(SHARE_VIEWER_URL)
endif
ifneq ($(strip $(SHARE_RELAYS)),)
  DART_DEFINES += --dart-define=SHARE_RELAYS=$(SHARE_RELAYS)
endif

# Pin every timestamp the build embeds (zip entries, .class files, manifest
# attrs) to the source commit so builds are reproducible across hosts and
# wall-clock times. Honored by Gradle/AGP, Kotlin compiler, Flutter tools.
SOURCE_DATE_EPOCH ?= $(shell git log -1 --format=%ct 2>/dev/null || echo 0)

apk: container-app
	@echo "🔨 Building $(FORMAT) ($(MODE)) via $(CONTAINER)"
	@echo "   SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH)"
	@$(CONTAINER) rm -f furtive-build > /dev/null 2>&1 || true
	@$(CONTAINER) run --name furtive-build \
		--ulimit nofile=65536:65536 \
		-e SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
		furtive-app bash -c 'cd /app/$(APP) && $(FLUTTER_BUILD) $(DART_DEFINES)'
	@$(CONTAINER) cp furtive-build:$(CONTAINER_OUTPUT) $(HOST_OUTPUT)
	@$(CONTAINER) rm furtive-build > /dev/null
	@echo "✅ Output extracted: $(HOST_OUTPUT)"
	@sha256sum $(HOST_OUTPUT) 2>/dev/null || shasum -a 256 $(HOST_OUTPUT)

# Build twice with identical inputs and compare SHA-256. Passes if bytes
# match, fails loudly with a diff hint otherwise. Use this in CI to catch
# reproducibility regressions early.
verify-reproducible:
	@echo "🔁 Reproducibility check: building twice and comparing"
	@$(MAKE) apk MODE=$(or $(MODE),release) FORMAT=$(or $(FORMAT),apk) PROTOMAPS_KEY=$(PROTOMAPS_KEY) PROTOMAPS_URL=$(PROTOMAPS_URL)
	@mv $(HOST_OUTPUT) $(HOST_OUTPUT).run1
	@$(MAKE) apk MODE=$(or $(MODE),release) FORMAT=$(or $(FORMAT),apk) PROTOMAPS_KEY=$(PROTOMAPS_KEY) PROTOMAPS_URL=$(PROTOMAPS_URL)
	@mv $(HOST_OUTPUT) $(HOST_OUTPUT).run2
	@SUM1=$$(sha256sum $(HOST_OUTPUT).run1 2>/dev/null || shasum -a 256 $(HOST_OUTPUT).run1); \
	 SUM2=$$(sha256sum $(HOST_OUTPUT).run2 2>/dev/null || shasum -a 256 $(HOST_OUTPUT).run2); \
	 echo "run1: $$SUM1"; \
	 echo "run2: $$SUM2"; \
	 H1=$$(echo $$SUM1 | awk '{print $$1}'); \
	 H2=$$(echo $$SUM2 | awk '{print $$1}'); \
	 if [ "$$H1" = "$$H2" ]; then \
	   echo "✅ Bit-identical"; \
	   rm -f $(HOST_OUTPUT).run2; mv $(HOST_OUTPUT).run1 $(HOST_OUTPUT); \
	 else \
	   echo "❌ Differs. Investigate with: diffoscope $(HOST_OUTPUT).run1 $(HOST_OUTPUT).run2"; \
	   exit 1; \
	 fi

PROJECT := $(notdir $(CURDIR))

devcontainer-create:
	@echo "🏗️  Creating Dev Container"
	@devcontainer up --workspace-folder . --config ./.devcontainer/devcontainer.json

devcontainer-start:
	@echo "▶️  Starting Dev Container ($(PROJECT))"
	@$(CONTAINER) start $(PROJECT)
	@$(CONTAINER) exec -it $(PROJECT) bash

# Alias for backwards compatibility
devcontainer: devcontainer-create
