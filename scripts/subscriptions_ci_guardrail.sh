#!/bin/bash

# 🚦 Subscription SSOT CI Guardrail Script
# This script ensures no subscription drift occurs in the codebase
# Run this in CI/CD pipeline to fail builds if violations are found

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXIT_CODE=0

echo "🚦 Running Subscription SSOT Guardrail Checks..."
echo "Project root: $PROJECT_ROOT"
echo ""

# Expected product IDs (SSOT)
EXPECTED_IDS=(
    "com.KhamariThompson.100Days.monthlyv2"
    "com.KhamariThompson.100Days.annualv1"
)

# Legacy/incorrect product IDs (should NOT exist)
FORBIDDEN_IDS=(
    "com.100days.founders.annual"
    "com.100days.annual"
    "com.100days.monthly"
    "com.KhamariThompson.100Days.monthly"  # Old version
)

# Files to exclude from search
EXCLUDE_PATTERNS=(
    "*/MIGRATION.md"
    "*/DESIGN.md"
    "*/SUBSCRIPTION_SSOT_IMPLEMENTATION.md"
    "*/.build/*"
    "*/DerivedData/*"
    "*/Pods/*"
    "*/.git/*"
    "*/scripts/*"
)

# Build exclude grep pattern
EXCLUDE_GREP=""
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    EXCLUDE_GREP="$EXCLUDE_GREP --exclude=$pattern"
done

# ====================================================================
# Check 1: No forbidden product IDs in code
# ====================================================================

echo "✅ Check 1: Scanning for forbidden product IDs..."

FORBIDDEN_FOUND=false
for id in "${FORBIDDEN_IDS[@]}"; do
    echo "   Checking for: $id"

    # Search in .swift files only, exclude documentation
    if grep -r "$id" "$PROJECT_ROOT" \
        --include="*.swift" \
        --exclude-dir=".build" \
        --exclude-dir="DerivedData" \
        --exclude-dir="Pods" \
        --exclude-dir=".git" \
        --exclude-dir="scripts" \
        --quiet; then

        echo "   ❌ FOUND forbidden product ID: $id"
        echo "   Files containing it:"
        grep -r "$id" "$PROJECT_ROOT" \
            --include="*.swift" \
            --exclude-dir=".build" \
            --exclude-dir="DerivedData" \
            --exclude-dir="Pods" \
            --exclude-dir=".git" \
            --exclude-dir="scripts" \
            -l | sed 's/^/      /'

        FORBIDDEN_FOUND=true
        EXIT_CODE=1
    fi
done

if [ "$FORBIDDEN_FOUND" = false ]; then
    echo "   ✅ No forbidden product IDs found"
fi

echo ""

# ====================================================================
# Check 2: Expected product IDs exist
# ====================================================================

echo "✅ Check 2: Verifying expected product IDs exist..."

MISSING_IDS=()
for id in "${EXPECTED_IDS[@]}"; do
    echo "   Checking for: $id"

    if ! grep -r "$id" "$PROJECT_ROOT" \
        --include="*.swift" \
        --exclude-dir=".build" \
        --exclude-dir="DerivedData" \
        --exclude-dir="Pods" \
        --exclude-dir=".git" \
        --quiet; then

        echo "   ⚠️  Expected product ID NOT found: $id"
        MISSING_IDS+=("$id")
        EXIT_CODE=1
    else
        echo "   ✅ Found: $id"
    fi
done

