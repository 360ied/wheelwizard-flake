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
          wheelwizard = pkgs.callPackage ./package.nix { };
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
