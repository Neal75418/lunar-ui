#!/bin/bash
# LunarUI - Update external libraries
# Run this script to download/update all dependencies

set -uo pipefail

LIBS_DIR="$(dirname "$0")/../LunarUI/Libs"
ERRORS=0

echo "🌙 Updating LunarUI libraries..."

# Create Libs directory if not exists
mkdir -p "$LIBS_DIR"
cd "$LIBS_DIR" || exit 1

# Function to clone or update a repo
update_lib() {
    local name=$1
    local url=$2
    local branch=${3:-main}

    echo "  📦 $name..."
    if [ -d "$name" ]; then
        (
            cd "$name" || return 1
            if ! git fetch origin 2>&1; then
                echo "  ❌ Failed to fetch $name"
                return 1
            fi
            if ! git reset --hard "origin/$branch" 2>/dev/null && ! git reset --hard origin/HEAD 2>/dev/null; then
                echo "  ❌ Failed to reset $name to origin/$branch"
                return 1
            fi
        ) || { ERRORS=$((ERRORS + 1)); return 1; }
    else
        if ! git clone --depth 1 -b "$branch" "$url" "$name" 2>&1 && \
           ! git clone --depth 1 "$url" "$name" 2>&1; then
            echo "  ❌ Failed to clone $name from $url"
            ERRORS=$((ERRORS + 1))
            return 1
        fi
    fi
    rm -rf "$name/.git"
}

# Ace3 (contains LibStub, CallbackHandler, and all Ace modules)
echo "📚 Downloading Ace3..."
if [ -d "Ace3-temp" ]; then rm -rf Ace3-temp; fi
if ! git clone --depth 1 https://github.com/WoWUIDev/Ace3.git Ace3-temp 2>&1; then
    echo "❌ Failed to clone Ace3 — aborting Ace3 module extraction"
    ERRORS=$((ERRORS + 1))
else
    # Extract individual Ace3 modules
    for module in LibStub CallbackHandler-1.0 AceAddon-3.0 AceDB-3.0 AceDBOptions-3.0 \
                  AceEvent-3.0 AceTimer-3.0 AceConsole-3.0 AceHook-3.0 \
                  AceConfig-3.0 AceConfigCmd-3.0 AceConfigDialog-3.0 AceConfigRegistry-3.0 \
                  AceGUI-3.0 AceLocale-3.0; do
        echo "  📦 $module..."
        if [ ! -d "Ace3-temp/$module" ]; then
            echo "  ❌ Module $module not found in Ace3 repo"
            ERRORS=$((ERRORS + 1))
            continue
        fi
        rm -rf "$module"
        cp -r "Ace3-temp/$module" .
    done
    rm -rf Ace3-temp
fi

# oUF
echo "📚 Downloading oUF..."
update_lib "oUF" "https://github.com/oUF-wow/oUF.git" "main"

# LibActionButton-1.0
echo "📚 Downloading LibActionButton-1.0..."
update_lib "LibActionButton-1.0" "https://github.com/Nevcairiel/LibActionButton-1.0.git" "main"

# LibSharedMedia-3.0 (from p3lim's repo as single file)
echo "📚 Downloading LibSharedMedia-3.0..."
mkdir -p LibSharedMedia-3.0
if ! curl -sfL "https://raw.githubusercontent.com/p3lim-wow/pMinimap/master/libs/LibSharedMedia-3.0.lua" \
    -o LibSharedMedia-3.0/LibSharedMedia-3.0.lua; then
    echo "  ❌ Failed to download LibSharedMedia-3.0"
    ERRORS=$((ERRORS + 1))
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "⚠️  Finished with $ERRORS error(s). Check output above."
    exit 1
else
    echo "✅ All libraries updated!"
fi
echo "📁 Location: $LIBS_DIR"
