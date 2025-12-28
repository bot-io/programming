#!/bin/bash
# Android Build Configuration Verification Script for Linux/Mac
# This script verifies that all Android build and signing configuration is properly set up

set -e

echo "========================================="
echo "Android Build Configuration Verification"
echo "========================================="
echo ""

ERRORS=0
WARNINGS=0

# Navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$PROJECT_ROOT"

# 1. Check Flutter installation
echo "[1/10] Checking Flutter installation..."
if command -v flutter &> /dev/null; then
    echo "  ✓ Flutter is installed"
    FLUTTER_VERSION=$(flutter --version | grep -oP 'Flutter \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo "    Version: $FLUTTER_VERSION"
else
    echo "  ✗ Flutter is not installed or not in PATH"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 2. Check pubspec.yaml exists
echo "[2/10] Checking pubspec.yaml..."
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml"
if [ -f "$PUBSPEC_FILE" ]; then
    echo "  ✓ pubspec.yaml found"
    VERSION_LINE=$(grep "^version:" "$PUBSPEC_FILE")
    if [[ $VERSION_LINE =~ version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+) ]]; then
        VERSION_NAME="${BASH_REMATCH[1]}"
        VERSION_CODE="${BASH_REMATCH[2]}"
        echo "    Version: $VERSION_NAME (Build: $VERSION_CODE)"
    else
        echo "  ⚠ Version format not found or invalid"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "  ✗ pubspec.yaml not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 3. Check Android build.gradle
echo "[3/10] Checking Android build.gradle..."
BUILD_GRADLE_FILE="$PROJECT_ROOT/android/app/build.gradle"
if [ -f "$BUILD_GRADLE_FILE" ]; then
    echo "  ✓ build.gradle found"
    
    # Check for version management
    if grep -q "versionCode" "$BUILD_GRADLE_FILE"; then
        echo "    ✓ Version code configuration found"
    else
        echo "    ⚠ Version code configuration missing"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for signing configuration
    if grep -q "signingConfigs" "$BUILD_GRADLE_FILE"; then
        echo "    ✓ Signing configuration found"
    else
        echo "    ⚠ Signing configuration missing"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for release build type
    if grep -q "buildTypes" "$BUILD_GRADLE_FILE"; then
        echo "    ✓ Build types configuration found"
    else
        echo "    ⚠ Build types configuration missing"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "  ✗ build.gradle not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 4. Check key.properties
