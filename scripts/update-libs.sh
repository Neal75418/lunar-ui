#!/bin/bash
# LunarUI - Update external libraries
# Pulls latest from main branches, following the "always latest" philosophy.
# Run this script after git clone or when you want to refresh libs.

set -uo pipefail

LIBS_DIR="$(cd "$(dirname "$0")/.." && pwd)/LunarUI/Libs"
ERRORS=0

echo "🌙 Updating LunarUI libraries..."
mkdir -p "$LIBS_DIR"
cd "$LIBS_DIR" || exit 1

# Clone a repo fresh. CRITICAL: always rm -rf first so we never fall into a
# stale dir whose missing .git causes git commands to walk up to the parent
# lunar-ui repo (which would fetch/reset the wrong tree!).
fetch_repo() {
    local name=$1 url=$2 branch=${3:-main}
    echo "  📦 $name..."
    rm -rf "$name"
    if ! git clone --depth 1 -b "$branch" "$url" "$name" >/dev/null 2>&1 && \
       ! git clone --depth 1 "$url" "$name" >/dev/null 2>&1; then
        echo "  ❌ Failed to clone $name from $url"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
    rm -rf "$name/.git"
}

# ---- Ace3 ----
# Strategy: clone the whole Ace3 repo, then copy each top-level module dir.
# AceConfig-3.0 contains its sub-modules (AceConfigCmd/Dialog/Registry) as
# nested dirs — TOC files load them via relative XML path, so we copy the
# whole AceConfig-3.0 tree rather than flattening sub-modules.
echo "📚 Downloading Ace3..."
rm -rf Ace3-temp
if ! git clone --depth 1 https://github.com/WoWUIDev/Ace3.git Ace3-temp >/dev/null 2>&1; then
    echo "❌ Failed to clone Ace3"
    ERRORS=$((ERRORS + 1))
else
    for module in LibStub CallbackHandler-1.0 AceAddon-3.0 AceDB-3.0 AceDBOptions-3.0 \
                  AceEvent-3.0 AceTimer-3.0 AceConsole-3.0 AceHook-3.0 \
                  AceConfig-3.0 AceGUI-3.0 AceLocale-3.0; do
        if [ -d "Ace3-temp/$module" ]; then
            echo "  📦 $module..."
            rm -rf "$module"
            cp -r "Ace3-temp/$module" .
        else
            echo "  ❌ Module $module not found in Ace3 repo"
            ERRORS=$((ERRORS + 1))
        fi
    done
    rm -rf Ace3-temp
fi

# ---- oUF ----
echo "📚 Downloading oUF..."
fetch_repo "oUF" "https://github.com/oUF-wow/oUF.git" "main"

# ---- LibActionButton-1.0 ----
echo "📚 Downloading LibActionButton-1.0..."
fetch_repo "LibActionButton-1.0" "https://github.com/Nevcairiel/LibActionButton-1.0.git" "main"

# ---- LibSharedMedia-3.0 ----
# LSM has no git source — upstream is Wowace SVN. We download the latest
# release zip directly from Wowace. The file ID below needs manual bumping
# when LSM releases a new version — check https://www.wowace.com/projects/libsharedmedia-3-0/files
# and update LSM_FILE_ID accordingly. LSM updates are rare (roughly once per
# WoW expansion), so manual tracking is acceptable.
echo "📚 Downloading LibSharedMedia-3.0..."
LSM_FILE_ID="7908455"  # v12.0.0 — 2026-04-10
LSM_TMP=$(mktemp -d)
if curl -sfL -o "$LSM_TMP/lsm.zip" \
    "https://www.wowace.com/projects/libsharedmedia-3-0/files/${LSM_FILE_ID}/download" && \
    unzip -q "$LSM_TMP/lsm.zip" -d "$LSM_TMP"; then
    # Zip structure: LibSharedMedia-3.0/LibSharedMedia-3.0/LibSharedMedia-3.0.lua
    # We want the innermost dir as our LunarUI/Libs/LibSharedMedia-3.0
    if [ -d "$LSM_TMP/LibSharedMedia-3.0/LibSharedMedia-3.0" ]; then
        rm -rf LibSharedMedia-3.0
        cp -r "$LSM_TMP/LibSharedMedia-3.0/LibSharedMedia-3.0" ./LibSharedMedia-3.0
    else
        echo "  ❌ Unexpected LibSharedMedia zip structure"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  ❌ Failed to download LibSharedMedia-3.0"
    ERRORS=$((ERRORS + 1))
fi
rm -rf "$LSM_TMP"

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "⚠️  Finished with $ERRORS error(s). Check output above."
    exit 1
else
    echo "✅ All libraries updated!"
fi
echo "📁 Location: $LIBS_DIR"
