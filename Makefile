.PHONY: test lint format format-fix coverage coverage-update check clean locale-check call-syntax-check help

help:
	@echo "LunarUI Development Commands"
	@echo "  make test             Run unit tests"
	@echo "  make lint             Run luacheck"
	@echo "  make format           Check stylua formatting"
	@echo "  make format-fix       Auto-fix formatting"
	@echo "  make coverage         Run tests + ratchet check against .coverage-baseline"
	@echo "  make coverage-update  Update .coverage-baseline to current coverage"
	@echo "  make check            Run all checks (lint + format + locale + test)"
	@echo "  make locale-check     Check locale key parity"
	@echo "  make call-syntax-check Check colon/dot call syntax consistency"
	@echo "  make clean            Remove generated files"

test:
	busted spec/

lint:
	luacheck .

format:
	stylua --check --glob '**/*.lua' --glob '!LunarUI/Libs/**' .

format-fix:
	stylua --glob '**/*.lua' --glob '!LunarUI/Libs/**' .

coverage:
	busted --coverage spec/ && luacov
	@tail -30 luacov.report.out 2>/dev/null || true
	@./scripts/check-coverage.sh

coverage-update:
	busted --coverage spec/ && luacov
	@./scripts/check-coverage.sh --update

check: lint format locale-check call-syntax-check test

locale-check:
	./scripts/check-locale-keys.sh

call-syntax-check:
	./scripts/check-call-syntax.sh

clean:
	rm -f luacov.stats.out luacov.report.out
