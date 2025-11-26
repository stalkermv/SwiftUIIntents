#!/bin/bash

# Script modified from https://docs.emergetools.com/docs/analyzing-a-spm-framework-ios
#
# GitHub Actions Integration:
# This script is automatically invoked by the release workflow (`.github/workflows/release-framework.yml`)
# when a version tag (e.g., "1.0.0") is pushed to the repository. The workflow:
# 1. Triggers on push tags matching semver pattern [0-9]+.[0-9]+.[0-9]+
# 2. Builds the XCFramework for iOS, iOS Simulator, and macOS
# 3. Creates a GitHub Release with the tag version
# 4. Uploads the generated XCFramework zip as a release asset
#
# To create a release manually:
#   git tag 1.0.0
#   git push origin 1.0.0
#
# The build artifacts are placed in the `build/` directory:
#   - <PackageName>.xcframework.zip - Universal XCFramework archive
#   - <PackageName>-*.xcarchive - Individual platform archives

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd -P)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

PROJECT_BUILD_DIR="${PROJECT_BUILD_DIR:-"${PROJECT_ROOT}/build"}"
mkdir -p "$PROJECT_BUILD_DIR"
SWIFTPM_WORKSPACE="$PROJECT_ROOT/.swiftpm/xcode/package.xcworkspace"
SWIFTPM_CHECKOUTS_DIR="$PROJECT_ROOT/.build/checkouts"
SWIFT_SERVICE_CONTEXT_DIR="$SWIFTPM_CHECKOUTS_DIR/swift-service-context"
LICENSE_FILE="$PROJECT_ROOT/LICENSE"
NOTICE_FILE="$PROJECT_ROOT/NOTICE"
LICENSES_DIR="$PROJECT_ROOT/LICENSES"

if [ ! -d "$SWIFTPM_WORKSPACE" ]; then
    echo "SwiftPM workspace not found at $SWIFTPM_WORKSPACE. Open the package in Xcode once (or run 'swift package generate-xcodeproj') to generate it."
    exit 1
fi

REQUIRED_LICENSE_FILES=(
    "$LICENSE_FILE"
    "$LICENSES_DIR/Apache-2.0.txt"
    "$NOTICE_FILE"
)

for required_file in "${REQUIRED_LICENSE_FILES[@]}"; do
    if [ ! -f "$required_file" ]; then
        echo "error: required license artifact '$required_file' is missing."
        exit 1
    fi
done

XCODEBUILD_BUILD_DIR="$PROJECT_BUILD_DIR/xcodebuild"
XCODEBUILD_DERIVED_DATA_PATH="$XCODEBUILD_BUILD_DIR/DerivedData"

PACKAGE_NAME=$1
if [ -z "$PACKAGE_NAME" ]; then
    echo "No package name provided. Using the first scheme found in the Package.swift."
    PACKAGE_NAME=$(
        cd "$PROJECT_ROOT"
        xcodebuild -list -workspace "$SWIFTPM_WORKSPACE" | awk '/Schemes:/{flag=1; next} flag && NF { print $0; exit }' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
    )
    echo "Using: $PACKAGE_NAME"
fi

(cd "$PROJECT_ROOT" && swift package resolve >/dev/null)

if [ ! -d "$SWIFT_SERVICE_CONTEXT_DIR" ]; then
    echo "error: swift-service-context checkout not found in $SWIFT_SERVICE_CONTEXT_DIR after resolving dependencies."
    exit 1
fi

bundle_licenses() {
    local artifact_root="$1"
    local license_dest="$artifact_root/Licenses"
    local third_party_dest="$license_dest/third-party/swift-service-context"

    mkdir -p "$third_party_dest"

    cp "$LICENSE_FILE" "$license_dest/LICENSE"
    cp "$LICENSES_DIR/Apache-2.0.txt" "$license_dest/Apache-2.0.txt"
    cp "$NOTICE_FILE" "$license_dest/NOTICE"
    cp "$SWIFT_SERVICE_CONTEXT_DIR/LICENSE.txt" "$third_party_dest/LICENSE.txt"
    cp "$SWIFT_SERVICE_CONTEXT_DIR/NOTICE.txt" "$third_party_dest/NOTICE.txt"
}

