#!/bin/bash
#
# Randomized operation log with rebase-heavy flow for git compatibility.

source "$(dirname "$0")/test-lib-e2e.sh"

LCG_STATE=0
RAND_VALUE=0

lcg_next() {
  LCG_STATE=$(( (LCG_STATE * 1103515245 + 12345) & 0x7fffffff ))
}

rand_range() {
  local n="$1"
  if [ "$n" -le 0 ]; then
    RAND_VALUE=0
    return
  fi
  lcg_next
  RAND_VALUE=$(( LCG_STATE % n ))
}

gen_ops() {
  local seed="$1"
  local steps="$2"
  local max_branches="$3"
  local out="$4"

  LCG_STATE="$seed"

  declare -a branches
  declare -A next_id
  declare -A last_file
  declare -A commit_count

  branches=("main")
  next_id["main"]=0
  last_file["main"]=""
  commit_count["main"]=0

  local cur="main"
  local branch_seq=1
  local file=""

  echo "init" >"$out"

  file="${cur}_${next_id[$cur]}.txt"
  next_id[$cur]=$((next_id[$cur] + 1))
  last_file[$cur]="$file"
  commit_count[$cur]=$((commit_count[$cur] + 1))
  echo "commit-new $file seed${seed}_0" >>"$out"

  local step=1
  while [ "$step" -le "$steps" ]; do
    local op
    rand_range 10
    op=$RAND_VALUE
    case "$op" in
      0)
        file="${cur}_${next_id[$cur]}.txt"
        next_id[$cur]=$((next_id[$cur] + 1))
        last_file[$cur]="$file"
        commit_count[$cur]=$((commit_count[$cur] + 1))
        echo "commit-new $file seed${seed}_${step}" >>"$out"
        ;;
      1)
        if [ -n "${last_file[$cur]}" ]; then
          echo "commit-mod ${last_file[$cur]} seed${seed}_${step}" >>"$out"
        else
          file="${cur}_${next_id[$cur]}.txt"
          next_id[$cur]=$((next_id[$cur] + 1))
          last_file[$cur]="$file"
          commit_count[$cur]=$((commit_count[$cur] + 1))
          echo "commit-new $file seed${seed}_${step}" >>"$out"
        fi
        ;;
      2)
        if [ -n "${last_file[$cur]}" ]; then
          echo "commit-rm ${last_file[$cur]}" >>"$out"
          commit_count[$cur]=$((commit_count[$cur] - 1))
          if [ "${commit_count[$cur]}" -lt 0 ]; then
            commit_count[$cur]=0
          fi
          last_file[$cur]=""
        else
          file="${cur}_${next_id[$cur]}.txt"
          next_id[$cur]=$((next_id[$cur] + 1))
          last_file[$cur]="$file"
          commit_count[$cur]=$((commit_count[$cur] + 1))
          echo "commit-new $file seed${seed}_${step}" >>"$out"
        fi
        ;;
      3)
        if [ "${#branches[@]}" -lt "$max_branches" ]; then
          local b="b${branch_seq}"
          branch_seq=$((branch_seq + 1))
          branches+=("$b")
          next_id["$b"]=0
          last_file["$b"]=""
          commit_count["$b"]=0
          echo "branch $b" >>"$out"
        else
          file="${cur}_${next_id[$cur]}.txt"
          next_id[$cur]=$((next_id[$cur] + 1))
          last_file[$cur]="$file"
          commit_count[$cur]=$((commit_count[$cur] + 1))
          echo "commit-new $file seed${seed}_${step}" >>"$out"
        fi
        ;;
      4)
        if [ "${#branches[@]}" -gt 1 ]; then
          local idx
          rand_range "${#branches[@]}"
          idx=$RAND_VALUE
          local target="${branches[$idx]}"
          if [ "$target" = "$cur" ]; then
            idx=$(( (idx + 1) % ${#branches[@]} ))
            target="${branches[$idx]}"
          fi
          echo "switch $target" >>"$out"
          cur="$target"
        else
          file="${cur}_${next_id[$cur]}.txt"
          next_id[$cur]=$((next_id[$cur] + 1))
          last_file[$cur]="$file"
          commit_count[$cur]=$((commit_count[$cur] + 1))
          echo "commit-new $file seed${seed}_${step}" >>"$out"
        fi
        ;;
      5)
        if [ "$cur" != "main" ] && [ "${#branches[@]}" -gt 1 ] && [ "${commit_count[$cur]}" -gt 0 ]; then
          echo "rebase main" >>"$out"
        else
          file="${cur}_${next_id[$cur]}.txt"
          next_id[$cur]=$((next_id[$cur] + 1))
          last_file[$cur]="$file"
          commit_count[$cur]=$((commit_count[$cur] + 1))
          echo "commit-new $file seed${seed}_${step}" >>"$out"
        fi
        ;;
      6)
        echo "status" >>"$out"
        ;;
      7)
        echo "tag t${seed}_${step}" >>"$out"
        ;;
      8)
        echo "switch main" >>"$out"
        cur="main"
        ;;
      9)
        file="${cur}_${next_id[$cur]}.txt"
        next_id[$cur]=$((next_id[$cur] + 1))
        last_file[$cur]="$file"
        commit_count[$cur]=$((commit_count[$cur] + 1))
        echo "commit-new $file seed${seed}_${step}" >>"$out"
        ;;
    esac
    step=$((step + 1))
  done
}

