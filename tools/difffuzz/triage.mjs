#!/usr/bin/env node
// Group FAILURE.txt reports under an --out directory by their first
// problem (kind + command), so recurring bugs are counted once.
//   node tools/difffuzz/triage.mjs [OUT_DIR]
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const out = path.resolve(process.argv[2] ?? path.join(os.tmpdir(), "bit-difffuzz"));
const groups = new Map();
for (const name of fs.readdirSync(out)) {
  const f = path.join(out, name, "FAILURE.txt");
  if (!fs.existsSync(f)) continue;
  const lines = fs.readFileSync(f, "utf8").split("\n");
  const first = lines[3] ?? "";
  let key;
  let m;
  if ((m = first.match(/^exit status differs for `([^`]*)`.*git=(\S+) bit=(\S+)/))) {
    const cmd = m[1].split(" ").filter((t) => t.startsWith("-") || /^[a-z-]+$/.test(t)).slice(0, 3).join(" ");
    key = `exit ${cmd}: git=${m[2] === "0" ? "ok" : "fail"} bit=${m[3] === "0" ? "ok" : "fail"}`;
  } else if (first.startsWith("state differs")) {
    const fields = lines.slice(4, 30).filter((l) => /^  \[/.test(l)).map((l) => l.trim()).join(",");
    const log = lines.filter((l) => l.startsWith("  $ ") || l.startsWith("  # "));
    const lastCmd = [...log].reverse().find((l) => l.startsWith("  $ ")) ?? "";
    const cmd = lastCmd.replace(/^ {2}\$ git /, "").split("   #")[0].split(" ").filter((t) => t.startsWith("-") || /^[a-z-]+$/.test(t)).slice(0, 3).join(" ");
    key = `state ${fields} after \`${cmd}\``;
  } else if (first.startsWith("git fsck")) {
    key = `fsck: ${(lines[4] ?? "").replace(/[0-9a-f]{40}/g, "<id>")}`;
  } else {
    key = first.replace(/[0-9a-f]{40}/g, "<id>").slice(0, 120);
  }
  if (!groups.has(key)) groups.set(key, []);
  groups.get(key).push(name);
}
const sorted = [...groups.entries()].sort((a, b) => b[1].length - a[1].length);
for (const [key, runs] of sorted) console.log(`${String(runs.length).padStart(3)}  ${key}\n       e.g. ${runs.slice(0, 3).join(" ")}`);
