---
name: update-wheelwizard
description: >-
  Use this skill when checking for new upstream WheelWizard releases,
  updating or bumping WheelWizard in package.nix, or regenerating NuGet dependencies (deps.json).
---

# Update WheelWizard

Run the automated update script, then troubleshoot and resolve any build or packaging failures.

## 1. Run the Update Script

Execute the script (optionally providing a target version):

```bash
# Update to latest upstream release
./scripts/update.sh

# Or update to a specific version
./scripts/update.sh <VERSION>
```

The script automatically fetches the new release tag, updates the source hash and version in `package.nix`, regenerates `deps.json`, stages files in git, and runs `nix build` and `nix flake check`.

## 2. Troubleshoot & Fix Failures

If the script fails during build or check:

- **.NET Target Framework changes**: Inspect `TargetFramework` in upstream `WheelWizard/WheelWizard.csproj`. If bumped, adjust `dotnet-sdk`, `dotnet-runtime`, and the `cp -r .../netX.X/...` path in `package.nix` and `flake.nix`.
- **New runtime dependencies**: Check if new native libraries are required and add them to `runtimeDeps` in `package.nix`.
- **Desktop / Asset path changes**: Verify whether desktop files, icons, or binary outputs moved in upstream repo.
- **Dependency restoration errors**: If NuGet dependencies fail to restore, inspect `deps.json` and retry `nix run .#fetch-deps -- ./deps.json`.

Re-run `nix build` and `nix flake check` to verify before concluding.
