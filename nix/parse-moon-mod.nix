# Parse a pkl-format `moon.mod` into an attrset compatible with the old
# `moon.mod.json` shape ({ name, version, deps }), so the Nix build can keep
# reading the module manifest after the migration away from moon.mod.json.
#
# The pkl format used by moon looks like:
#   name = "mizchi/bit"
#   version = "0.43.2"
#   import {
#     "moonbitlang/async@0.19.4",
#     "mizchi/simd@0.4.1",
#     ...
#   }
{ lib }:
path:
let
  text = builtins.readFile path;
  lines = lib.splitString "\n" text;

  # First capture group of the first line matching `re`, or `default`.
  firstMatch = re: default:
    let
      matches = lib.filter (m: m != null) (map (l: builtins.match re l) lines);
    in
    if matches == [ ] then default else builtins.elemAt (builtins.head matches) 0;

  name = firstMatch ''name = "([^"]+)".*'' null;
  version = firstMatch ''version = "([^"]+)".*'' null;

  # Import lines look like `  "owner/pkg@1.2.3",`. Capture (pkg, version).
  depMatches = lib.filter (m: m != null) (
    map (l: builtins.match ''[[:space:]]*"([^"@]+)@([^"]+)",?[[:space:]]*'' l) lines
  );
  deps = builtins.listToAttrs (
    map (m: {
      name = builtins.elemAt m 0;
      value = builtins.elemAt m 1;
    }) depMatches
  );
in
{ inherit name version deps; }
