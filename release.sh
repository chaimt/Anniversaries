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

# Commit changes, create tag, and push
git_operations() {
    local version=$1
    
    echo ""
    
    # Check for uncommitted changes
    if [[ -n $(git status --porcelain) ]]; then
        echo "Committing changes..."
        git add -A
        git commit -m "Release v$version"
        echo -e "${GREEN}Changes committed${NC}"
    else
        echo "No changes to commit"
    fi
    
    # Check if tag already exists
    if git rev-parse "v$version" >/dev/null 2>&1; then
        echo -e "${YELLOW}Tag v$version already exists, skipping tag creation${NC}"
    else
        echo "Creating git tag..."
        git tag -a "v$version" -m "Release v$version"
        echo -e "${GREEN}Created git tag v$version${NC}"
    fi
    
    # Push commits and tag
    echo "Pushing to origin..."
    git push origin HEAD
    git push origin "v$version" 2>/dev/null || echo -e "${YELLOW}Tag already exists on remote${NC}"
    echo -e "${GREEN}Pushed to origin${NC}"
}

# Create GitHub release with zip file
create_github_release() {
    local version=$1
    local zip_file="$OUTPUT_DIR/anniversaries.zip"
    
    echo ""
    
    # Check if gh CLI is available
    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}GitHub CLI (gh) not found. Skipping GitHub release creation.${NC}"
        echo "Install it with: brew install gh"
        echo "Then manually create a release at: https://github.com/chaimt/Anniversaries/releases"
        return
    fi
    
    # Check if release already exists
    if gh release view "v$version" &>/dev/null; then
        echo -e "${YELLOW}GitHub release v$version already exists${NC}"
        echo "Updating release assets..."
        gh release upload "v$version" "$zip_file" --clobber
        echo -e "${GREEN}Updated release assets${NC}"
    else
        echo "Creating GitHub release..."
        gh release create "v$version" "$zip_file" \
            --title "v$version" \
            --notes "Release v$version"
        echo -e "${GREEN}Created GitHub release v$version${NC}"
    fi
    
    # Get and display release URL
    local release_url=$(gh release view "v$version" --json url -q .url)
    echo -e "${GREEN}Release URL: $release_url${NC}"
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
    
    # Git operations (commit, tag, push)
    git_operations "$new_version"
    
    # Create GitHub release
    create_github_release "$new_version"
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Release $new_version complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
}

main "$@"
