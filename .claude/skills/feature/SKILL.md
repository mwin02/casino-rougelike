---
name: feature
description: Build one BUILD_PLAN.md block end to end (discuss, plan, test, implement, review, open a PR).
disable-model-invocation: true
argument-hint: [block-id]
---

# Build block $ARGUMENTS

Follow these steps in order. Do not skip a waiting step.

1. **Read.** Find block `$ARGUMENTS` in `BUILD_PLAN.md` (goal, exit, tests, manual). Read every `docs/spec-v4.md` section it cites, plus anything they depend on. Note each `[TUNE]` and `[OPEN]` tag you meet.
2. **Explore.** Read the existing code in `src/`, `test/` and `config/` this block will touch or reuse. Prefer extending what exists.
3. **Discuss before planning.** Present:
   - the open design decisions: `[OPEN]` items this block touches, and ambiguities or contradictions in the spec or plan;
   - the implementation choices that matter here, such as data shapes, where state lives, the core/view-model API boundary, and which config keys get added.

   Give each point a recommendation and its alternatives. **Stop and wait for the developer's answers.** Never resolve an `[OPEN]` item yourself.
4. **Plan.** Write a plan that reflects those answers: files, types, config keys, and the exact test list mapped to the block's tests. If the change will exceed ~400 lines (excluding `.uid` files), split it into PRs along natural seams (core, then view model, then scene) and list them. **Wait for approval.**
   Then branch from an up-to-date `main`: `git switch main && git pull && git switch -c block-$ARGUMENTS/<slug>`.
5. **Tests first.** Write the block's tests (load the `godot-testing` skill). Run `scripts/test` and confirm they fail for the right reason.
6. **Implement.** Follow the architecture rules in `CLAUDE.md`. `[TUNE]` values go in `config/`.
7. **Verify.** Run `scripts/check` until it passes, and show the result.
8. **Review.** Run the `spec-reviewer` subagent on the diff, naming block `$ARGUMENTS`. Fix every real gap it reports, or explain why it isn't one, then run `scripts/check` again.
9. **Manual check.** If the block has anything visual or on-device, give the developer a short numbered manual-check list and **wait for confirmation**. A bug they find gets a failing test first, then the fix.
10. **Spec.** If any design number changed, including a decision from step 3 that changes a spec value, update `docs/spec-v4.md` now.
11. **Tick.** Change the block's `- [ ] Done` to `- [x] Done` in `BUILD_PLAN.md`, but only if its exit condition is fully met.
12. **Commit and open a PR.** Make one commit for this block (or for each planned PR), with a message like `Block $ARGUMENTS: <goal>`. Push the branch and run `gh pr create` with that message as the title and a body that follows `.github/pull_request_template.md`, kept short. Report the PR link and its CI status. Never push to `main`.
