#!/bin/bash
# Setup Script Permissions for Linux/Mac
# This script makes all build scripts executable

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Setting executable permissions for build scripts..."

chmod +x "$SCRIPT_DIR"/*.sh

echo "✅ All scripts are now executable"
echo ""
echo "Executable scripts:"
ls -lh "$SCRIPT_DIR"/*.sh | awk '{print $9, $1}'
