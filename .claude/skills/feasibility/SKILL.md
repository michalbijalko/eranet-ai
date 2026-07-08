---
name: feasibility
description: Quick discovery / feasibility (go-no-go) pass before committing to build - understand what the ticket/client wants, research how it could be done in the SEPS stack, judge whether it's doable and worth it, and give a recommendation. Use at the very start of a new idea or theme, or when the user mentions "feasibility", "go-no-go", "prieskum", "dá sa to vôbec urobiť", "discovery", "oplatí sa to". Runs before planning the real build; the business owner makes the final call.
---

# Feasibility / discovery (go-no-go)

The first step for a brand-new idea we don't yet understand. Before planning or building,
do a quick research pass to answer: **what does the client/ticket actually want, can we do
it within the SEPS stack, and is it worth doing?** Output is a recommendation, not code.

## What to do

1. **Frame the ask** — restate what the ticket/client wants in one or two sentences; note
   the unknowns and open questions.
2. **Research how it could be done** — look at the existing codebase first (129 resource
   files, 166 service files, 208 entities — the thing you need may already exist). Use web
   search for external libraries or integrations if needed. The constraint is the fixed
   stack: Java EE 7 / EclipseLink / RESTEasy / AngularJS 1.5 / Bootstrap 3. No new
   frameworks without a decision.
3. **Assess doability** — is it feasible with the existing stack and structure? What's the
   risky part? Would a small proof-of-concept be needed to be sure?
4. **Assess worth** — rough effort vs value; is it a priority now or later? Does it conflict
   with other in-flight work?

## Output: a short go-no-go note

- The ask (1–2 sentences) and the key unknowns.
- What you found (can it be done, with what existing pieces, what's the catch).
- A clear **recommendation**: go / no-go / needs a small PoC first, with why.
- If "go": the rough shape of the build — which existing services/entities to extend,
  what new pieces are needed.

Keep it short — a paragraph or a few bullets, not a report. The point is to kill or
green-light fast and cheaply, and to surface the right questions.

## Decision stays human

The agent's job is to gather and recommend; the **business owner gives the green light**.
Don't slide from "feasible" into building — stop at the recommendation and let a human
decide whether to proceed.
