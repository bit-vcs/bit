# Sub-Issues

`bit issue` supports parent-child relationships (sub-issues), allowing you to break large tasks into smaller units and track progress.

## Creating Sub-Issues

Use `--parent` (`-p`) to specify the parent issue ID.

```bash
# Create a parent issue
bit issue create --title "Auth refactoring"

# Create sub-issues
bit issue create --title "Fix token validation" --parent <parent-id>
bit issue create --title "Improve session management" -p <parent-id>
```

The `--parent=<id>` form is also supported.

## Listing Issues

By default, only top-level issues (those without a parent) are shown.

```bash
# Top-level only (default)
bit issue list

# All issues including sub-issues
bit issue list --all

# Sub-issues of a specific parent only
bit issue list --parent <parent-id>
```

Can be combined with `--state open` / `--state closed`.

## Viewing Details

`bit issue get` automatically displays parent info and sub-issues.

```bash
bit issue get <id>
```

Example output for a parent issue:

```
id iss-abc123
title Auth refactoring
state open
...
sub-issues:
  #iss-def456 [open] Fix token validation
  #iss-ghi789 [closed] Improve session management
```

For a child issue, parent info is shown:

```
id iss-def456
title Fix token validation
state open
parent iss-abc123
...
parent: #iss-abc123 Auth refactoring
```

## Data Model

- Issue has a `parent_id : String?` field
- Serialized as a `parent <id>` header line (only when parent_id is set)
- Backward compatible with existing issues that have no parent
- `parent_id` is preserved through close / reopen / update operations
- Auto-closing children when a parent is closed is out of scope

## Limitations

- No depth limit enforced (deep nesting is possible but not recommended)
- Reparenting (changing the parent) is not supported
- Tree view mode is not implemented
