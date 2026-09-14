#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "Update failed. Modified files may be staged in git (run 'git status')." >&2
  fi
}
trap cleanup EXIT

for cmd in nix curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Required command '$cmd' is not installed or not in PATH." >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Default configuration
TARGET_VERSION=""
CHECK_ONLY=0
DRY_RUN=0
SKIP_DEPS=0
SKIP_BUILD=0
FORCE="${FORCE:-0}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [VERSION]

Update WheelWizard flake to the latest release or a specific version.

Arguments:
  VERSION               Target version to update to (e.g. '2.5.7' or 'v2.5.7', default: latest)

Options:
  -c, --check           Check if a newer version is available without making changes
  -n, --dry-run         Show what would be updated without modifying files
  -s, --skip-deps       Skip regenerating deps.json (use existing dependencies)
  -b, --skip-build      Skip 'nix build' and 'nix flake check' verification
  -f, --force           Force update even if already on the target version
  -h, --help            Display this help message

Environment Variables:
  FORCE=1               Equivalent to --force (also accepts 'true' or 'yes')
  NUGET_HTTP_CACHE_PATH Custom path for NuGet HTTP cache (speeds up dependency restoration)
EOF
}

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--check)
      CHECK_ONLY=1
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -s|--skip-deps)
      SKIP_DEPS=1
      shift
      ;;
    -b|--skip-build)
      SKIP_BUILD=1
      shift
      ;;
    -f|--force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [ -z "$TARGET_VERSION" ]; then
        TARGET_VERSION="$1"
      else
        echo "Error: Unexpected argument '$1'" >&2
        usage >&2
        exit 1
      fi
      shift
      ;;
  esac
done

while [[ $# -gt 0 ]]; do
  if [ -z "$TARGET_VERSION" ]; then
    TARGET_VERSION="$1"
  else
    echo "Error: Unexpected argument '$1'" >&2
    usage >&2
    exit 1
  fi
  shift
done

TARGET_VERSION="${TARGET_VERSION:-latest}"

CURRENT_VERSION=$(grep -E 'version = "[^"]+"' package.nix | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')

if [ "$TARGET_VERSION" = "latest" ]; then
  echo "Checking latest upstream release..."
  # Use HTTP redirect for instantaneous, rate-limit-free tag resolution
  LATEST_URL=$(curl -sIL -o /dev/null -w '%{url_effective}' "https://github.com/TeamWheelWizard/WheelWizard/releases/latest" 2>/dev/null || true)
  TAG=$(basename "$LATEST_URL")

  # Fallback to GitHub REST API if redirect is unavailable or unexpected
  if [[ "$TAG" != v* ]]; then
    TAG=$(curl -sL https://api.github.com/repos/TeamWheelWizard/WheelWizard/releases/latest | jq -r .tag_name)
  fi
else
  TAG="v${TARGET_VERSION#v}"
fi

if [[ -z "$TAG" || "$TAG" == "null" ]]; then
  echo "Error: Failed to resolve valid release tag." >&2
  exit 1
fi

VERSION="${TAG#v}"

if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "Current version: $CURRENT_VERSION"
  if [ "$TARGET_VERSION" = "latest" ]; then
    echo "Latest version:  $VERSION (tag: $TAG)"
    if [ "$VERSION" = "$CURRENT_VERSION" ]; then
      echo "Flake is up to date."
    else
      echo "Update available: $CURRENT_VERSION -> $VERSION"
    fi
  else
    echo "Target version:  $VERSION (tag: $TAG)"
    if [ "$VERSION" = "$CURRENT_VERSION" ]; then
      echo "Flake is already on version $VERSION."
    else
      echo "Target version differs from current version: $CURRENT_VERSION -> $VERSION"
    fi
  fi
  exit 0
fi

echo "Targeting version: $VERSION (tag: $TAG)"
echo "Current version:   $CURRENT_VERSION"

if [ "$VERSION" = "$CURRENT_VERSION" ] && [[ ! "$FORCE" =~ ^(1|true|yes)$ ]]; then
  echo "Already on version $VERSION. Use --force or FORCE=1 to force update."
  exit 0
fi

echo "Prefetching archive for $TAG..."
PREFETCH_JSON=$(nix store prefetch-file --json --hash-type sha256 --unpack "https://github.com/TeamWheelWizard/WheelWizard/archive/refs/tags/${TAG}.tar.gz")
SRI_HASH=$(jq -r .hash <<< "$PREFETCH_JSON")

echo "Source hash: $SRI_HASH"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] Would update package.nix: version -> $VERSION, hash -> $SRI_HASH"
  if [ "$SKIP_DEPS" -eq 0 ]; then
    echo "[dry-run] Would regenerate deps.json via 'nix run .#fetch-deps'"
  fi
  if [ "$SKIP_BUILD" -eq 0 ]; then
    echo "[dry-run] Would build and verify with 'nix build -L' and 'nix flake check'"
  fi
  exit 0
fi

echo "Updating package.nix..."
sed -i -E "s/^[[:space:]]*version = \"[^\"]+\";/  version = \"$VERSION\";/" package.nix
sed -i -E "s|^[[:space:]]*hash = \"[^\"]+\";|    hash = \"$SRI_HASH\";|" package.nix

echo "Validating Nix evaluation..."
git add package.nix
nix eval .#wheelwizard.drvPath > /dev/null

if [ "$SKIP_DEPS" -eq 1 ]; then
  echo "Skipping deps.json regeneration (--skip-deps specified)..."
else
  echo "Regenerating deps.json..."
  # Ensure NuGet cache directory exists for fast restores
  export NUGET_HTTP_CACHE_PATH="${NUGET_HTTP_CACHE_PATH:-$HOME/.local/share/NuGet/v3-cache}"
  mkdir -p "$NUGET_HTTP_CACHE_PATH"
  nix run .#fetch-deps -- ./deps.json
  git add deps.json
fi

if [ "$SKIP_BUILD" -eq 1 ]; then
  echo "Skipping build verification (--skip-build specified)..."
else
  echo "Building package..."
  nix build -L

  echo "Running flake check..."
  nix flake check
fi

echo "Successfully updated to $VERSION!"
