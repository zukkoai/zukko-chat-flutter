# Running review as a separate subagent (the "judge")

For multi-file features or risky refactors, run review as a **separate agent**, not
inline. A fresh agent starts clean and isn't biased by the implementation context
it just wrote — the second pair of eyes catches what the author rationalized away.

## Why a separate agent
- **No author bias.** The implementer already "knows" the code works; a clean
  reviewer re-derives correctness from the diff alone.
- **Read-only by contract.** The reviewer's job is to *judge*, not to fix — so it
  can't paper over a problem by quietly rewriting it.
- **Tighter signal.** The reviewer outputs a severity-ranked verdict the
  orchestrator can act on, instead of a blended write+review stream.

## When to dispatch
- **Dispatch a subagent** for: multi-file features, risky refactors, changes
  touching auth/payments/security, or anything the user explicitly asks to be
  reviewed independently.
- **Inline self-review is enough** for: small, single-file, low-risk changes —
  just walk the used skills' `## Common mistakes` + this skill's checklist.

## How to dispatch (Task / subagent tool)
1. **Finish the implementation** first; make sure it at least compiles.
2. **Gather the diff** (e.g. `git diff` of the change, or the list of changed
   files) — that is the review input.
3. **Spawn a review subagent** with a prompt like:

   > Review this diff as `review`. Detect project conventions from
   > `pubspec.yaml` / `analysis_options.yaml` first, then walk
   > `reference/checklist.md`. Report findings grouped **Blocking /
   > Should-fix / Nit**, each as `file:line → problem → concrete fix`. End with
   > the **Definition-of-done check**. **Read-only: report, do not rewrite any
   > file.** Here is the diff:
   > ```
   > <diff>
   > ```

4. **Act on the verdict in the parent agent:** apply all **Blocking** + agreed
   **Should-fix** items, then re-present. Nits are optional.

## The reviewer agent's rules
- **Read-only.** Read files, run/assume `flutter analyze` + `dart format`, but
  **never** edit, write, or refactor. The fix is described, not applied.
- **Judge the diff, not the whole repo.** Focus on what changed; mention
  unchanged code only when it's directly load-bearing for the change.
- **Follow the Output contract** from `SKILL.md`: verdict first, grouped by
  severity, `file:line → problem → fix`, end with the Definition-of-done check.
- **Be specific and fair.** Every finding cites a location and a concrete fix;
  don't flag style as Blocking, and don't approve over a real crash/leak/secret.
- **Cite, don't re-teach.** Point to the owning skill's
  `reference/anti-patterns.md` (`flutter-optimization`, `state-management`,
  `flutter-analyze`, `error-handling`, `dart`) instead of pasting
  long explanations.

## Handoff back
The subagent's final message *is* the review. The parent agent treats it as a
work list: fix Blocking + Should-fix, optionally Nits, then ship. Do not loop the
reviewer on its own output unless new code was written in response.
