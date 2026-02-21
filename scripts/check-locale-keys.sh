#!/usr/bin/env bash
# Lint: check locale key parity between enUS and zhTW
# Portable — uses sed instead of grep -P for macOS/Linux compatibility
set -euo pipefail

ENFILE="LunarUI/Locales/enUS.lua"
ZHFILE="LunarUI/Locales/zhTW.lua"

# Extract L["key"] patterns using sed (portable across macOS and Linux)
extract_keys() {
    sed -n 's/.*L\["\([^"]*\)"\].*/\1/p' "$1" | sort -u
}

en_keys=$(extract_keys "$ENFILE")
zh_keys=$(extract_keys "$ZHFILE")

en_only=$(comm -23 <(echo "$en_keys") <(echo "$zh_keys"))
zh_only=$(comm -13 <(echo "$en_keys") <(echo "$zh_keys"))

exit_code=0

if [ -n "$en_only" ]; then
    echo "ERROR: Keys in enUS.lua missing from zhTW.lua:"
    echo "$en_only" | sed 's/^/  /'
    exit_code=1
fi

if [ -n "$zh_only" ]; then
    echo "ERROR: Keys in zhTW.lua missing from enUS.lua:"
    echo "$zh_only" | sed 's/^/  /'
    exit_code=1
fi

if [ $exit_code -eq 0 ]; then
    key_count=$(echo "$en_keys" | wc -l | tr -d ' ')
    echo "Locale key parity check passed! ($key_count keys)"
fi

exit $exit_code
