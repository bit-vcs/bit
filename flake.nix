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
            moonbit = inputs.moonbit-overlay.packages.${prev.stdenv.hostPlatform.system}.latest;
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

          moonbit = pkgs.moonbit-bin.latest;

          bit = pkgs.callPackage ./package.nix {
            inherit moonbit;
            moonRegistryIndex = inputs.moon-registry;
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
              moonbit
              pkgs.git
              pkgs.pnpm
              pkgs.nodejs
              pkfire
              pkspec
            ];
          };
        };
    };
}
