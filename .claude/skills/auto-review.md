# auto-review

Review code changes and provide feedback, triggered by relay review.request events.

## Trigger

Called when `bit relay review list` shows a pending review request, or when relay-agent detects `review.request`.

## Steps

1. **Get PR details**: Read the PR diff using `git diff` or `gh pr diff <id>`
2. **Analyze changes**: Check for:
   - Bugs and logic errors
   - Security vulnerabilities (OWASP top 10)
   - Code style and consistency
   - Test coverage
   - Performance implications
3. **Write review**: Provide constructive, specific feedback
4. **Submit verdict**: `bit relay review submit <repo> --pr <id> --verdict approve/reject`

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
