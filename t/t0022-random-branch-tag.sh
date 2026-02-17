#!/bin/bash
#
# Randomized operation log focused on branch/tag/cherry-pick compatibility.

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
    declare -a tags
    declare -A next_id
    declare -A last_file
    declare -A commit_count

    branches=("main")
    tags=()
    next_id["main"]=0
    last_file["main"]=""
    commit_count["main"]=0

    local cur="main"
    local branch_seq=1
    local file=""
    local step=1

    echo "init" > "$out"

    file="${cur}_${next_id[$cur]}.txt"
    next_id[$cur]=$((next_id[$cur] + 1))
    last_file["$cur"]="$file"
    echo "commit-new $file seed${seed}_0" >> "$out"
    commit_count["$cur"]=$((commit_count["$cur"] + 1))

    while [ "$step" -le "$steps" ]; do
        local op
        rand_range 12
        op=$RAND_VALUE
        case "$op" in
            0)
                file="${cur}_${next_id[$cur]}.txt"
                next_id[$cur]=$((next_id[$cur] + 1))
                last_file["$cur"]="$file"
                commit_count["$cur"]=$((commit_count["$cur"] + 1))
                echo "commit-new $file seed${seed}_${step}" >> "$out"
                ;;
            1)
                if [ -n "${last_file[$cur]}" ]; then
                    echo "commit-mod ${last_file[$cur]} seed${seed}_${step}" >> "$out"
                else
                    file="${cur}_${next_id[$cur]}.txt"
                    next_id[$cur]=$((next_id[$cur] + 1))
                    last_file["$cur"]="$file"
                    commit_count["$cur"]=$((commit_count["$cur"] + 1))
                    echo "commit-new $file seed${seed}_${step}" >> "$out"
                fi
                ;;
            2)
                if [ -n "${last_file[$cur]}" ] && [ "${commit_count[$cur]}" -gt 0 ]; then
                    echo "commit-rm ${last_file[$cur]}" >> "$out"
                    last_file["$cur"]=""
                    commit_count["$cur"]=$((commit_count["$cur"] - 1))
                    if [ "${commit_count[$cur]}" -lt 0 ]; then
                        commit_count["$cur"]=0
                    fi
                else
                    file="${cur}_${next_id[$cur]}.txt"
                    next_id[$cur]=$((next_id[$cur] + 1))
                    last_file["$cur"]="$file"
                    commit_count["$cur"]=$((commit_count["$cur"] + 1))
                    echo "commit-new $file seed${seed}_${step}" >> "$out"
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
                    echo "branch $b" >> "$out"
                else
                    file="${cur}_${next_id[$cur]}.txt"
                    next_id[$cur]=$((next_id[$cur] + 1))
                    last_file["$cur"]="$file"
                    commit_count["$cur"]=$((commit_count["$cur"] + 1))
                    echo "commit-new $file seed${seed}_${step}" >> "$out"
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
                    echo "switch $target" >> "$out"
                    cur="$target"
                else
                    file="${cur}_${next_id[$cur]}.txt"
                    next_id[$cur]=$((next_id[$cur] + 1))
                    last_file["$cur"]="$file"
                    commit_count["$cur"]=$((commit_count["$cur"] + 1))
                    echo "commit-new $file seed${seed}_${step}" >> "$out"
                fi
                ;;
            5)
                local tag="tag_${seed}_${step}"
                echo "tag $tag" >> "$out"
                tags+=("$tag")
                ;;
            6)
                if [ "${#branches[@]}" -gt 1 ]; then
                    local idx
                    rand_range "${#branches[@]}"
                    idx=$RAND_VALUE
                    local target="${branches[$idx]}"
                    if [ "$target" = "$cur" ]; then
                        idx=$(( (idx + 1) % ${#branches[@]} ))
                        target="${branches[$idx]}"
                    fi
                    echo "cherry-pick $target" >> "$out"
                else
                    file="${cur}_${next_id[$cur]}.txt"
                    next_id[$cur]=$((next_id[$cur] + 1))
                    last_file["$cur"]="$file"
                    commit_count["$cur"]=$((commit_count["$cur"] + 1))
                    echo "commit-new $file seed${seed}_${step}" >> "$out"
                fi
                ;;
            7)
                if [ "${#tags[@]}" -gt 0 ]; then
                    local idx
                    rand_range "${#tags[@]}"
                    idx=$RAND_VALUE
                    local tag_name="${tags[$idx]}"
                    echo "tag-del $tag_name" >> "$out"
                else
                    local tag="tag_${seed}_${step}"
                    echo "tag $tag" >> "$out"
                    tags+=("$tag")
                fi
                ;;
            8)
                echo "status" >> "$out"
                ;;
            9)
                echo "pack-objects" >> "$out"
                ;;
            10)
                echo "index-pack" >> "$out"
                ;;
            11)
                if [ "$((RAND_VALUE % 2))" -eq 0 ]; then
                    echo "repack" >> "$out"
                else
                    echo "gc" >> "$out"
                fi
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
            tag-del)
                $run_cmd tag -d "$arg1" >/dev/null 2>&1 || true
                ;;
            cherry-pick)
                local pick
                pick=$($run_cmd rev-parse "$arg1" 2>/dev/null || true)
                if [ -n "$pick" ]; then
                    if ! $run_cmd cherry-pick "$pick" >/dev/null 2>&1; then
                        $run_cmd cherry-pick --abort >/dev/null 2>&1 || true
                    fi
                fi
                ;;
            status)
                $run_cmd status --porcelain >/dev/null
                ;;
            pack-objects)
                if ! $run_cmd rev-parse --verify HEAD >/dev/null 2>&1; then
                    continue
                fi
                local pack_stem=".git/objects/pack/compat"
                $run_cmd rev-parse HEAD | $run_cmd pack-objects "$pack_stem" >/dev/null 2>&1 || true
                ;;
            index-pack)
                local pack_file
                pack_file=$(ls .git/objects/pack/*.pack 2>/dev/null | head -n 1 || true)
                if [ -n "$pack_file" ]; then
                    $run_cmd index-pack "$pack_file" >/dev/null 2>&1 || true
                fi
                ;;
            repack)
                $run_cmd repack -a -d >/dev/null 2>&1 || true
                ;;
            gc)
                $run_cmd gc >/dev/null 2>&1 || true
                ;;
            *)
                echo "unknown op: $op" >&2
                return 1
                ;;
        esac
    done < "$opfile"

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
    [ "$status_git" = "$status_bit" ]
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

run_cases() {
    local seeds="${GIT_COMPAT_T0022_SEEDS:-1101 1102 1103}"
    local steps="${GIT_COMPAT_T0022_STEPS:-50}"
    local max_branches="${GIT_COMPAT_T0022_MAX_BRANCHES:-4}"

    for seed in $seeds; do
      test_expect_success "random branch/tag/cherry-pick ops seed=${seed}" "
        run_case ${seed} ${steps} ${max_branches}
      "
    done
}

run_cases

test_done
