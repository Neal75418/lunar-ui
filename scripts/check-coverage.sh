#!/usr/bin/env bash
# 檢查 luacov 覆蓋率，支援 ratchet 模式（不可退步）
#
# 用法：
#   ./scripts/check-coverage.sh            — ratchet 模式，讀 .coverage-baseline
#   ./scripts/check-coverage.sh 43         — 固定門檻模式（legacy）
#   ./scripts/check-coverage.sh --update   — 將當前覆蓋率寫入 .coverage-baseline
#
# Ratchet 模式會比對當前覆蓋率與 .coverage-baseline：
#   - 低於 baseline → FAIL
#   - 高於 baseline + RATCHET_DELTA → 提示更新 baseline
set -euo pipefail

REPORT="luacov.report.out"
BASELINE_FILE=".coverage-baseline"
RATCHET_DELTA=1.0

if [ ! -f "$REPORT" ]; then
    echo "ERROR: $REPORT not found. Run busted --coverage + luacov first."
    exit 1
fi

# luacov 報告最後一行格式: "Total           xxx / yyy   zz.zz%"
COVERAGE=$(tail -1 "$REPORT" | grep -oE '[0-9]+\.[0-9]+%' | head -1 | tr -d '%')
if [ -z "$COVERAGE" ]; then
    echo "ERROR: Could not parse coverage from $REPORT"
    exit 1
fi

# 參數數量上限：最多一個
if [ $# -gt 1 ]; then
    echo "ERROR: too many arguments. Usage: $0 [<threshold> | --update]"
    exit 2
fi

# --update 模式：把當前覆蓋率寫入 baseline
if [ "${1:-}" = "--update" ]; then
    printf '%s\n' "$COVERAGE" > "$BASELINE_FILE"
    echo "Baseline updated: ${COVERAGE}% → $BASELINE_FILE"
    echo "Remember to commit $BASELINE_FILE."
    exit 0
fi

# 決定門檻來源
if [ $# -eq 1 ]; then
    THRESHOLD="$1"
    # 拒絕未知 flag（避免 awk 把 "--foo" 當 0 導致 false PASS）
    case "$THRESHOLD" in
        -*)
            echo "ERROR: unknown flag '$THRESHOLD'. Usage: $0 [<threshold> | --update]"
            exit 2
            ;;
    esac
    # 驗證為合法數字（整數或小數）
    if ! printf '%s' "$THRESHOLD" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
        echo "ERROR: threshold '$THRESHOLD' is not a valid number"
        exit 2
    fi
    MODE="fixed"
else
    if [ ! -f "$BASELINE_FILE" ]; then
        echo "ERROR: $BASELINE_FILE not found."
        echo "       Run './scripts/check-coverage.sh --update' to initialize it."
        exit 1
    fi
    THRESHOLD=$(tr -d '[:space:]' < "$BASELINE_FILE")
    if ! printf '%s' "$THRESHOLD" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
        echo "ERROR: $BASELINE_FILE contains invalid content: '$THRESHOLD'"
        exit 1
    fi
    MODE="ratchet"
fi

PASS=$(awk "BEGIN { print ($COVERAGE >= $THRESHOLD) ? 1 : 0 }")

if [ "$PASS" -eq 1 ]; then
    echo "Coverage: ${COVERAGE}% >= ${THRESHOLD}% ($MODE) - PASSED"
    if [ "$MODE" = "ratchet" ]; then
        SHOULD_UPDATE=$(awk "BEGIN { print ($COVERAGE >= $THRESHOLD + $RATCHET_DELTA) ? 1 : 0 }")
        if [ "$SHOULD_UPDATE" -eq 1 ]; then
            echo ""
            echo "HINT: Coverage exceeds baseline by >= ${RATCHET_DELTA}%."
            echo "      Run './scripts/check-coverage.sh --update' and commit $BASELINE_FILE"
            echo "      to ratchet the baseline up."
        fi
    fi
else
    echo "Coverage: ${COVERAGE}% < ${THRESHOLD}% ($MODE) - FAILED"
    if [ "$MODE" = "ratchet" ]; then
        echo ""
        echo "Coverage regressed below the committed baseline."
        echo "Add or restore tests to bring coverage back to ${THRESHOLD}% or higher."
    fi
    exit 1
fi
