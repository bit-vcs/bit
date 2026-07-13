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

    # Typed task runner + language-agnostic test runner used in place of the
    # old justfile. See Taskfile.pkl and Test.pkl at the repo root.
    pkfire.url = "github:mizchi/pkfire";
    pkfire.inputs.nixpkgs.follows = "nixpkgs";
    pkspec.url = "github:mizchi/pkspec";
    pkspec.inputs.nixpkgs.follows = "nixpkgs";
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

          # Strip workspace-local deps so buildCachedRegistry only resolves
          # packages that actually exist on mooncakes.io.
          bitMod = (import ./nix/parse-moon-mod.nix { inherit (pkgs) lib; }) ./modules/bit/moon.mod;
          registryOnlyMod = bitMod // {
            deps = pkgs.lib.filterAttrs (
              name: _: !(pkgs.lib.hasPrefix "mizchi/bit_" name || pkgs.lib.hasPrefix "mizchi/bitx_" name)
            ) bitMod.deps;
          };
          registryOnlyModFile = pkgs.writeText "moon.mod.json" (builtins.toJSON registryOnlyMod);

          moonHome = pkgs.moonPlatform.bundleWithRegistry {
            cachedRegistry = pkgs.moonPlatform.buildCachedRegistry {
              moonModJson = registryOnlyModFile;
              registryIndexSrc = inputs.moon-registry;
            };
          };

          pkfire = inputs.pkfire.packages.${system}.default;
          pkspec = inputs.pkspec.packages.${system}.default;
        in
        {
          packages = {
            default = bit;
            inherit bit pkfire pkspec;
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
            pkfire = {
              type = "app";
              program = "${pkfire}/bin/pkf";
            };
            pkspec = {
              type = "app";
              program = "${pkspec}/bin/pkspec";
            };
          };

          devShells.default = pkgs.mkShellNoCC {
            packages = [
              moonHome
              pkgs.git
              pkgs.pnpm
              pkgs.nodejs
              pkfire
              pkspec
            ];
            env.MOON_HOME = "${moonHome}";
          };
        };
    };
}
