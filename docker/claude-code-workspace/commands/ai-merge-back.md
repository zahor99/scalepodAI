---
description: Rebase feature branch onto base branch, resolve any conflicts with AI, and merge back
---

Merge the current feature branch back into its base branch using rebase. Follow these steps carefully.

## Step 1 — Identify branches and verify state

Run these:
- `git branch --show-current` → this is the **feature branch**
- `echo $BRANCH` → this is the **base branch**
- `git status` → must be clean

Confirm you are on the feature branch. If there are uncommitted changes, commit them first with a descriptive message before continuing.

## Step 2 — Rebase onto latest base

```
git fetch origin
git rebase origin/$BRANCH
```

If the rebase completes with no conflicts, skip directly to **Step 4**.
If there are conflicts, follow **Step 3** for each conflict round.

## Step 3 — Conflict resolution (only if rebase paused)

The rebase may pause multiple times. For EACH pause, follow this process completely before running `git rebase --continue`.

**3a. Identify conflicts**
Run `git status` to see all files with conflicts.

**3b. Analyze each conflicting file**

For each file:

- **Read the ENTIRE file** — you need the surrounding code, comments, and docstrings to understand context, not just the conflict markers
- **Check recent history on both branches:**
  - `git log --oneline -5 -- <file>` (feature branch commits)
  - `git log --oneline -5 origin/$BRANCH -- <file>` (base branch commits)
- **For each conflict block** (`<<<<<<<` to `>>>>>>>`):
  - **Ours** (above `=======`) = feature branch changes being replayed
  - **Theirs** (below `=======`) = current base branch state
  - Read any comments or docstrings near the conflict — they explain the *intent*
  - Check if either side introduced imports, dependencies, or config the other side also needs

**3c. Resolve using the right strategy**

Pick the strategy based on what kind of conflict it is:
- **Both sides add different things** (new functions, new config entries) → keep BOTH additions
- **Both sides modify the same logic** → understand WHY each change was made. If feature adds a capability and base fixes a bug, you need BOTH
- **One side deletes code the other modified** → read commit messages and comments to understand if deletion was intentional cleanup or if modifications are still needed
- **Import conflicts** → merge both import sets, deduplicate
- **Formatting-only** → prefer base branch unless feature formatting was intentional (e.g., lint fix)

**3d. Verify each resolved file**
- Zero leftover conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
- No duplicate functions, imports, or declarations
- Brackets, parens, indentation all correct
- Code reads coherently top to bottom

**3e. Stage and continue**
```
git add .
git rebase --continue
```

Keep detailed notes of every resolution (file, what each side did, your strategy, any judgment calls).

If >10 conflict rounds, run `git rebase --abort` and explain the situation rather than risk a bad resolution.

## Step 4 — Push rebased feature branch

```
git push --force-with-lease origin HEAD
```

## Step 5 — Merge into base and push

```
git checkout $BRANCH
git pull origin $BRANCH
git merge $FEATURE_BRANCH
git push origin $BRANCH
```

The merge should be fast-forward after rebase. If it is NOT fast-forward, STOP and explain — do not force it.

## Step 6 — Report

Provide a summary:
- Branches involved (feature → base)
- Whether the rebase was clean or had conflicts
- If there were conflicts, for EACH one:
  - **File**: path
  - **Feature side**: what the feature branch was doing
  - **Base side**: what the base branch changed
  - **Resolution**: what you did and why
  - **Risk**: low (additive/obvious), medium (judgment call), or high (logic change — user should review)
- Confirm merge and push succeeded
- `git log --oneline -10`

If there are $ARGUMENTS, use them as priority guidance for conflict resolution decisions.
