GO ?= go
GOFMT ?= gofmt
NODE ?= node
QMLLINT ?= qmllint
QUICKSHELL ?= quickshell
QML_IMPORT_PATH ?= /usr/lib/qt6/qml

.PHONY: build check run

build:
	mkdir -p bin
	$(GO) build -o bin/mitishell ./cmd/mitishell

check:
	test -z "$$(find . -name '*.go' -not -path './vendor/*' -print0 | xargs -0 $(GOFMT) -l)"
	$(GO) vet ./...
	$(GO) test ./...
	$(QMLLINT) -I $(QML_IMPORT_PATH) shell/shell.qml
	git diff --check

run:
	$(QUICKSHELL) -p shell