build_framework() {
    local sdk="$1"
    local destination="$2"
    local scheme="$3"

    local XCODEBUILD_ARCHIVE_PATH="$PROJECT_BUILD_DIR/$scheme-$sdk.xcarchive"

    rm -rf "$XCODEBUILD_ARCHIVE_PATH"

    PROTOBUFKIT_LIBRARY_TYPE=dynamic xcodebuild archive \
        -workspace "$SWIFTPM_WORKSPACE" \
        -scheme "$scheme" \
        -archivePath "$XCODEBUILD_ARCHIVE_PATH" \
        -derivedDataPath "$XCODEBUILD_DERIVED_DATA_PATH" \
        -sdk "$sdk" \
        -destination "$destination" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        INSTALL_PATH='Library/Frameworks' \
        OTHER_SWIFT_FLAGS=-no-verify-emitted-module-interface    
    
    local swiftmodule_source="$XCODEBUILD_DERIVED_DATA_PATH/Build/Intermediates.noindex/ArchiveIntermediates/$scheme/BuildProductsPath/Release-$sdk/$scheme.swiftmodule"
    if [ ! -d "$swiftmodule_source" ]; then
        swiftmodule_source="$XCODEBUILD_DERIVED_DATA_PATH/Build/Intermediates.noindex/ArchiveIntermediates/$scheme/BuildProductsPath/Release/$scheme.swiftmodule"
    fi

    local framework_path="$XCODEBUILD_ARCHIVE_PATH/Products/Library/Frameworks/$scheme.framework"
    local framework_binary="$framework_path/$scheme"

    if [ "$sdk" = "macosx" ]; then
        FRAMEWORK_MODULES_PATH="$framework_path/Versions/Current/Modules"
        framework_binary="$framework_path/Versions/Current/$scheme"
    else
        FRAMEWORK_MODULES_PATH="$framework_path/Modules"
    fi

    if [ ! -e "$framework_binary" ]; then
        echo "error: '$framework_binary' is missing. The archive only contains Modules, so xcodebuild cannot assemble an xcframework."
        echo "This usually means the Swift package product is not being built as a framework. Ensure the library is declared with type .dynamic or build a static-library xcframework via the -library flag."
        exit 1
    fi

    if [ "$sdk" = "macosx" ]; then
        mkdir -p "$FRAMEWORK_MODULES_PATH"
        cp -r \
        "$swiftmodule_source" \
        "$FRAMEWORK_MODULES_PATH/$scheme.swiftmodule"
        rm -rf "$XCODEBUILD_ARCHIVE_PATH/Products/Library/Frameworks/$scheme.framework/Modules"
        ln -s Versions/Current/Modules "$XCODEBUILD_ARCHIVE_PATH/Products/Library/Frameworks/$scheme.framework/Modules"
    else
        mkdir -p "$FRAMEWORK_MODULES_PATH"
        cp -r \
        "$swiftmodule_source" \
        "$FRAMEWORK_MODULES_PATH/$scheme.swiftmodule"
    fi
    
    # Delete private and package swiftinterface
    rm -f "$FRAMEWORK_MODULES_PATH/$scheme.swiftmodule/"*.package.swiftinterface
    rm -f "$FRAMEWORK_MODULES_PATH/$scheme.swiftmodule/"*.private.swiftinterface
}

build_framework "iphonesimulator" "generic/platform=iOS Simulator" "$PACKAGE_NAME"
build_framework "iphoneos" "generic/platform=iOS" "$PACKAGE_NAME"
build_framework "macosx" "generic/platform=macOS" "$PACKAGE_NAME"

echo "Builds completed successfully."

(
    cd "$PROJECT_BUILD_DIR"

    rm -rf "$PACKAGE_NAME.xcframework"
    xcodebuild -create-xcframework  \
        -archive "$PACKAGE_NAME-iphonesimulator.xcarchive" -framework "$PACKAGE_NAME.framework" \
        -archive "$PACKAGE_NAME-iphoneos.xcarchive" -framework "$PACKAGE_NAME.framework" \
        -archive "$PACKAGE_NAME-macosx.xcarchive" -framework "$PACKAGE_NAME.framework" \
        -output "$PACKAGE_NAME.xcframework"

    bundle_licenses "$PACKAGE_NAME.xcframework"

    cp -r "$PACKAGE_NAME-iphonesimulator.xcarchive/dSYMs" "$PACKAGE_NAME.xcframework/ios-arm64_x86_64-simulator"
    cp -r "$PACKAGE_NAME-iphoneos.xcarchive/dSYMs" "$PACKAGE_NAME.xcframework/ios-arm64"
    cp -r "$PACKAGE_NAME-macosx.xcarchive/dSYMs" "$PACKAGE_NAME.xcframework/macos-arm64_x86_64"

    zip -r "$PACKAGE_NAME.xcframework.zip" "$PACKAGE_NAME.xcframework"
)

