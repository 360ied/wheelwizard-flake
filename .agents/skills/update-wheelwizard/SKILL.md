---
name: update-wheelwizard
description: >-
  Use this skill when checking for new upstream WheelWizard releases,
  updating or bumping WheelWizard in package.nix, or regenerating NuGet dependencies (deps.json).
---

# Update WheelWizard

Run the automated update script, then troubleshoot and resolve any build or packaging failures.

## 1. Quick Check (Fast Path)

Before running a full update, quickly check if a newer release exists (<1s):

```bash
./scripts/update.sh --check
```

If the flake is already up to date, conclude the task immediately.

## 2. Upstream Change Pre-Check (Optional but Recommended)

If an update is available, inspect what changed upstream before building.

You can inspect changed files via GitHub compare API (note: subject to GitHub API rate limits if unauthenticated):
```bash
# View list of changed files between releases (e.g. v2.5.6...v2.5.7)
curl -sL "https://api.github.com/repos/TeamWheelWizard/WheelWizard/compare/<OLD_TAG>...<NEW_TAG>" | jq -r '.files[].filename'
```

Alternatively, run `./scripts/update.sh --dry-run` to prefetch the new source into the Nix store, allowing you to inspect files locally without making any GitHub API calls.

Look for:
- `WheelWizard.csproj`: Dependency version bumps (.NET framework, Avalonia, DBus, etc.). If `<PackageReference>` entries are unchanged, you can use `--skip-deps`.
- `Flatpak/*.desktop`, icons, or paths: Check if asset locations moved.

## 3. Run the Update Script

Execute the update script:

```bash
# Update to latest upstream release
./scripts/update.sh

# Or update to a specific version
./scripts/update.sh <VERSION>

# Fast dry-run to preview version and SRI hash without changes
./scripts/update.sh --dry-run

# Skip NuGet dependency regeneration if .csproj dependencies did not change
./scripts/update.sh --skip-deps

# Update package.nix and deps.json without running nix build
./scripts/update.sh --skip-build
```

The script automatically:
1. Resolves the latest release tag via fast HTTP redirect (avoiding GitHub API rate limits).
2. Prefetches the source archive into the Nix store and computes SRI hash.
3. Updates `version` and `hash` in `package.nix`.
4. Runs a fast evaluation check (`nix eval .#wheelwizard.drvPath`) to catch syntax and derivation issues immediately.
5. Regenerates `deps.json` via `nix run .#fetch-deps` (unless `--skip-deps` is set).
6. Builds the package with streaming logs (`nix build -L`) and runs `nix flake check`.

## 4. Troubleshoot & Fix Failures

If the script fails during build or check:

- **Quick Nix evaluation check**:
  ```bash
  nix eval .#wheelwizard.drvPath
  ```
- **Inspect build logs**:
  ```bash
  nix log
  ```
- **.NET Target Framework changes**: Inspect `TargetFramework` in upstream `WheelWizard/WheelWizard.csproj`. If bumped, adjust `dotnet-sdk`, `dotnet-runtime`, and the `cp -r .../netX.X/...` path in `package.nix` and `flake.nix`.
- **New runtime dependencies**: Check if new native libraries are required and add them to `runtimeDeps` in `package.nix`.
- **Desktop / Asset path changes**: Verify whether desktop files, icons, or binary outputs moved in upstream repo.
- **Dependency restoration errors**: If NuGet dependencies fail to restore, inspect `deps.json` and retry `nix run .#fetch-deps -- ./deps.json`.

After making fixes, stage the files (`git add package.nix deps.json`) and verify with:
```bash
nix build -L
nix flake check
```
