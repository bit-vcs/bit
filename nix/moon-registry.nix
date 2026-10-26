# Offline mooncakes registry for `moon build` inside the Nix sandbox.
#
# moonbit-overlay dropped its moonPlatform registry builders, so this keeps the
# small part bit needs: walk the dependency closure through the locked registry
# index, fetch each package zip by its index checksum, and lay the result out
# as $MOON_HOME/registry/{index,cache}. moon then resolves everything from the
# cache without network access.
{
  lib,
  fetchurl,
  runCommand,
}:
{
  registryIndexSrc, # checkout of https://mooncakes.io/git/index
  deps, # attrset<name: string, version: string>
  moonCacheUri ? "https://moonbitlang-mooncakes.s3.us-west-2.amazonaws.com",
}:
let
  # Parse $MOON_HOME/registry/index/user/<user>/<package>.index (JSON lines)
  # into attrset<version, record>.
  readIndex =
    name:
    let
      lines = lib.filter (s: s != "") (
        lib.splitString "\n" (builtins.readFile "${registryIndexSrc}/user/${name}.index")
      );
    in
    builtins.listToAttrs (
      map (
        line:
        let
          record = builtins.fromJSON line;
        in
        {
          name = record.version;
          value = record;
        }
      ) lines
    );

  # Every name@version reachable from `deps`. moon's MVS picks one version per
  # module at build time; caching every version in the closure is harmless.
  closure =
    pending: seen:
    if pending == [ ] then
      seen
    else
      let
        head = builtins.head pending;
        key = "${head.name}@${head.version}";
        record = (readIndex head.name).${head.version};
        next = lib.mapAttrsToList (name: version: { inherit name version; }) (record.deps or { });
      in
      if seen ? ${key} then
        closure (builtins.tail pending) seen
      else
        closure (builtins.tail pending ++ next) (seen // { ${key} = record; });

  records = builtins.attrValues (
    closure (lib.mapAttrsToList (name: version: { inherit name version; }) deps) { }
  );

  install =
    record:
    let
      zip = fetchurl {
        url = "${moonCacheUri}/user/${record.name}/${record.version}.zip";
        sha256 = record.checksum;
      };
    in
    "install -Dm644 ${zip} $out/registry/cache/${record.name}/${record.version}.zip";
in
runCommand "moon-registry" { } ''
  mkdir -p $out/registry/index
  cp -r ${registryIndexSrc}/. $out/registry/index/
  ${lib.concatMapStringsSep "\n" install records}
''
