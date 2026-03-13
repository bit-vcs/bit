#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import shutil
import statistics
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


def run_command(
    args: list[str],
    *,
    cwd: Path | None = None,
    capture: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=str(cwd) if cwd is not None else None,
        check=True,
        text=True,
        capture_output=capture,
    )


def gh_json(args: list[str], *, cwd: Path | None = None) -> object:
    result = run_command(["gh", *args], cwd=cwd)
    return json.loads(result.stdout)


def read_allowlist(path: Path) -> list[str]:
    items: list[str] = []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        items.append(line)
    return items


def read_weights(path: Path) -> dict[str, int]:
    weights: dict[str, int] = {}
    if not path.exists():
        return weights
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.replace("\t", " ").split()
        if len(parts) < 2:
            continue
        try:
            value = int(parts[1])
        except ValueError:
            continue
        weights[parts[0]] = max(1, value)
    return weights


def collect_run_ids(repo: str, workflow: str, branch: str, limit: int) -> list[int]:
    payload = gh_json(
        [
            "run",
            "list",
            "-R",
            repo,
            "--workflow",
            workflow,
            "--branch",
            branch,
            "--limit",
            str(max(limit * 4, 20)),
            "--json",
            "databaseId,status,conclusion",
        ]
    )
    run_ids: list[int] = []
    for item in payload:
        if item["status"] != "completed":
            continue
        run_ids.append(int(item["databaseId"]))
        if len(run_ids) == limit:
            break
    return run_ids


def list_artifacts(repo: str, run_id: int) -> list[str]:
    payload = gh_json([ "api", f"/repos/{repo}/actions/runs/{run_id}/artifacts" ])
    return [artifact["name"] for artifact in payload.get("artifacts", [])]


def download_timing_artifacts(
    repo: str,
    run_ids: list[int],
    temp_root: Path,
) -> list[int]:
    downloaded: list[int] = []
    for run_id in run_ids:
        artifact_names = list_artifacts(repo, run_id)
        timing_names = sorted(
            name for name in artifact_names if name.startswith("test-timing-shard-")
        )
        if not timing_names:
            continue
        target_dir = temp_root / str(run_id)
        target_dir.mkdir(parents=True, exist_ok=True)
        run_command(
            [
                "gh",
                "run",
                "download",
                str(run_id),
                "-R",
                repo,
                *sum([["-n", name] for name in timing_names], []),
            ],
            cwd=target_dir,
            capture=True,
        )
        downloaded.append(run_id)
    return downloaded


def iter_timing_files(root: Path) -> list[Path]:
    return sorted(root.glob("*/*/test-timing-shard-*.tsv"))


def aggregate_weights(
    timing_root: Path,
    allowlist: list[str],
    fallback: dict[str, int],
    stat: str,
) -> tuple[dict[str, int], dict[str, list[int]]]:
    samples: dict[str, list[int]] = {}
    for timing_file in iter_timing_files(timing_root):
        for raw in timing_file.read_text().splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            name, value = line.split("\t", 1)
            samples.setdefault(name, []).append(int(value))

    weights: dict[str, int] = {}
    for name in allowlist:
        values = samples.get(name)
        if values:
            if stat == "mean":
                computed = int(sum(values) / len(values) + 0.5)
            else:
                computed = int(statistics.median(values) + 0.5)
            weights[name] = max(1, computed)
        else:
            weights[name] = fallback.get(name, 1)
    return weights, samples


def assign_shards(
    allowlist: list[str],
    weights: dict[str, int],
    shard_total: int,
) -> tuple[list[int], dict[str, int]]:
    loads = [0] * shard_total
    shard_of: dict[str, int] = {}
    indexed = list(enumerate(allowlist))
    indexed.sort(key=lambda item: (-weights.get(item[1], 1), item[0], item[1]))
    for position, name in indexed:
        shard = min(range(shard_total), key=lambda idx: (loads[idx], idx))
        loads[shard] += weights.get(name, 1)
        shard_of[name] = shard
    return loads, shard_of


