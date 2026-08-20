GO ?= go
GOFMT ?= gofmt
NODE ?= node
QMLLINT ?= qmllint
QUICKSHELL ?= quickshell
QML_IMPORT_PATH ?= /usr/lib/qt6/qml
XDG_DATA_HOME ?= $(HOME)/.local/share
BIN_INSTALL_DIR ?= $(HOME)/.local/bin
SHELL_INSTALL_DIR ?= $(XDG_DATA_HOME)/mitishell/shell

.PHONY: build check install run test uninstall

build:
	mkdir -p bin
	$(GO) build -o bin/mitishell ./cmd/mitishell

test:
	$(GO) test ./...
	$(GO) test -race ./...
	$(NODE) --test tests/*.test.js

check: test
	test -z "$$(find . -name '*.go' -not -path './vendor/*' -print0 | xargs -0 $(GOFMT) -l)"
	$(GO) vet ./...
	$(QMLLINT) -I $(QML_IMPORT_PATH) -I shell $$(find shell -name '*.qml' -print)
	git diff --check

run: build
	MITISHELL_BIN=$(CURDIR)/bin/mitishell MITISHELL_QS_PATH=$(CURDIR)/shell \
		$(QUICKSHELL) -n -p $(CURDIR)/shell

install: build
	install -Dm755 bin/mitishell $(BIN_INSTALL_DIR)/mitishell
	find shell -type f -print0 | while IFS= read -r -d '' file; do \
		relative="$${file#shell/}"; \
		install -Dm644 "$$file" "$(SHELL_INSTALL_DIR)/$$relative"; \
	done

uninstall:
	rm -f $(BIN_INSTALL_DIR)/mitishell
	find shell -type f -print0 | while IFS= read -r -d '' file; do \
		relative="$${file#shell/}"; \
		rm -f "$(SHELL_INSTALL_DIR)/$$relative"; \
	done
	find $(SHELL_INSTALL_DIR) -depth -type d -empty -delete 2>/dev/null || true
