#!/bin/bash
# Version Management Script for Linux/Mac
# This script helps manage version code and version name in pubspec.yaml
#
# Usage:
#   ./version_manager.sh                    # Show current version
#   ./version_manager.sh bump patch         # Bump patch version (1.0.0 -> 1.0.1)
#   ./version_manager.sh bump minor         # Bump minor version (1.0.0 -> 1.1.0)
#   ./version_manager.sh bump major         # Bump major version (1.0.0 -> 2.0.0)
#   ./version_manager.sh build <number>     # Set build number
#   ./version_manager.sh set <version>      # Set version (format: x.y.z+build)

set -e

# Navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml"

if [ ! -f "$PUBSPEC_FILE" ]; then
    echo "Error: pubspec.yaml not found" >&2
    exit 1
fi

# Extract current version
get_current_version() {
    local content=$(cat "$PUBSPEC_FILE")
    if [[ $content =~ version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}|${BASH_REMATCH[2]}"
    else
        echo "1.0.0|1"
    fi
}

# Show current version
show_version() {
    local version_info=$(get_current_version)
    local version_name=$(echo "$version_info" | cut -d'|' -f1)
    local version_code=$(echo "$version_info" | cut -d'|' -f2)
    echo "Current Version: $version_name (Build: $version_code)"
}

# Bump version
bump_version() {
    local bump_type=$1
    local version_info=$(get_current_version)
    local version_name=$(echo "$version_info" | cut -d'|' -f1)
    local version_code=$(echo "$version_info" | cut -d'|' -f2)
    
    IFS='.' read -ra PARTS <<< "$version_name"
    local major=${PARTS[0]}
    local minor=${PARTS[1]}
    local patch=${PARTS[2]}
    
    case "$bump_type" in
        patch)
            patch=$((patch + 1))
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        *)
            echo "Error: Invalid bump type. Use: patch, minor, or major" >&2
            exit 1
            ;;
    esac
    
    local new_version_name="$major.$minor.$patch"
    local new_version_code=$((version_code + 1))
    
    update_version "$new_version_name" "$new_version_code"
    echo "Version bumped: $version_name -> $new_version_name"
    echo "Build number: $version_code -> $new_version_code"
}

# Set build number
set_build_number() {
    local build_number=$1
    local version_info=$(get_current_version)
    local version_name=$(echo "$version_info" | cut -d'|' -f1)
    
    update_version "$version_name" "$build_number"
    echo "Build number set to: $build_number"
}

# Set version
set_version_string() {
    local version_string=$1
    
    if [[ ! $version_string =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
        echo "Error: Version format must be x.y.z+build (e.g., 1.2.3+4)" >&2
        exit 1
    fi
    
    local version_name="${BASH_REMATCH[1]}"
    local version_code="${BASH_REMATCH[2]}"
    
    update_version "$version_name" "$version_code"
    echo "Version set to: $version_name (Build: $version_code)"
}

# Update version in pubspec.yaml
update_version() {
    local version_name=$1
    local version_code=$2
    
    # Create backup
    cp "$PUBSPEC_FILE" "$PUBSPEC_FILE.bak"
    
    # Update version line
    sed -i.tmp "s/^version:.*/version: $version_name+$version_code/" "$PUBSPEC_FILE"
    rm -f "$PUBSPEC_FILE.tmp"
    
    echo "Updated pubspec.yaml (backup saved as pubspec.yaml.bak)"
}

# Main script logic
case "$1" in
    bump)
        if [ -z "$2" ]; then
            echo "Error: Bump type required (patch, minor, or major)" >&2
            exit 1
        fi
        bump_version "$2"
        ;;
    build)
        if [ -z "$2" ]; then
            echo "Error: Build number required" >&2
            exit 1
        fi
        set_build_number "$2"
        ;;
    set)
        if [ -z "$2" ]; then
            echo "Error: Version string required (format: x.y.z+build)" >&2
            exit 1
        fi
        set_version_string "$2"
        ;;
    "")
        show_version
        echo ""
        echo "Usage:"
        echo "  $0                    # Show current version"
        echo "  $0 bump patch         # Bump patch version"
        echo "  $0 bump minor         # Bump minor version"
        echo "  $0 bump major         # Bump major version"
        echo "  $0 build <number>     # Set build number"
        echo "  $0 set <version>      # Set version (x.y.z+build)"
        ;;
    *)
        echo "Error: Unknown command: $1" >&2
        exit 1
        ;;
esac
