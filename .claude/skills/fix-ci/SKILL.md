---
name: fix-ci
description: "Investigate and fix CI failures. Use when: debugging failed GitHub Actions runs, fixing build/test failures, or processing ci.status relay events."
---

# fix-ci

Investigate and fix CI failures.

## Trigger

- User reports a CI failure
- `gh run list` shows a failed run
- Relay event: `ci.status: fail` (optional, requires relay)

## Steps

1. **Get CI details**: `gh run list --repo <repo>` to find the failed run
2. **Read logs**: `gh run view <id> --log-failed` to get failure details
3. **Identify cause**: Parse the log output to find the root cause
4. **Fix**: Make the necessary code changes
5. **Test locally**: Run `just release-check` or relevant tests
6. **Report**:
   ```bash
   # Commit the fix
   git add -A && git commit -m "Fix CI: <description>"
   # Via relay (optional)
   bit relay ci push <repo> --status pass --ref <ref>
   ```

## Important

- Always run tests before reporting success
- If the fix is complex, create a bit issue instead of auto-fixing
- Never force push or make destructive changes without user approval
