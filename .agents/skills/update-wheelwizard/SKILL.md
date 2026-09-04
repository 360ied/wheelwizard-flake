---
name: update-wheelwizard
description: >-
  Use this skill when checking for new upstream WheelWizard releases,
  updating or bumping WheelWizard in package.nix, or regenerating NuGet dependencies (deps.json).
---

# Update WheelWizard Skill

Procedure and tools for updating the WheelWizard package to the latest upstream release.

## Automated Update

Run the bundled update script:

```bash
# Update to latest upstream release
./.agents/skills/update-wheelwizard/scripts/update.sh

# Or update to a specific version/tag
./.agents/skills/update-wheelwizard/scripts/update.sh 2.5.3
```

## Manual Update Procedure

If running manually or debugging:

1. **Check latest upstream release**:
   ```bash
   curl -sL https://api.github.com/repos/TeamWheelWizard/WheelWizard/releases/latest | jq -r '{tag: .tag_name, name: .name}'
   ```

2. **Compute source SRI hash**:
   ```bash
   TAG="v<VERSION>"
   RAW_HASH=$(nix-prefetch-url --unpack "https://github.com/TeamWheelWizard/WheelWizard/archive/refs/tags/${TAG}.tar.gz")
   nix hash convert --to sri --hash-algo sha256 "$RAW_HASH"
   ```

3. **Update `package.nix`**:
   - Set `version = "<VERSION>"`.
   - Set `hash = "sha256-..."`.

4. **Regenerate NuGet dependencies**:
   ```bash
   git add package.nix
   nix run .#fetch-deps -- ./deps.json
   ```

5. **Verify**:
   ```bash
   git add deps.json
   nix build
   nix flake check
   ```
