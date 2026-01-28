#!/bin/bash
# LunarUI - Update external libraries
# Run this script to download/update all dependencies

set -e

LIBS_DIR="$(dirname "$0")/../LunarUI/Libs"

echo "🌙 Updating LunarUI libraries..."

# Create Libs directory if not exists
mkdir -p "$LIBS_DIR"
cd "$LIBS_DIR"

# Function to clone or update a repo
update_lib() {
    local name=$1
    local url=$2
    local branch=${3:-main}

    echo "  📦 $name..."
    if [ -d "$name" ]; then
        cd "$name"
        git fetch origin
        git reset --hard "origin/$branch" 2>/dev/null || git reset --hard origin/HEAD
        cd ..
    else
        git clone --depth 1 -b "$branch" "$url" "$name" 2>/dev/null || \
        git clone --depth 1 "$url" "$name"
    fi
    rm -rf "$name/.git"
}

# Ace3 (contains LibStub, CallbackHandler, and all Ace modules)
echo "📚 Downloading Ace3..."
if [ -d "Ace3-temp" ]; then rm -rf Ace3-temp; fi
git clone --depth 1 https://github.com/WoWUIDev/Ace3.git Ace3-temp

# Extract individual Ace3 modules
for module in LibStub CallbackHandler-1.0 AceAddon-3.0 AceDB-3.0 AceDBOptions-3.0 \
              AceEvent-3.0 AceTimer-3.0 AceConsole-3.0 AceHook-3.0 \
              AceConfig-3.0 AceConfigCmd-3.0 AceConfigDialog-3.0 AceConfigRegistry-3.0 \
              AceGUI-3.0 AceLocale-3.0; do
    echo "  📦 $module..."
    rm -rf "$module"
    cp -r "Ace3-temp/$module" .
done
rm -rf Ace3-temp

# oUF
echo "📚 Downloading oUF..."
update_lib "oUF" "https://github.com/oUF-wow/oUF.git" "main"

# LibActionButton-1.0
echo "📚 Downloading LibActionButton-1.0..."
update_lib "LibActionButton-1.0" "https://github.com/Nevcairiel/LibActionButton-1.0.git" "main"

# LibSharedMedia-3.0 (from p3lim's repo as single file)
echo "📚 Downloading LibSharedMedia-3.0..."
mkdir -p LibSharedMedia-3.0
curl -sL "https://raw.githubusercontent.com/p3lim-wow/pMinimap/master/libs/LibSharedMedia-3.0.lua" \
    -o LibSharedMedia-3.0/LibSharedMedia-3.0.lua

echo ""
echo "✅ All libraries updated!"
echo "📁 Location: $LIBS_DIR"
