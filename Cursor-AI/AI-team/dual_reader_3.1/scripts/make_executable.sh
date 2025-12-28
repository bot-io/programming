#!/bin/bash
# Make all shell scripts executable
# This script ensures all build scripts have execute permissions

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Making shell scripts executable..."

chmod +x "$SCRIPT_DIR"/*.sh

echo "Done! All shell scripts are now executable."
echo ""
echo "Executable scripts:"
ls -lh "$SCRIPT_DIR"/*.sh
