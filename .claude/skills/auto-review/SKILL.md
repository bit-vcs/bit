---
name: auto-review
description: "Review code changes and provide structured feedback. Use when: reviewing PRs, analyzing code diffs for bugs/security/style, or processing review.request relay events."
---

# auto-review

Review code changes and provide structured feedback.

## Trigger

- User requests a code review
- `bit pr list` shows PRs awaiting review
- Relay event: `review.request` (optional, requires relay)

## Steps

1. **Get PR details**: `bit pr get <id>` or `git diff <base>...<head>`
2. **Analyze changes**: Check for:
   - Bugs and logic errors
   - Security vulnerabilities (OWASP top 10)
   - Code style and consistency
   - Test coverage
   - Performance implications
3. **Write review**: Provide constructive, specific feedback
4. **Submit verdict**:
   ```bash
   # Local (bit pr)
   bit pr review <pr-id> --approve --commit <hex> --body "LGTM"
   # Via relay (optional)
   bit relay review submit <repo> --pr <id> --verdict approve
   ```

## Review format

```
## Summary
Brief description of what the PR does.

## Findings
- [severity] file:line — description

## Verdict
approve/request-changes with reasoning
```

## Important

- Be constructive, not just critical
- Approve if changes are correct even if style differs from preference
- Flag security issues as blocking
- For MoonBit code, check for common issues: unused variables, missing error handling, type mismatches
