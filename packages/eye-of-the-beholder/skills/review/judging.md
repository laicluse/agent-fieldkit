# Judging

Read this before using independent judges (model or human) to compare candidates, and before building an evaluation loop on appearance. A judge round produces evidence about one open decision for these judges; it does not produce beauty, acceptance or truth.

## What a round judges

State before the round: the open design decision the judges answer, the task the surface serves, the constraints, and the references they compare against. Functional correctness, accessibility and brief compliance are checks run before the round, not preferences judged in it. Candidates that fail a check do not enter the comparison.

## Diversity before taste

Judge preference only between genuine alternatives. Before the round, compare the candidates on information order, composition, typography, imagery and tempo, and name the differences. Container geometry can flag suspected duplicates: two candidates with near-identical boxes and information architecture are probably one hypothesis, but typography, imagery or tempo can make them two. Use the flag as a prompt to look, not as a numeric gate; no threshold is defined here, and none should be invented without labelled pairs that include same-geometry different-hypothesis cases.

## Protocol

- Abstract labels (`A`, `B` or symbols), no rationale, no history: a judge that reads why a candidate was made judges the argument.
- Both orders. Every pair is judged in both presentation orders; a verdict that flips with order is unstable and counts as a tie for that judge.
- Ties allowed, abstentions allowed, and both are reported as such.
- Pointed differences required: a verdict names the visible difference it rests on, or it is discarded.
- Several judges with different bias profiles. Different model names do not prove different profiles; show it on calibration pairs.
- Stop ranking when verdicts flip on repetition. Report counts, ties, abstentions and the spread, not only agreement.
- Decide exclusion rules on calibration pairs before the round, never during it.

Position bias is documented at 60 to 69 percent for the second option in pairwise LLM judging, and instructions to avoid bias can make it worse; order swapping and abstract labels are the mitigation, not prompting.

## Calibration

A judge round means something only against known verdicts. Calibration pairs live in `test/calibration/`: two candidates for one brief, a human verdict (or an explicit tie), the visible difference the verdict rests on, and the recorded disagreement when humans disagreed. Keep two kinds apart and report them apart: defect pairs, where one candidate fails an observable requirement, test whether a judge sees defects; preference pairs, where both candidates pass the checks, test whether a judge's preferences track the humans'. Agreement on defect pairs says nothing about preference. Include equally good different solutions and motion pairs judged on recordings. Before trusting a round, run the judges on the preference pairs and report their agreement with the human verdicts. Calibration proves agreement with these people on these tasks; the operator's taste remains a separate layer that no round replaces.

## What a round never establishes

Agreement among judges is not the user's acceptance, and consensus among models does not remove a bias they share. Human judgement is also fallible and is the anchor here because the user is the person the surface serves, not because it is infallible.
