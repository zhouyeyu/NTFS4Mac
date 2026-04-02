PREFIX ?= /usr/local

install:
	@echo "Installing ntfs-cli to $(PREFIX)/bin..."
	@mkdir -p $(PREFIX)/bin
	@cp ntfs-cli.sh $(PREFIX)/bin/ntfs-cli
	@chmod +x $(PREFIX)/bin/ntfs-cli
	@mkdir -p $(PREFIX)/lib/ntfs4mac
	@cp lib/*.sh $(PREFIX)/lib/ntfs4mac/
	@chmod +x $(PREFIX)/lib/ntfs4mac/*.sh
	@# Fix lib path in installed script
	@sed -i '' 's|LIB_DIR="$$SCRIPT_DIR/lib"|LIB_DIR="$(PREFIX)/lib/ntfs4mac"|' $(PREFIX)/bin/ntfs-cli
	@echo "Done. Run: ntfs-cli help"

uninstall:
	@echo "Uninstalling ntfs-cli..."
	@rm -f $(PREFIX)/bin/ntfs-cli
	@rm -rf $(PREFIX)/lib/ntfs4mac
	@echo "Done."

.PHONY: install uninstall
