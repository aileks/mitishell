GO ?= go
GOFMT ?= gofmt
NODE ?= node
QMLLINT ?= /usr/lib/qt6/bin/qmllint
QMLTESTRUNNER ?= /usr/lib/qt6/bin/qmltestrunner
QUICKSHELL ?= quickshell
QML_IMPORT_PATH ?= /usr/lib/qt6/qml
export QML_IMPORT_PATH
XDG_DATA_HOME ?= $(HOME)/.local/share
BIN_INSTALL_DIR ?= $(HOME)/.local/bin
SHELL_INSTALL_DIR ?= $(XDG_DATA_HOME)/mitishell/shell
DESKTOP_INSTALL_DIR ?= $(XDG_DATA_HOME)/applications

.PHONY: build check install install-prebuilt run test uninstall

build:
	mkdir -p bin
	$(GO) build -o bin/mitishell ./cmd/mitishell

test:
	$(GO) test ./...
	$(GO) test -race ./...
	$(NODE) --test tests/*.test.js
	QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
		$(QMLTESTRUNNER) -import shell -input tests/qml

check: test
	test -z "$$(find . -name '*.go' -not -path './vendor/*' -print0 | xargs -0 $(GOFMT) -l)"
	$(GO) vet ./...
	$(QMLLINT) -E -I shell $$(find shell -name '*.qml' -print)
	git diff --check

run: build
	MITISHELL_BIN=$(CURDIR)/bin/mitishell MITISHELL_QS_PATH=$(CURDIR)/shell \
		$(QUICKSHELL) -n -p $(CURDIR)/shell

install: build
	$(MAKE) --no-print-directory install-prebuilt

install-prebuilt:
	test -x bin/mitishell
	install -Dm755 bin/mitishell $(BIN_INSTALL_DIR)/mitishell
	install -Dm644 data/mitishell.desktop $(DESKTOP_INSTALL_DIR)/mitishell.desktop
	rm -rf $(SHELL_INSTALL_DIR).staging
	find shell -type f -print0 | while IFS= read -r -d '' file; do \
		relative="$${file#shell/}"; \
		install -Dm644 "$$file" "$(SHELL_INSTALL_DIR).staging/$$relative"; \
	done
	rm -rf $(SHELL_INSTALL_DIR)
	mv $(SHELL_INSTALL_DIR).staging $(SHELL_INSTALL_DIR)

uninstall:
	rm -f $(BIN_INSTALL_DIR)/mitishell
	rm -f $(DESKTOP_INSTALL_DIR)/mitishell.desktop
	rm -rf $(XDG_DATA_HOME)/mitishell
