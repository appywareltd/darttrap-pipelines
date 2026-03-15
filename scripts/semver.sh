#!/usr/bin/env bash
#
# semver.sh — Calculate the next version for a Flutter app.
#
# Reads the current version from pubspec.yaml, determines the bump type
# from conventional commit messages since the last tag, and outputs
# a Flutter-compatible version string (e.g. 1.4.2+42).
#
# Usage: ./semver.sh [--dry-run]
#
# Build number is calculated as total commit count for reproducibility.

set -euo pipefail

PUBSPEC="pubspec.yaml"

# Extract current version from pubspec.yaml
if [[ ! -f "$PUBSPEC" ]]; then
  echo "Error: $PUBSPEC not found" >&2
  exit 1
fi

CURRENT_VERSION=$(grep -E '^version:' "$PUBSPEC" | head -1 | sed 's/version: *//' | sed 's/+.*//')

if [[ -z "$CURRENT_VERSION" ]]; then
  echo "Error: Could not parse version from $PUBSPEC" >&2
  exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Get the latest tag, if any
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

# Get commits since last tag (or all commits if no tag)
if [[ -n "$LATEST_TAG" ]]; then
  COMMITS=$(git log "${LATEST_TAG}..HEAD" --pretty=format:"%s" 2>/dev/null || echo "")
else
  COMMITS=$(git log --pretty=format:"%s" 2>/dev/null || echo "")
fi

# Determine bump type from conventional commits
BUMP="patch"

while IFS= read -r msg; do
  [[ -z "$msg" ]] && continue

  if echo "$msg" | grep -qiE '^BREAKING CHANGE|^[a-z]+(\(.+\))?!:'; then
    BUMP="major"
    break
  elif echo "$msg" | grep -qiE '^feat(\(.+\))?:'; then
    if [[ "$BUMP" != "major" ]]; then
      BUMP="minor"
    fi
  fi
done <<< "$COMMITS"

# Apply bump
case "$BUMP" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
esac

# Build number = total commit count
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "1")

VERSION="${MAJOR}.${MINOR}.${PATCH}+${BUILD_NUMBER}"

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "Current: $CURRENT_VERSION"
  echo "Bump: $BUMP"
  echo "Next: $VERSION"
else
  echo "$VERSION"
fi