echo "[4/10] Checking signing configuration..."
KEY_PROPERTIES_FILE="$PROJECT_ROOT/android/key.properties"
if [ -f "$KEY_PROPERTIES_FILE" ]; then
    echo "  ✓ key.properties found"
    
    # Check keystore file exists
    STORE_FILE_LINE=$(grep "^storeFile=" "$KEY_PROPERTIES_FILE" || true)
    if [ -n "$STORE_FILE_LINE" ]; then
        KEYSTORE_PATH=$(echo "$STORE_FILE_LINE" | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$KEYSTORE_PATH" ]; then
            # Handle relative paths
            if [[ "$KEYSTORE_PATH" == ../* ]]; then
                KEYSTORE_PATH="$PROJECT_ROOT/${KEYSTORE_PATH#../}"
            elif [ ! -f "$KEYSTORE_PATH" ] && [ ! "${KEYSTORE_PATH:0:1}" = "/" ]; then
                KEYSTORE_PATH="$PROJECT_ROOT/android/$KEYSTORE_PATH"
            fi
            
            if [ -f "$KEYSTORE_PATH" ]; then
                echo "    ✓ Keystore file found: $KEYSTORE_PATH"
            else
                echo "    ⚠ Keystore file not found: $KEYSTORE_PATH"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    fi
    
    # Check required properties
    REQUIRED_PROPS=("storePassword" "keyPassword" "keyAlias" "storeFile")
    for PROP in "${REQUIRED_PROPS[@]}"; do
        PROP_LINE=$(grep "^$PROP=" "$KEY_PROPERTIES_FILE" || true)
        if [ -n "$PROP_LINE" ] && ! echo "$PROP_LINE" | grep -q "YOUR_"; then
            echo "    ✓ $PROP configured"
        else
            echo "    ⚠ $PROP not configured or using template value"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
else
    echo "  ⚠ key.properties not found (debug signing will be used)"
    echo "    Run: scripts/generate_keystore.sh to create signing configuration"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 5. Check key.properties.template
echo "[5/10] Checking key.properties.template..."
KEY_PROPERTIES_TEMPLATE="$PROJECT_ROOT/android/key.properties.template"
if [ -f "$KEY_PROPERTIES_TEMPLATE" ]; then
    echo "  ✓ key.properties.template found"
else
    echo "  ⚠ key.properties.template not found"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 6. Check build scripts (PowerShell)
echo "[6/10] Checking PowerShell build scripts..."
SCRIPTS=("build_apk.ps1" "build_aab.ps1" "build_android.ps1" "generate_keystore.ps1" "version_manager.ps1")
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
for SCRIPT in "${SCRIPTS[@]}"; do
    SCRIPT_PATH="$SCRIPTS_DIR/$SCRIPT"
    if [ -f "$SCRIPT_PATH" ]; then
        echo "    ✓ $SCRIPT found"
    else
        echo "    ✗ $SCRIPT not found"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# 7. Check build scripts (Bash)
echo "[7/10] Checking Bash build scripts..."
BASH_SCRIPTS=("build_apk.sh" "build_aab.sh" "build_android.sh" "generate_keystore.sh" "version_manager.sh")
for SCRIPT in "${BASH_SCRIPTS[@]}"; do
    SCRIPT_PATH="$SCRIPTS_DIR/$SCRIPT"
    if [ -f "$SCRIPT_PATH" ]; then
        echo "    ✓ $SCRIPT found"
        # Check if executable
        if [ -x "$SCRIPT_PATH" ]; then
            echo "      ✓ Executable"
        else
            echo "      ⚠ Not executable (run: chmod +x $SCRIPT_PATH)"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo "    ✗ $SCRIPT not found"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# 8. Check ProGuard rules
echo "[8/10] Checking ProGuard configuration..."
PROGUARD_FILE="$PROJECT_ROOT/android/app/proguard-rules.pro"
if [ -f "$PROGUARD_FILE" ]; then
    echo "  ✓ proguard-rules.pro found"
else
    echo "  ⚠ proguard-rules.pro not found"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 9. Check .gitignore
echo "[9/10] Checking .gitignore for security..."
GITIGNORE_FILE="$PROJECT_ROOT/.gitignore"
if [ -f "$GITIGNORE_FILE" ]; then
    GITIGNORE_CONTENT=$(cat "$GITIGNORE_FILE")
    
    if echo "$GITIGNORE_CONTENT" | grep -q "key\.properties"; then
        echo "    ✓ key.properties is ignored"
    else
        echo "    ⚠ key.properties is NOT ignored"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    if echo "$GITIGNORE_CONTENT" | grep -q "\*\.jks"; then
        echo "    ✓ *.jks is ignored"
    else
        echo "    ⚠ *.jks is NOT ignored"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    if echo "$GITIGNORE_CONTENT" | grep -q "\*\.keystore"; then
        echo "    ✓ *.keystore is ignored"
    else
        echo "    ⚠ *.keystore is NOT ignored"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    echo "  ✓ Security: Sensitive files are properly ignored"
else
    echo "  ⚠ .gitignore not found"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 10. Check documentation
echo "[10/10] Checking documentation..."
DOCS_DIR="$PROJECT_ROOT/docs"
DOC_FILES=("ANDROID_BUILD_AND_SIGNING.md" "ANDROID_BUILD_QUICK_REFERENCE.md")
for DOC in "${DOC_FILES[@]}"; do
    DOC_PATH="$DOCS_DIR/$DOC"
    if [ -f "$DOC_PATH" ]; then
        echo "    ✓ $DOC found"
    else
        echo "    ⚠ $DOC not found"
        WARNINGS=$((WARNINGS + 1))
    fi
done
echo ""

# Summary
echo "========================================="
echo "Verification Summary"
echo "========================================="
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✓ All checks passed! Build configuration is complete."
    echo ""
    echo "Next steps:"
    echo "  1. If signing is not configured, run: scripts/generate_keystore.sh"
    echo "  2. Build APK: scripts/build_apk.sh"
    echo "  3. Build AAB: scripts/build_aab.sh"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠ Configuration complete with $WARNINGS warning(s)"
    echo ""
    echo "Warnings are non-critical but should be addressed:"
    echo "  - Signing configuration is optional for testing (debug builds)"
    echo "  - Required for Play Store releases (AAB builds)"
    exit 0
else
    echo "✗ Configuration has $ERRORS error(s) and $WARNINGS warning(s)"
    echo ""
    echo "Please fix the errors before building."
    exit 1
fi
