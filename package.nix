{
  lib,
  git,
  autoPatchelfHook,
  stdenv,
  writeText,
  moonPlatform,
  moonRegistryIndex,
}:
let
  bitMod = builtins.fromJSON (builtins.readFile ./modules/bit/moon.mod.json);
  # buildCachedRegistry reads moon.mod.json to know which packages to fetch
  # from mooncakes.io. Workspace-local deps (mizchi/bit_* and mizchi/bitx_*)
  # aren't published there, so drop them and keep only registry deps.
  registryOnlyDeps = lib.filterAttrs (
    name: _: !(lib.hasPrefix "mizchi/bit_" name || lib.hasPrefix "mizchi/bitx_" name)
  ) bitMod.deps;
  registryOnlyMod = bitMod // {
    deps = registryOnlyDeps;
  };
  registryOnlyModFile = writeText "moon.mod.json" (builtins.toJSON registryOnlyMod);

  moonHome = moonPlatform.bundleWithRegistry {
    cachedRegistry = moonPlatform.buildCachedRegistry {
      moonModJson = registryOnlyModFile;
      registryIndexSrc = moonRegistryIndex;
    };
  };
in
stdenv.mkDerivation {
  pname = "bit";
  version = bitMod.version;

  src = lib.cleanSource ./.;

  nativeBuildInputs = [ moonHome ] ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];
  propagatedBuildInputs = [ git ];

  configurePhase = ''
    runHook preConfigure
    export MOON_HOME=${moonHome}
    export HOME=$TMPDIR
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    moon build --target native --release modules/bit/src/cmd/bit
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 \
      _build/native/release/build/mizchi/bit/cmd/bit/bit.exe \
      $out/bin/bit
    runHook postInstall
  '';

  doCheck = false;

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
