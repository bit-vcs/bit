#!/bin/sh
set -eu

usage() {
	echo "usage: $0 <target-dir>" >&2
	exit 1
}

target_dir="${1:-}"
test -n "$target_dir" || usage

mkdir -p "$target_dir"

init_repo() {
	repo_dir="$1"
	file_name="$2"
	file_content="$3"
	commit_message="$4"

	mkdir -p "$repo_dir"
	(
		cd "$repo_dir"
		git init -q
		# Pin the branch rather than inheriting the host's default. Tests built
		# on this fixture name `main`, and git still defaults to `master` where
		# init.defaultBranch is unset. Setting HEAD while it is unborn works on
		# every git version, unlike `git init -b`.
		git symbolic-ref HEAD refs/heads/main
		git config user.email "fixture@example.com"
		git config user.name "Fixture User"
		printf "%s\n" "$file_content" > "$file_name"
		git add "$file_name"
		git commit -q -m "$commit_message"
	)
}

init_repo "$target_dir" "root.txt" "root-v1" "root init"
init_repo "$target_dir/dep" "dep.txt" "dep-v1" "dep init"
init_repo "$target_dir/leaf" "leaf.txt" "leaf-v1" "leaf init"
init_repo "$target_dir/extra" "extra.txt" "extra-v1" "extra init"