def evaluate_assignment(
    allowlist: list[str],
    shard_of: dict[str, int],
    weights: dict[str, int],
    shard_total: int,
) -> list[int]:
    loads = [0] * shard_total
    for name in allowlist:
        loads[shard_of[name]] += weights.get(name, 1)
    return loads


def format_header(
    *,
    repo: str,
    branch: str,
    workflow: str,
    stat: str,
    run_ids: list[int],
) -> str:
    run_list = ",".join(str(run_id) for run_id in run_ids)
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return "\n".join(
        [
            "# Estimated per-script runtime weights (seconds) for git-compat sharding",
            f"# Source repo: {repo}",
            f"# Source workflow: {workflow}",
            f"# Source branch: {branch}",
            f"# Aggregation: {stat}",
            f"# Source runs: {run_list}",
            f"# Generated: {generated}",
        ]
    )


def write_weights_file(
    output: Path,
    allowlist: list[str],
    weights: dict[str, int],
    header: str,
) -> None:
    lines = [header]
    for name in allowlist:
        lines.append(f"{name}\t{weights[name]}")
    output.write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default="bit-vcs/bit")
    parser.add_argument("--branch", default="main")
    parser.add_argument("--workflow", default="CI")
    parser.add_argument("--runs", type=int, default=10)
    parser.add_argument("--shards", type=int, default=10)
    parser.add_argument("--stat", choices=["median", "mean"], default="median")
    parser.add_argument("--allowlist", default="tools/git-test-allowlist.txt")
    parser.add_argument("--output", default="tools/git-test-runtime-seconds.tsv")
    parser.add_argument("--input-dir")
    args = parser.parse_args()

    repo_root = Path.cwd()
    allowlist_path = repo_root / args.allowlist
    output_path = repo_root / args.output
    allowlist = read_allowlist(allowlist_path)
    current_weights = read_weights(output_path)

    temp_root: Path | None = None
    timing_root: Path
    source_run_ids: list[int]
    if args.input_dir:
        timing_root = Path(args.input_dir)
        source_run_ids = sorted(
            int(path.name)
            for path in timing_root.iterdir()
            if path.is_dir() and path.name.isdigit()
        )
    else:
        temp_root = Path(tempfile.mkdtemp(prefix="bit-git-test-runtime-"))
        run_ids = collect_run_ids(args.repo, args.workflow, args.branch, args.runs)
        source_run_ids = download_timing_artifacts(args.repo, run_ids, temp_root)
        timing_root = temp_root

    new_weights, samples = aggregate_weights(
        timing_root,
        allowlist,
        current_weights,
        args.stat,
    )

    _, current_assignment = assign_shards(allowlist, current_weights, args.shards)
    optimized_loads, optimized_assignment = assign_shards(
        allowlist,
        new_weights,
        args.shards,
    )
    current_empirical = evaluate_assignment(
        allowlist,
        current_assignment,
        new_weights,
        args.shards,
    )
    optimized_empirical = evaluate_assignment(
        allowlist,
        optimized_assignment,
        new_weights,
        args.shards,
    )

    header = format_header(
        repo=args.repo,
        branch=args.branch,
        workflow=args.workflow,
        stat=args.stat,
        run_ids=source_run_ids,
    )
    write_weights_file(output_path, allowlist, new_weights, header)

    changed = [
        (name, current_weights.get(name, 1), new_weights[name], len(samples.get(name, [])))
        for name in allowlist
        if current_weights.get(name, 1) != new_weights[name]
    ]
    print(f"timing files: {len(iter_timing_files(timing_root))}")
    print(f"runs used: {len(source_run_ids)}")
    print(f"weights changed: {len(changed)}")
    print(f"current assignment on refreshed weights: {current_empirical}")
    print(f"optimized assignment on refreshed weights: {optimized_empirical}")
    if changed:
        print("largest changes:")
        for name, old, new, sample_count in sorted(
            changed,
            key=lambda item: (abs(item[2] - item[1]), item[0]),
            reverse=True,
        )[:20]:
            print(f"  {name}: {old} -> {new} (samples={sample_count})")

    if temp_root is not None:
        shutil.rmtree(temp_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
