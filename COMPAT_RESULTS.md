# Compat Results

Date: 2026-02-05

Version: 0.6.1
Commit: 5469b4d978e3bd388fad34dc12d1a142a0ac9c0d

## Allowlist (tools/git-test-allowlist.txt)

Run: `just git-t-allowlist-shim-strict`

Result:
- success: 4650
- broken: 4
- failed: 0
- total: 4760
- pass rate: 97.7%

Missing prereq (skip): BIT_SHA256, EXPENSIVE, GPG, GPGSM, LONG_REF, MINGW, RFC1991, TTY

Note: allowlist was expanded after this run; re-run allowlist to refresh results.

Known breakage in allowlist:
- t5505-remote.sh: show stale with negative refspecs
- t5528-push-default.sh: matching
- t5610-clone-detached.sh: cloned HEAD is detached
- t2405-worktree-submodule.sh: submodule checked out after worktree add

## Allowlist Coverage (git/t)

- total tests: 1031
- allowlist: 610 (59.2%)
- outside allowlist: 421

## Outside Allowlist (Exploratory Runs)

## Failure Summary (high level)

- Pack / MIDX / bitmap / reuse / repack 系の差分が主要 (t53xx, t77xx)
- Partial clone / promisor / protocol v2 の端ケース (t0411, t5616, t5510)
- help/doc/porcelain 表示の差異 (t0012, t0450, t7502)
- cat-file の batch/all/unordered (t1006)
- bundle の sha256 list-heads (t6020)
- pager の exec-path 取り扱い (t7006)
- merge --continue (killed 状態) (t7600)
- scalar/git-shell の未実装 (t9210/t9211, t9850)

Overall:
- executed: 779 / 901 (86.5%)
- pass: 744
- fail: 35
- pass rate: 95.5%

### t0 (non-allowlist)

- executed: 75 / 75 (100%)
- pass: 72
- fail: 3

Failures:
- t0012-help.sh: `index-pack -h`, `pack-objects -h`, `receive-pack -h`, `upload-pack -h`
- t0411-clone-from-partial.sh: promisor remote fetch via `pack-objects` not executed
- t0450-txt-doc-vs-help.sh: help vs docs mismatch (52 known breakage; 11 failures)

### t1 (non-allowlist, complete)

- executed: 87 / 87 (100%)
- pass: 85
- fail: 2

Failures:
- t1006-cat-file.sh
  - known breakage: `--batch-check with %(rest)` (2 cases)
  - failures: `cat-file --batch-all-objects shows all objects`, `cat-file --unordered works`
- t1517-outside-repo.sh
  - known breakage: `git web--browse -h/--help-all` and `git whatchanged -h/--help-all` outside a repo

### t2 (non-allowlist, complete)

- executed: 51 / 51 (100%)
- pass: 51
- fail: 0


### t3 (non-allowlist, complete)

- executed: 105 / 105 (100%)
- pass: 105
- fail: 0


### t4 (non-allowlist, complete)

- executed: 135 / 135 (100%)
- pass: 135
- fail: 0


### t5 (non-allowlist, complete) — 2026-02-05 (re-run)

- executed: 5427 / 5427 (100%)
- pass: 5338
- fail: 0
- broken: 15

Failures (t5 re-run):
none

Known breakage (t5 re-run):
- t5505-remote.sh: show stale with negative refspecs
- t5528-push-default.sh: push from/to new branch fails with matching
- t5540-http-push-webdav.sh: force-with-lease + auth prompt cases
- t5572-pull-submodule.sh: replace submodule with file cases
- t5610-clone-detached.sh: detached HEAD detection
- t5801-remote-helpers.sh: pushing without marks


### t6 (non-allowlist, complete)

- executed: 85 / 85 (100%)
- pass: 85
- fail: 0


Failures (t6 so far):
none

### t7 (non-allowlist, complete)

- executed: 102 / 102 (100%)
- pass: 102
- fail: 0


Failures (t7 so far):
none

### t8 (non-allowlist, complete)

- executed: 16 / 16 (100%)
- pass: 16
- fail: 0


### t9 (non-allowlist, complete) — 2026-02-05 (re-run)

- executed: 1195 / 1195 (100%)
- pass: 1154
- fail: 0
- broken: 5

Failures (t9):
none

Known breakage (t9):
- t9001-send-email.sh: invalid smtp server port value (test 20)
- t9350-fast-export.sh: no exact-ref revisions included
- t9902-completion.sh: tilde expansion / push -d / push --delete (3 cases)

Notes:
- missing prereq: !AUTOIDENT GPG GPGSM HIGHLIGHT TTY WINDOWS
- skipped: t910x git-svn (svn not found), t9200 git-cvsexportcommit (cvs not found), t940x git-cvsserver (cvs not found), t960x cvsimport (cvs not found), t980x git-p4 (p4/p4d not found)

## Re-run Scripts

Allowlist (shim strict):
```bash
just git-t-allowlist-shim-strict
```

Single test:
```bash
just git-t-one t5302-pack-index.sh
```

Batch example (t9 selected):
```bash
for t in \
  t9001-send-email.sh \
  t9002-column.sh \
  t9003-help-autocorrect.sh \
  t9210-scalar.sh \
  t9211-scalar-clone.sh \
  t9300-fast-import.sh \
  t9301-fast-import-notes.sh \
  t9302-fast-import-unpack-limit.sh \
  t9303-fast-import-compression.sh \
  t9304-fast-import-marks.sh \
  t9305-fast-import-signatures.sh \
  t9306-fast-import-signed-tags.sh \
  t9350-fast-export.sh \
  t9351-fast-export-anonymize.sh \
  t9700-perl-git.sh \
  t9850-shell.sh \
  t9901-git-web--browse.sh \
  t9902-completion.sh \
  t9903-bash-prompt.sh
do
  just git-t-one "$t"
done
```
