#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

TARGET_VERSION="${1:-latest}"

if [ "$TARGET_VERSION" = "latest" ]; then
  echo "Checking latest upstream release..."
  TAG=$(curl -sL https://api.github.com/repos/TeamWheelWizard/WheelWizard/releases/latest | jq -r .tag_name)
else
  TAG="v${TARGET_VERSION#v}"
fi

VERSION="${TAG#v}"
echo "Targeting version: $VERSION (tag: $TAG)"

CURRENT_VERSION=$(grep -E 'version = "[^"]+"' package.nix | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')
if [ "$VERSION" = "$CURRENT_VERSION" ] && [ "${FORCE:-0}" != "1" ]; then
  echo "Already on version $VERSION. Use FORCE=1 to force update."
  exit 0
fi

echo "Prefetching archive for $TAG..."
RAW_HASH=$(nix-prefetch-url --unpack "https://github.com/TeamWheelWizard/WheelWizard/archive/refs/tags/${TAG}.tar.gz")
SRI_HASH=$(nix hash convert --to sri --hash-algo sha256 "$RAW_HASH")

echo "Updating package.nix..."
sed -i -E "s/version = \"[^\"]+\"/version = \"$VERSION\"/" package.nix
sed -i -E "s|hash = \"[^\"]+\"|hash = \"$SRI_HASH\"|" package.nix

echo "Regenerating deps.json..."
git add package.nix
nix run .#fetch-deps -- ./deps.json
git add deps.json

echo "Building package..."
nix build

echo "Running flake check..."
nix flake check

echo "Successfully updated to $VERSION!"
