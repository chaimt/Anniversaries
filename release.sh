#!/bin/bash

# Release script for Anniversaries Home Assistant custom component
# Usage: ./release.sh [version]
# Example: ./release.sh 1.2.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$SCRIPT_DIR/custom_components/anniversaries"
CONST_FILE="$COMPONENT_DIR/const.py"
MANIFEST_FILE="$COMPONENT_DIR/manifest.json"
OUTPUT_DIR="$SCRIPT_DIR/dist"

# Get current version from const.py
get_current_version() {
    sed -n 's/.*VERSION = "\([^"]*\)".*/\1/p' "$CONST_FILE"
}

# Validate semantic version format (allows optional pre-release suffix like -beta, b, -rc1, etc.)
validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+[a-zA-Z0-9._-]*$ ]]; then
        echo -e "${RED}Error: Invalid version format. Use semantic versioning (e.g., 1.2.0 or 1.2.0b)${NC}"
        exit 1
    fi
}

# Update version in const.py
update_const_version() {
    local version=$1
    sed -i.bak "s/VERSION = \".*\"/VERSION = \"$version\"/" "$CONST_FILE"
    rm -f "$CONST_FILE.bak"
    echo -e "${GREEN}Updated const.py version to $version${NC}"
}

# Update version in manifest.json
update_manifest_version() {
    local version=$1
    # Use Python for reliable JSON manipulation
    python3 -c "
import json
with open('$MANIFEST_FILE', 'r') as f:
    data = json.load(f)
data['version'] = '$version'
with open('$MANIFEST_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
    echo -e "${GREEN}Updated manifest.json version to $version${NC}"
}

# Create the release zip file
create_zip() {
    local version=$1
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Zip file name
    local zip_file="$OUTPUT_DIR/anniversaries.zip"
    local versioned_zip="$OUTPUT_DIR/anniversaries-$version.zip"
    
    # Remove old zip files
    rm -f "$zip_file" "$versioned_zip"
    
    # Create zip from component directory
    cd "$COMPONENT_DIR"
    zip -r "$zip_file" . -x "*.pyc" -x "__pycache__/*" -x ".DS_Store" -x "*.bak"
    
    # Also create a versioned copy
    cp "$zip_file" "$versioned_zip"
    
    cd "$SCRIPT_DIR"
    
    echo -e "${GREEN}Created release zip files:${NC}"
    echo "  - $zip_file"
    echo "  - $versioned_zip"
}

# Create git tag
create_git_tag() {
    local version=$1
    
    echo ""
    read -p "Create git tag v$version? (y/n): " create_tag
    if [[ $create_tag =~ ^[Yy]$ ]]; then
        # Check for uncommitted changes
        if [[ -n $(git status --porcelain) ]]; then
            echo -e "${YELLOW}Warning: You have uncommitted changes.${NC}"
            read -p "Commit changes before tagging? (y/n): " commit_changes
            if [[ $commit_changes =~ ^[Yy]$ ]]; then
                git add -A
                git commit -m "Release v$version"
                echo -e "${GREEN}Changes committed${NC}"
            fi
        fi
        
        git tag -a "v$version" -m "Release v$version"
        echo -e "${GREEN}Created git tag v$version${NC}"
        
        read -p "Push tag to origin? (y/n): " push_tag
        if [[ $push_tag =~ ^[Yy]$ ]]; then
            git push origin "v$version"
            echo -e "${GREEN}Pushed tag v$version to origin${NC}"
        fi
    fi
}

# Main script
main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  Anniversaries Release Script${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    
    # Get current version
    current_version=$(get_current_version)
    echo -e "Current version: ${GREEN}$current_version${NC}"
    
    # Get new version from argument or prompt
    if [[ -n $1 ]]; then
        new_version=$1
    else
        read -p "Enter new version (or press Enter to keep $current_version): " new_version
        if [[ -z $new_version ]]; then
            new_version=$current_version
        fi
    fi
    
    # Validate version
    validate_version "$new_version"
    
    echo ""
    echo -e "New version: ${GREEN}$new_version${NC}"
    echo ""
    
    # Update version if changed
    if [[ $new_version != $current_version ]]; then
        echo "Updating version numbers..."
        update_const_version "$new_version"
        update_manifest_version "$new_version"
        echo ""
    fi
    
    # Create zip
    echo "Creating release zip..."
    create_zip "$new_version"
    
    # Git operations
    create_git_tag "$new_version"
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Release $new_version complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review the changes: git diff"
    echo "  2. Push to GitHub: git push origin master"
    echo "  3. Create a GitHub release with the tag"
    echo "  4. Upload dist/anniversaries.zip to the release"
}

main "$@"