apply_ops() {
  local tool="$1"
  local repo="$2"
  local opfile="$3"

  local run_cmd
  if [ "$tool" = "git" ]; then
    run_cmd="git"
  else
    run_cmd="git_cmd"
  fi

  local base_date=1700000000
  local commit_seq=0

  mkdir -p "$repo"
  local old_dir
  old_dir=$(pwd)
  cd "$repo"

  while read -r op arg1 arg2; do
    case "$op" in
      init)
        $run_cmd init
        ;;
      branch)
        $run_cmd branch "$arg1"
        ;;
      switch)
        $run_cmd switch "$arg1"
        ;;
      rebase)
        local ts=$((base_date + commit_seq))
        if [ "$arg1" = "main" ]; then
          GIT_AUTHOR_DATE="${ts} +0000" GIT_COMMITTER_DATE="${ts} +0000" \
            $run_cmd rebase "$arg1" || {
              GIT_AUTHOR_DATE="${ts} +0000" GIT_COMMITTER_DATE="${ts} +0000" \
                $run_cmd rebase --abort >/dev/null 2>&1 || true
            }
          commit_seq=$((commit_seq + 1))
        fi
        ;;
      commit-new)
        local ts=$((base_date + commit_seq))
        echo "$arg2" > "$arg1"
        $run_cmd add "$arg1"
        GIT_AUTHOR_DATE="${ts} +0000" GIT_COMMITTER_DATE="${ts} +0000" \
          $run_cmd commit -m "commit $commit_seq"
        commit_seq=$((commit_seq + 1))
        ;;
      commit-mod)
        local ts=$((base_date + commit_seq))
        echo "$arg2" >> "$arg1"
        $run_cmd add "$arg1"
        GIT_AUTHOR_DATE="${ts} +0000" GIT_COMMITTER_DATE="${ts} +0000" \
          $run_cmd commit -m "commit $commit_seq"
        commit_seq=$((commit_seq + 1))
        ;;
      commit-rm)
        local ts=$((base_date + commit_seq))
        $run_cmd rm "$arg1"
        GIT_AUTHOR_DATE="${ts} +0000" GIT_COMMITTER_DATE="${ts} +0000" \
          $run_cmd commit -m "commit $commit_seq"
        commit_seq=$((commit_seq + 1))
        ;;
      tag)
        $run_cmd tag "$arg1"
        ;;
      status)
        $run_cmd status --porcelain >/dev/null
        ;;
    esac
  done <"$opfile"

  cd "$old_dir"
}

compare_repos() {
  local repo_git="$1"
  local repo_bit="$2"

  git -C "$repo_git" fsck --strict
  git -C "$repo_bit" fsck --strict

  local heads_git
  local heads_bit
  heads_git=$(git -C "$repo_git" for-each-ref --format='%(refname:short)' refs/heads | sort)
  heads_bit=$(git -C "$repo_bit" for-each-ref --format='%(refname:short)' refs/heads | sort)
  [ "$heads_git" = "$heads_bit" ]

  local b
  for b in $heads_git; do
    local tree_git
    local tree_bit
    tree_git=$(git -C "$repo_git" rev-parse "$b^{tree}")
    tree_bit=$(git -C "$repo_bit" rev-parse "$b^{tree}")
    [ "$tree_git" = "$tree_bit" ]
  done

  local status_git
  local status_bit
  status_git=$(git -C "$repo_git" status --porcelain)
  status_bit=$(git -C "$repo_bit" status --porcelain)
  [ -z "$status_git" ]
  [ -z "$status_bit" ]
}

run_case() {
  local seed="$1"
  local steps="$2"
  local max_branches="$3"
  local work="$TRASH_DIR/work_$seed"
  mkdir -p "$work"

  local ops="$work/ops.log"
  gen_ops "$seed" "$steps" "$max_branches" "$ops"

  apply_ops git "$work/repo_git" "$ops"
  apply_ops bit "$work/repo_bit" "$ops"

  compare_repos "$work/repo_git" "$work/repo_bit"
}

test_expect_success 'random rebase ops seed=501' '
  run_case 501 50 5
'

test_expect_success 'random rebase ops seed=502' '
  run_case 502 50 5
'

test_done
