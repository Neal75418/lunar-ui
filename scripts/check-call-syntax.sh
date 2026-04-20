#!/usr/bin/env bash
# Lint: detect colon-syntax calls to dot-defined LunarUI functions
#
# Background: functions declared as `function LunarUI.Name()` (dot) must be
# called as `LunarUI.Name()` (dot). Calling with `LunarUI:Name()` (colon)
# silently passes the LunarUI table as an extra first argument — works today
# only if the function ignores its first arg, but becomes a silent bug the
# moment anyone adds a real first parameter.
#
# Ace3 mixin methods (defined with colon, e.g. Print/RegisterModule/ApplyHUDScale)
# are correctly called with colon and are NOT flagged by this check.
#
# This guard was added after cleaning up 41 such mismatches (commit 18f2635).
set -euo pipefail

cd "$(dirname "$0")/.."

# 1. Find all dot-defined LunarUI function names.
#    Matches: `function LunarUI.Foo(` → captures `Foo`
#    Excludes Libs/ (third-party addons register their own methods).
DOT_DEFINED=$(grep -rEho '^function LunarUI\.[A-Z][A-Za-z]*' \
    LunarUI/ LunarUI_Options/ LunarUI_Debug/ \
    --include='*.lua' 2>/dev/null \
    | sed -E 's/^function LunarUI\.//' \
    | sort -u)

if [ -z "$DOT_DEFINED" ]; then
    echo "WARN: no dot-defined LunarUI.* functions found. Is this the right repo?"
    exit 0
fi

# 2. Also include dot-assigned exports: `LunarUI.Foo = localFoo`
DOT_ASSIGNED=$(grep -rEho '^LunarUI\.[A-Z][A-Za-z]* =' \
    LunarUI/ LunarUI_Options/ LunarUI_Debug/ \
    --include='*.lua' 2>/dev/null \
    | sed -E 's/^LunarUI\.//' \
    | sed -E 's/ =$//' \
    | sort -u)

NAMES=$(printf '%s\n%s\n' "$DOT_DEFINED" "$DOT_ASSIGNED" | sort -u)

# 3. Grep for colon-syntax calls to any of these names.
violations=0
while IFS= read -r name; do
    [ -z "$name" ] && continue
    # Match `LunarUI:Name(` anywhere (except Libs/).
    # -F fixed-string on the colon-prefixed name avoids regex interpretation.
    hits=$(grep -rHn "LunarUI:${name}(" \
        LunarUI/ LunarUI_Options/ LunarUI_Debug/ spec/ \
        --include='*.lua' 2>/dev/null || true)
    if [ -n "$hits" ]; then
        if [ $violations -eq 0 ]; then
            echo "ERROR: dot-defined function called with colon syntax:"
            echo ""
        fi
        echo "  $name (defined with dot, must be called LunarUI.${name}(...)):"
        while IFS= read -r line; do
            echo "    $line"
        done <<<"$hits"
        echo ""
        violations=$((violations + 1))
    fi
done <<<"$NAMES"

if [ $violations -gt 0 ]; then
    echo "Found $violations dot-defined function(s) called with colon."
    echo "Fix: replace 'LunarUI:FuncName(' with 'LunarUI.FuncName(' at the"
    echo "listed locations. See commit 18f2635 for context."
    exit 1
fi

echo "Call syntax check passed (no colon-on-dot mismatches)."
