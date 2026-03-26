# fix-ci

Investigate and fix CI failures, triggered by relay ci.status events.

## Trigger

Called when `bit relay ci pull` shows a failure, or when relay-agent detects `ci.status: fail`.

## Steps

1. **Get CI details**: Run `gh run list --repo <repo>` to find the failed run
2. **Read logs**: `gh run view <id> --log-failed` to get failure details
3. **Identify cause**: Parse the log output to find the root cause
4. **Fix**: Make the necessary code changes
5. **Test locally**: Run `just release-check` or relevant tests
6. **Report**: Push CI status update via `bit relay ci push <repo> --status pass --ref <ref>`

## Example

```bash
# Check failed CI
gh run view <run-id> --log-failed 2>&1 | tail -50

# After fixing
just release-check
git add -A && git commit -m "Fix CI: <description>"
bit relay ci push bit-vcs/bit --status pass --ref main
```

## Important

- Always run tests before reporting success
- If the fix is complex, create an issue instead of auto-fixing
- Never force push or make destructive changes without user approval
