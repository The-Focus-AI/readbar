# ReadBar - macOS Menubar PDF/EPUB File Tracker
# Makefile for building and installing ReadBar

# Configuration
APP_NAME = readbar
SOURCE_FILE = readbar.swift
INSTALL_DIR = /usr/local/bin
FRAMEWORKS = -framework Cocoa -framework Foundation -framework CoreServices

# Compiler settings
SWIFT_FLAGS = -O -warnings-as-errors
DEPLOYMENT_TARGET = -target x86_64-apple-macos10.15

# Default target
.PHONY: all
all: build

# Build the application
.PHONY: build
build: $(APP_NAME)

$(APP_NAME): $(SOURCE_FILE)
	@echo "Building ReadBar..."
	swiftc $(SWIFT_FLAGS) $(DEPLOYMENT_TARGET) -o $(APP_NAME) $(SOURCE_FILE) $(FRAMEWORKS)
	@echo "✅ Build complete: $(APP_NAME)"

# Install to /usr/local/bin
.PHONY: install
install: build
	@echo "Installing ReadBar to $(INSTALL_DIR)..."
	@if [ ! -d "$(INSTALL_DIR)" ]; then \
		echo "Creating $(INSTALL_DIR) directory..."; \
		sudo mkdir -p $(INSTALL_DIR); \
	fi
	sudo cp $(APP_NAME) $(INSTALL_DIR)/$(APP_NAME)
	sudo chmod +x $(INSTALL_DIR)/$(APP_NAME)
	@echo "✅ ReadBar installed to $(INSTALL_DIR)/$(APP_NAME)"
	@echo ""
	@echo "To run ReadBar:"
	@echo "  $(APP_NAME)"
	@echo ""
	@echo "To add to login items:"
	@echo "  System Preferences > Users & Groups > Login Items > Add $(INSTALL_DIR)/$(APP_NAME)"

# Uninstall from /usr/local/bin
.PHONY: uninstall
uninstall:
	@echo "Uninstalling ReadBar..."
	@if [ -f "$(INSTALL_DIR)/$(APP_NAME)" ]; then \
		sudo rm -f $(INSTALL_DIR)/$(APP_NAME); \
		echo "✅ ReadBar uninstalled from $(INSTALL_DIR)"; \
	else \
		echo "ReadBar is not installed in $(INSTALL_DIR)"; \
	fi

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@if [ -f "$(APP_NAME)" ]; then \
		rm -f $(APP_NAME); \
		echo "✅ Removed $(APP_NAME)"; \
	fi
	@if [ -f "/tmp/readbar_debug.txt" ]; then \
		rm -f /tmp/readbar_debug.txt; \
		echo "✅ Removed debug file"; \
	fi
	@if [ -f "/tmp/readbar_output.log" ]; then \
		rm -f /tmp/readbar_output.log; \
		echo "✅ Removed log file"; \
	fi

# Run the application locally (for development)
.PHONY: run
run: build
	@echo "Starting ReadBar..."
	@echo "Press Ctrl+C to stop"
	./$(APP_NAME)

# Test build without installation
.PHONY: test
test: build
	@echo "Testing ReadBar build..."
	@if [ -x "./$(APP_NAME)" ]; then \
		echo "✅ Build successful and executable"; \
		file ./$(APP_NAME); \
	else \
		echo "❌ Build failed or not executable"; \
		exit 1; \
	fi

# Show help
.PHONY: help
help:
	@echo "ReadBar - macOS Menubar PDF/EPUB File Tracker"
	@echo ""
	@echo "Available targets:"
	@echo "  build     - Compile the ReadBar application"
	@echo "  install   - Build and install to $(INSTALL_DIR) (requires sudo)"
	@echo "  uninstall - Remove ReadBar from $(INSTALL_DIR) (requires sudo)"
	@echo "  run       - Build and run ReadBar locally"
	@echo "  test      - Build and verify the executable"
	@echo "  clean     - Remove build artifacts and temporary files"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make install    # Build and install ReadBar"
	@echo "  make run        # Build and run for development"
	@echo "  make clean      # Clean up build files"

# Check if source file exists
$(SOURCE_FILE):
	@if [ ! -f "$(SOURCE_FILE)" ]; then \
		echo "❌ Source file $(SOURCE_FILE) not found"; \
		exit 1; \
	fi

# Verify system requirements
.PHONY: check
check:
	@echo "Checking system requirements..."
	@which swiftc > /dev/null 2>&1 || (echo "❌ Swift compiler not found. Install Xcode Command Line Tools." && exit 1)
	@echo "✅ Swift compiler found: $$(swiftc --version | head -n1)"
	@sw_vers -productVersion | awk -F. '{if($$1>=14 || ($$1==10 && $$2>=15)) print "✅ macOS version compatible: " $$0; else {print "❌ macOS 10.15+ required"; exit 1}}'
	@echo "✅ System requirements satisfied"