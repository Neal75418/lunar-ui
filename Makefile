.PHONY: test lint format format-fix coverage check clean locale-check help

help:
	@echo "LunarUI Development Commands"
	@echo "  make test         Run unit tests"
	@echo "  make lint         Run luacheck"
	@echo "  make format       Check stylua formatting"
	@echo "  make format-fix   Auto-fix formatting"
	@echo "  make coverage     Run tests with coverage report"
	@echo "  make check        Run all checks (lint + format + test)"
	@echo "  make locale-check Check locale key parity"
	@echo "  make clean        Remove generated files"

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
	@./scripts/check-coverage.sh 33

check: lint format test

locale-check:
	./scripts/check-locale-keys.sh

clean:
	rm -f luacov.stats.out luacov.report.out
