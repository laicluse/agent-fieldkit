# Words on the surface

Read this before writing or changing any text a user sees: titles, labels, buttons, messages, empty states. Words are part of the design: they set the voice, carry the instructions, and are the first thing that reads as written by a machine.

Every rule below is followed, or broken on purpose with the reason written in the project's record. A choice that is neither is an oversight. Evidence is marked: **measured**, **convention**, **opinion**.

## What words do on a surface

- People scan before they read, so the first words of a title, a label or a sentence carry most of the load (see [typography](typography.md)).
- A product has one voice, set by who it speaks to and how they should feel, and many tones: the voice stays, the tone follows the situation. A confirmation and a failed payment are not written alike (Apple).
- People recognise more easily than they recall: a specific label on the screen beats a general one that must be interpreted (Nielsen's heuristics).
- The system should "speak the users' language", with their words and concepts, not the builder's (Nielsen's heuristics).

## Rules

| Rule | Reason | An oversight looks like |
| --- | --- | --- |
| Say it in the fewest words that keep the meaning. Check that each word needs to be there. What tells the user a consequence, asks their consent, helps them recover or is required by law or policy is meaning, and stays. | Every word is read by someone looking for the exit. | A sentence of explanation above a form whose labels already say it. |
| Lead with what matters: the result, the object, the action. | Scanning eyes take the first words and leave. | "In order to be able to continue, you will need to..." |
| A button says what it does, with a verb and where needed its object. | "Send" works better than "Let's do it!"; a link says where it goes, never "click here" (Apple). | "OK", "Submit", "Continue" on an action with consequences. |
| Use the user's word for a thing, and the same word everywhere. Keep a list of terms. | A second name reads as a second thing. | "Remove" in one place and "delete" in another for the same act. |
| Choose capitalisation per kind of element and keep it: sentence case reads plainer, title case more formal. | Mixed capitalisation reads as several authors. | "Add Gift" beside "Add wish". |
| A message about a problem is visible where the problem is, says what happened in plain words, says what to do next, and keeps what the user already entered. | An error must be recognised, diagnosed and recovered from (Nielsen Norman). | "Something went wrong." A form cleared after a failed save. |
| Never blame. No "invalid", "illegal", "incorrect" about what a person did. Leave humour out of anything seen more than once. | Proper use is the maker's responsibility; a joke goes stale on the second error. | "Oops! You entered an invalid value." |
| State facts in the product's own terms. Words about how the thing was built, why the design is as it is, or what the screen is about to show do not belong on the screen. Why something happens to the user does. | The first explain the maker, not the task. | "Here is an overview of your items, organised for clarity." |
| An empty state says what would appear here and offers the fitting next step, when the user has one: adding the first item, or clearing the filter that left nothing. | An empty region reads as broken. | A blank panel; "No data". |
| Write numbers, dates and units the way the reader's language does, with the unit beside the number. | A bare number must be interpreted. | "12" in a column with no unit in its heading. |

Required, not weighed (WCAG 2.2): every control has an accessible name (4.1.2); every image that carries meaning has a text alternative (1.1.1); a status message reaches assistive technology without moving focus (4.1.3); the language of the page is declared, and of a passage in another language too (3.1.1, 3.1.2).

## Deciding for a surface

1. Name the voice in a sentence: who is spoken to, in what situation, how they should feel.
2. List the terms the surface uses for its things and actions; one word each.
3. Write the labels and buttons first. If they need a sentence beside them to be understood, change the control or the label, not the sentence.
4. Write each message for its situation: what happened, what now.
5. Read the surface aloud from top to bottom. Whatever you would not say to a person sitting next to you is rewritten, or goes when it carries none of the meaning named above.

## Sources

Read for this file on 2026-11-24:

- Apple, [Human Interface Guidelines: Writing](https://developer.apple.com/design/human-interface-guidelines/writing).
- Nielsen Norman Group: [ten usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/), [error-message guidelines](https://www.nngroup.com/articles/error-message-guidelines/), [UX writing study guide](https://www.nngroup.com/articles/ux-writing-study-guide/), [how users read on the web](https://www.nngroup.com/articles/how-users-read-on-the-web/).

Not read: the GOV.UK content design guidance (the page did not load); Strunk and White; Ginny Redish, *Letting Go of the Words*. The rules on empty states and on maker's talk rest on practice, not on a source read here.
