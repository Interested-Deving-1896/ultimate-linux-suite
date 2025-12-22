# Ultimate Linux Suite - Makefile
#
# Targets:
#   make install    - Install to system (requires root)
#   make uninstall  - Remove from system (requires root)
#   make clean      - Clean build artifacts
#   make test       - Run syntax checks

PREFIX ?= /usr/local
DESTDIR ?=
PKGNAME = ultimate-linux-suite
VERSION = 3.0.0

INSTALL_DIR = $(DESTDIR)$(PREFIX)/share/$(PKGNAME)
BIN_DIR = $(DESTDIR)$(PREFIX)/bin
DOC_DIR = $(DESTDIR)$(PREFIX)/share/doc/$(PKGNAME)

.PHONY: all install uninstall clean test help

all: help

help:
	@echo "Ultimate Linux Suite - Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make install     Install to $(PREFIX) (requires root)"
	@echo "  make uninstall   Remove from $(PREFIX) (requires root)"
	@echo "  make clean       Clean build artifacts"
	@echo "  make test        Run syntax checks"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  DESTDIR=$(DESTDIR)"

install:
	@echo "Installing $(PKGNAME) to $(INSTALL_DIR)..."
	install -d $(INSTALL_DIR)
	install -d $(BIN_DIR)
	install -d $(DOC_DIR)
	install -m 755 ultimate.sh $(INSTALL_DIR)/
	cp -r lib $(INSTALL_DIR)/
	cp -r modules $(INSTALL_DIR)/
	cp -r menus $(INSTALL_DIR)/
	cp -r backends $(INSTALL_DIR)/
	cp -r apps $(INSTALL_DIR)/
	cp -r configs $(INSTALL_DIR)/
	cp -r drivers $(INSTALL_DIR)/
	@echo '#!/bin/bash' > $(BIN_DIR)/$(PKGNAME)
	@echo 'exec $(PREFIX)/share/$(PKGNAME)/ultimate.sh "$$@"' >> $(BIN_DIR)/$(PKGNAME)
	chmod 755 $(BIN_DIR)/$(PKGNAME)
	install -m 644 README.md $(DOC_DIR)/
	install -m 644 CHANGELOG.md $(DOC_DIR)/
	install -m 644 LICENSE $(DOC_DIR)/
	@echo "Installation complete!"
	@echo "Run with: $(PKGNAME)"

uninstall:
	@echo "Removing $(PKGNAME)..."
	rm -rf $(INSTALL_DIR)
	rm -f $(BIN_DIR)/$(PKGNAME)
	rm -rf $(DOC_DIR)
	@echo "Uninstall complete!"

clean:
	rm -rf build/
	rm -rf dist/
	@echo "Build artifacts cleaned"

test:
	@echo "Running syntax checks..."
	@bash -n ultimate.sh && echo "ultimate.sh: OK"
	@for f in lib/*.sh; do bash -n "$$f" && echo "$$f: OK"; done
	@for f in modules/*.sh; do bash -n "$$f" && echo "$$f: OK"; done
	@for f in menus/*.sh; do bash -n "$$f" && echo "$$f: OK"; done
	@for f in backends/*.sh; do bash -n "$$f" && echo "$$f: OK"; done
	@for f in apps/*.sh; do bash -n "$$f" && echo "$$f: OK"; done
	@echo "All syntax checks passed!"
