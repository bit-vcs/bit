{
  description = "bit – Git-compatible version control in MoonBit";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    moonbit-overlay.url = "github:moonbit-community/moonbit-overlay";
    moon-registry = {
      url = "git+https://mooncakes.io/git/index";
      flake = false;
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      flake = {
        overlays.default = _final: prev: {
          bit = prev.callPackage ./package.nix {
            moonRegistryIndex = inputs.moon-registry;
          };
        };
      };

      perSystem =
        { system, ... }:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.moonbit-overlay.overlays.default ];
            config.allowBroken = true;
          };

          bit = pkgs.callPackage ./package.nix {
            moonRegistryIndex = inputs.moon-registry;
          };

          moonHome = pkgs.moonPlatform.bundleWithRegistry {
            cachedRegistry = pkgs.moonPlatform.buildCachedRegistry {
              moonModJson = ./moon.mod.json;
              registryIndexSrc = inputs.moon-registry;
            };
          };
        in
        {
          packages = {
            default = bit;
            inherit bit;
          };

          apps = {
            default = {
              type = "app";
              program = "${bit}/bin/bit";
            };
            bit = {
              type = "app";
              program = "${bit}/bin/bit";
            };
          };

          devShells.default = pkgs.mkShellNoCC {
            packages = [
              moonHome
              pkgs.git
              pkgs.just
              pkgs.pnpm
              pkgs.nodejs
            ];
            env.MOON_HOME = "${moonHome}";
          };
        };
    };
}
