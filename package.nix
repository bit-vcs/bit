{
  lib,
  git,
  autoPatchelfHook,
  stdenv,
  moonPlatform,
  moonRegistryIndex,
}:
moonPlatform.buildMoonPackage {
  src = ./.;
  moonModJson = ./moon.mod.json;
  inherit moonRegistryIndex;

  doCheck = false;
  propagatedBuildInputs = [ git ];
  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  meta = {
    description = "Git-compatible version control in MoonBit";
    homepage = "https://github.com/bit-vcs/bit";
    mainProgram = "bit";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
