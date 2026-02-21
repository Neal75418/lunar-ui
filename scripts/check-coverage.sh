#!/usr/bin/env bash
# 檢查 luacov 覆蓋率是否達到最低門檻
# 用法: ./scripts/check-coverage.sh [threshold]
# 預設門檻: 25%
set -euo pipefail

THRESHOLD=${1:-25}
REPORT="luacov.report.out"

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

PASS=$(awk "BEGIN { print ($COVERAGE >= $THRESHOLD) ? 1 : 0 }")

if [ "$PASS" -eq 1 ]; then
    echo "Coverage: ${COVERAGE}% >= ${THRESHOLD}% threshold - PASSED"
else
    echo "Coverage: ${COVERAGE}% < ${THRESHOLD}% threshold - FAILED"
    exit 1
fi
