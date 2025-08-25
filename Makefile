# Makefile для PigeonLinux Installer
DESTDIR ?= /mnt
CONFIG_FILE ?= .config

.PHONY: all menuconfig cfdisk install clean help

all: menuconfig cfdisk install

menuconfig: bin/menuconfig
	@./bin/menuconfig

cfdisk:
	@if [ -f "$(CONFIG_FILE)" ]; then \
		echo "Starting cfdisk on $$(grep 'TARGET_DISK=' $(CONFIG_FILE) | cut -d= -f2 | tr -d '"')..."; \
		cfdisk $$(grep 'TARGET_DISK=' $(CONFIG_FILE) | cut -d= -f2 | tr -d '"'); \
	else \
		echo "Error: Run 'make menuconfig' first!"; \
		exit 1; \
	fi

install:
	@if [ ! -f "$(CONFIG_FILE)" ]; then \
		echo "Error: Configuration file not found. Run 'make menuconfig' first!"; \
		exit 1; \
	fi
	@./install.sh

# Статическая компиляция без зависимостей
bin/menuconfig: src/menuconfig.c
	@mkdir -p bin
	cc -static -O2 -o $@ $<

clean:
	@-umount $(DESTDIR)/boot 2>/dev/null || true
	@-umount $(DESTDIR) 2>/dev/null || true
	@-rm -f $(CONFIG_FILE) 2>/dev/null || true
	@-rm -f bin/menuconfig 2>/dev/null || true
	@-rm -f src/*.o 2>/dev/null || true

distclean: clean
	@-rm -rf bin/ 2>/dev/null || true

help:
	@echo "PigeonLinux Installer Makefile"
	@echo "Usage: make [target]"
	@echo "Targets: all, menuconfig, cfdisk, install, clean, distclean, help"
