{
  description = "WheelWizard, Retro Rewind Launcher";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = import nixpkgs { inherit system; };
            inherit system;
          }
        );
    in
    {
      packages = forEachSystem (
        { pkgs, ... }:
        rec {
          wheelwizard-2_5_1 = pkgs.callPackage ./package.nix { version = "2.5.1"; };
          wheelwizard-2_5_3 = pkgs.callPackage ./package.nix { version = "2.5.3"; };
          wheelwizard = wheelwizard-2_5_1;
          default = wheelwizard;
        }
      );

      apps = forEachSystem (
        { system, pkgs }:
        rec {
          wheelwizard = {
            type = "app";
            program = "${self.packages.${system}.wheelwizard}/bin/WheelWizard";
            meta.description = "WheelWizard Launcher";
          };
          fetch-deps = {
            type = "app";
            program = "${self.packages.${system}.wheelwizard.passthru.fetch-deps}";
            meta.description = "Regenerate deps.json for WheelWizard";
          };
          default = wheelwizard;
        }
      );

      overlays.default = final: _prev: {
        wheelwizard = final.callPackage ./package.nix { };
        wheelwizard-2_5_1 = final.callPackage ./package.nix { version = "2.5.1"; };
        wheelwizard-2_5_3 = final.callPackage ./package.nix { version = "2.5.3"; };
      };

      devShells = forEachSystem (
        { pkgs, ... }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              dotnetCorePackages.sdk_10_0-bin
              dotnetCorePackages.runtime_10_0-bin
            ];
          };
        }
      );
    };
}
