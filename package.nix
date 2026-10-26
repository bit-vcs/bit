{
  lib,
  git,
  autoPatchelfHook,
  stdenv,
  callPackage,
  moonbit,
  moonRegistryIndex,
}:
let
  bitMod = (import ./nix/parse-moon-mod.nix { inherit lib; }) ./modules/bit/moon.mod;
  # Only registry deps need caching. Workspace-local deps (mizchi/bit_* and
  # mizchi/bitx_*) aren't published to mooncakes.io, so drop them.
  registryOnlyDeps = lib.filterAttrs (
    name: _: !(lib.hasPrefix "mizchi/bit_" name || lib.hasPrefix "mizchi/bitx_" name)
  ) bitMod.deps;

  registry = callPackage ./nix/moon-registry.nix { } {
    registryIndexSrc = moonRegistryIndex;
    deps = registryOnlyDeps;
  };
in
stdenv.mkDerivation {
  pname = "bit";
  version = bitMod.version;

  src = lib.cleanSource ./.;

  nativeBuildInputs = [ moonbit ] ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];
  propagatedBuildInputs = [ git ];

  configurePhase = ''
    runHook preConfigure
    export HOME=$TMPDIR
    # The toolchain locates itself via MOON_TOOLCHAIN_ROOT, so MOON_HOME only
    # holds the registry. moon writes to it, hence the writable copy.
    export MOON_HOME=$TMPDIR/moon-home
    mkdir -p $MOON_HOME
    cp -r --no-preserve=mode ${registry}/registry $MOON_HOME/
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    moon build --target native --release modules/bit
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 \
      _build/native/release/build/mizchi/bit/bit.exe \
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
