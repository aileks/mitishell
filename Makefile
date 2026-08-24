GO ?= go
GOFMT ?= gofmt
NODE ?= node
QMLLINT ?= /usr/lib/qt6/bin/qmllint
QUICKSHELL ?= quickshell
QML_IMPORT_PATH ?= /usr/lib/qt6/qml
XDG_DATA_HOME ?= $(HOME)/.local/share
BIN_INSTALL_DIR ?= $(HOME)/.local/bin
SHELL_INSTALL_DIR ?= $(XDG_DATA_HOME)/mitishell/shell
DESKTOP_INSTALL_DIR ?= $(XDG_DATA_HOME)/applications

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
	install -Dm644 data/mitishell.desktop $(DESKTOP_INSTALL_DIR)/mitishell.desktop
	# Remove the previous install first so deleted source files do not
	# linger; the directory holds only program files.
	rm -rf $(SHELL_INSTALL_DIR)
	find shell -type f -print0 | while IFS= read -r -d '' file; do \
		relative="$${file#shell/}"; \
		install -Dm644 "$$file" "$(SHELL_INSTALL_DIR)/$$relative"; \
	done

uninstall:
	rm -f $(BIN_INSTALL_DIR)/mitishell
	rm -f $(DESKTOP_INSTALL_DIR)/mitishell.desktop
	# The data directory holds only installed program files; user config
	# and cache live elsewhere and stay untouched.
	rm -rf $(XDG_DATA_HOME)/mitishell
