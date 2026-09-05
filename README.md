# WheelWizard Nix Flake

Nix flake packaging for [WheelWizard](https://github.com/TeamWheelWizard/WheelWizard), based on [NixOS/nixpkgs#557011](https://github.com/NixOS/nixpkgs/pull/557011).

## Usage

### Run directly

```bash
nix run
```

### Build

```bash
nix build
```

The resulting binary will be at `./result/bin/WheelWizard`.

### Use as a Flake Input

In your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    wheelwizard.url = "path:/home/bualy/files/devel/wheelwizard_flake"; # or github url
  };

  outputs = { self, nixpkgs, wheelwizard, ... }: {
    # In your NixOS or Home Manager configuration:
    # Option 1: Use package directly
    # environment.systemPackages = [ wheelwizard.packages.${pkgs.system}.default ];
    
    # Option 2: Use overlay
    # nixpkgs.overlays = [ wheelwizard.overlays.default ];
    # environment.systemPackages = [ pkgs.wheelwizard ];
  };
}
```

### Updating WheelWizard

To update WheelWizard to the latest upstream release:

```bash
./scripts/update.sh
```

Or to target a specific version:

```bash
./scripts/update.sh <version>
```

This script updates the source hash in `package.nix`, regenerates `deps.json`, and verifies the build.

### Updating Nuget Dependencies

To regenerate `deps.json` manually:

```bash
nix run .#fetch-deps -- ./deps.json
```