if [ ${#MISSING_IDS[@]} -gt 0 ]; then
    echo "   ❌ Missing expected product IDs: ${MISSING_IDS[*]}"
fi

echo ""

# ====================================================================
# Check 3: Only ONE paywall view exists
# ====================================================================

echo "✅ Check 3: Checking for duplicate paywall views..."

PAYWALL_FILES=$(find "$PROJECT_ROOT" -name "*Paywall*.swift" -type f \
    -not -path "*/.build/*" \
    -not -path "*/DerivedData/*" \
    -not -path "*/Pods/*" \
    -not -path "*/.git/*" \
    -not -path "*/Subscription/*" | wc -l | tr -d ' ')

SUBSCRIPTION_PAYWALL=$(find "$PROJECT_ROOT/100DaysRebuild/Subscription/UI" -name "PaywallView.swift" -type f 2>/dev/null | wc -l | tr -d ' ')

echo "   Paywall files outside Subscription module: $PAYWALL_FILES"
echo "   Paywall files in Subscription/UI: $SUBSCRIPTION_PAYWALL"

if [ "$PAYWALL_FILES" -gt 0 ]; then
    echo "   ❌ DUPLICATE PAYWALLS FOUND outside Subscription module:"
    find "$PROJECT_ROOT" -name "*Paywall*.swift" -type f \
        -not -path "*/.build/*" \
        -not -path "*/DerivedData/*" \
        -not -path "*/Pods/*" \
        -not -path "*/.git/*" \
        -not -path "*/Subscription/*" | sed 's/^/      /'
    EXIT_CODE=1
fi

if [ "$SUBSCRIPTION_PAYWALL" -eq 0 ]; then
    echo "   ⚠️  Warning: PaywallView.swift not found in Subscription/UI"
    echo "   This is expected if you haven't created it yet"
fi

if [ "$PAYWALL_FILES" -eq 0 ] && [ "$SUBSCRIPTION_PAYWALL" -eq 1 ]; then
    echo "   ✅ Only one paywall exists in Subscription/UI"
fi

echo ""

# ====================================================================
# Check 4: Legacy subscription properties not used
# ====================================================================

echo "✅ Check 4: Checking for legacy subscription properties..."

LEGACY_PROPS=(
    "isProUser"
    "hasSubscription"
    "subscriptionLevel"
    "paywallUnlocked"
    "effectiveIsProUser"
    "hasProAccess"
)

LEGACY_FOUND=false
for prop in "${LEGACY_PROPS[@]}"; do
    # Check outside Subscription module only
    MATCHES=$(find "$PROJECT_ROOT" -name "*.swift" -type f \
        -not -path "*/.build/*" \
        -not -path "*/DerivedData/*" \
        -not -path "*/Pods/*" \
        -not -path "*/.git/*" \
        -not -path "*/Subscription/*" \
        -not -path "*/Migration/*" \
        -not -path "*/Services/SubscriptionService.swift" \
        -not -path "*/Services/Entitlements.swift" \
        -exec grep -l "\.$prop\|var $prop\|let $prop" {} \; 2>/dev/null)

    if [ -n "$MATCHES" ]; then
        echo "   ⚠️  Legacy property '$prop' found outside Subscription module:"
        echo "$MATCHES" | sed 's/^/      /'
        LEGACY_FOUND=true
        # Don't fail build for this, just warn
    fi
done

if [ "$LEGACY_FOUND" = false ]; then
    echo "   ✅ No legacy properties found outside Subscription module"
fi

echo ""

# ====================================================================
# Check 5: Subscription code only in Subscription module
# ====================================================================

echo "✅ Check 5: Verifying subscription code is in Subscription module..."

# Check for RevenueCat imports outside Subscription module
RC_IMPORTS=$(find "$PROJECT_ROOT" -name "*.swift" -type f \
    -not -path "*/.build/*" \
    -not -path "*/DerivedData/*" \
    -not -path "*/Pods/*" \
    -not -path "*/.git/*" \
    -not -path "*/Subscription/*" \
    -not -path "*/App.swift" \
    -exec grep -l "import RevenueCat" {} \; 2>/dev/null)

if [ -n "$RC_IMPORTS" ]; then
    echo "   ⚠️  RevenueCat imports found outside Subscription module:"
    echo "$RC_IMPORTS" | sed 's/^/      /'
    echo "   Consider moving subscription logic to Subscription module"
    # Don't fail, just warn
else
    echo "   ✅ RevenueCat imports only in Subscription module (or App.swift)"
fi

echo ""

# ====================================================================
# Summary
# ====================================================================

echo "=================================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ ALL CHECKS PASSED - Subscription SSOT is clean!"
    echo "=================================================="
else
    echo "❌ CHECKS FAILED - Fix violations above"
    echo "=================================================="
    echo ""
    echo "Common fixes:"
    echo "  1. Remove forbidden product IDs from code"
    echo "  2. Add expected product IDs if missing"
    echo "  3. Delete duplicate paywall files"
    echo "  4. Move legacy code to Migration module"
    echo ""
fi

exit $EXIT_CODE
