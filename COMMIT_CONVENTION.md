# Commit Message Convention

All commit messages follow this format:

```
[TAG] Short summary in English (imperative, ≤72 chars)

Optional body explaining *why*, not just *what*.
Wrap at 72 characters.
```

---

## Tags

| Tag | When to use | Example |
|-----|-------------|---------|
| `[FEATURE]` | Add new user-facing functionality | `[FEATURE] Add tracking mode where target moves across screen` |
| `[FIX]` | Fix a bug or incorrect behaviour | `[FIX] Prevent target spawning outside arena bounds` |
| `[REFACTOR]` | Restructure code without changing behaviour | `[REFACTOR] Extract spawn logic into dedicated controller method` |
| `[DOCS]` | Documentation only — README, comments, guides | `[DOCS] Add iOS Xcode linking steps to SETUP.md` |
| `[CHORE]` | Build scripts, tooling, config — no production code | `[CHORE] Add VS Code workspace and doctor.sh` |
| `[TEST]` | Add or fix tests — no production code change | `[TEST] Add Rust unit test for game-over boundary condition` |
| `[STYLE]` | Formatting, whitespace — no logic change | `[STYLE] Run dart format across all screen files` |
| `[PERF]` | Performance improvement | `[PERF] Replace repeated FFI calls with single sync in tick` |
| `[SECURITY]` | Security-related change | `[SECURITY] Sanitize GameRule JSON before passing to engine` |
| `[RELEASE]` | Version bump or release preparation | `[RELEASE] Bump version to 1.1.0` |

---

## Rules

1. **Tag is mandatory.** Every commit must start with one of the tags above.
2. **Imperative mood.** Write "Add feature" not "Added feature" or "Adding feature".
3. **English only.** Tags and summary line are always in English.
4. **Summary ≤ 72 characters** (including the tag).
5. **Body is optional** but recommended for non-obvious changes — explain *why*, not *what*.
6. **One logical change per commit.** If you need two tags, split into two commits.

---

## Examples from this project

```
[FEATURE] Initial release of Patchi-Wani
[REFACTOR] Rename project from gochizou to patchi-wani; replace mascot
[DOCS] Prepare repository for public release on GitHub
[CHORE] Add VS Code workspace config and environment doctor script
[FIX] Correct target spawn interval after hit
[TEST] Add Rust unit test for difficulty scaling boundary
```

---

## Quick reference

```
[FEATURE]   new functionality users can see or touch
[FIX]       something was broken, now it works
[REFACTOR]  same behaviour, cleaner code
[DOCS]      only words changed, no code logic
[CHORE]     tooling, scripts, config files
[TEST]      tests added or fixed
[STYLE]     whitespace / formatting only
[PERF]      faster, leaner, less memory
[SECURITY]  closes a security concern
[RELEASE]   version bump or changelog update
```
