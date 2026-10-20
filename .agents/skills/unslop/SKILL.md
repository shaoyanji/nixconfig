---
name: unslop
description: "Pick me before shipping prose: docs, skills, AGENTS.nix note bodies, commit messages, a reply. Finds AI tells in text and rewrites them, preserving meaning and voice."
version: 0.1.0
author: Lauren Tan (poteto), adapted for nixconfig
license: MIT
platforms: [linux, darwin]
metadata:
  hermes:
    tags: ['pstack', 'method', 'prose', 'docs']
    related_skills: ['correct', 'no-comments', 'knowledge-base']
---

# unslop: cut the tells, keep the meaning

Adapted from pstack (`unslop`, MIT, cursor/plugins). Rule numbers are stable ids other skills cite; a removed rule leaves a gap.

Scan for the patterns, then rewrite. Match the tone of the file you are editing.

## Content

3. **Superficial -ing clauses.** "highlighting...", "ensuring...", "reflecting...", "showcasing...". Delete them or replace with the real source.
5. **Vague attribution.** "Experts believe", "reports suggest", "some argue". Name the source or delete the sentence.

## Language

7. **AI vocabulary.** Additionally, crucial, delve, enduring, enhance, foster, garner, interplay, intricate, landscape, pivotal, showcase, tapestry, testament, underscore, vibrant. Use the plain word.
8. **Fancy ways to say "is".** "serves as", "stands as", "boasts", "features". Write "is" or "has".
9. **"Not just X, but Y."** State the point once.
10. **Rule of three.** Do not force ideas into threes. Use the natural number; here that is usually one or two.
11. **Synonym cycling.** One name per thing, repeated.
12. **False ranges.** "from X to Y" where X and Y are not on a scale. List the items.

## Style

13. **Em dash overuse.** Prefer periods and commas. Existing repo prose uses em dashes heavily; do not treat that as licence for new ones, and do not mass-rewrite old files to satisfy this rule.
14. **Colon overuse.** A colon before a list is fine. A colon as a mid-sentence connector is not; rewrite so the point stands alone.
15. **Boldface overuse.** Do not bold every proper noun. In this repo, bold earns its place only for a hard rule or a measured number.
16. **Inline-header lists.** A bold label whose text restates the label ("**Performance:** performance improved") is a tell. Prose it. A bold lead-in that names the item and is followed by new detail is fine.
17. **Title case headings.** Sentence case.
18. **Decorative emojis.** Remove.
19. **Curly quotes.** Straight quotes.

## Communication artifacts

20. **Chatbot phrases.** "I hope this helps", "Let me know if", "Of course", "Found the smoking gun". Remove.
22. **Sycophancy.** "Great question", "You're absolutely right". Answer the question.

## Filler

23. **Filler phrases.** "In order to" becomes "To"; "due to the fact that" becomes "because"; "it is important to note that" is deleted.
24. **Hedging stacks.** "could potentially possibly" becomes "may".
25. **Generic conclusions.** "The future looks bright" states nothing. Name the plan or the number.

## Jargon

26. **Abstract metaphor nouns.** Substrate, wedge, vector, locus, nexus, primitive as a noun, harness, surface, bedrock, scaffolding, modality, paradigm, north star, flywheel, ratchet. Pick the concrete word: the file, the check, the table.
27. **Say what it does, not how it feels.** "the cache stays close at hand" names a feeling. The fix names a mechanism or a number: "`checks:build:route` asks the cache over HTTP in 1.1 s". If the sentence could appear unchanged in another project's docs, it says nothing about this one.
28. **Shorten or split.** If the reader backtracks to parse it, split the sentence.
29. **Active voice.** Name the actor: "queries are validated by the compiler" becomes "the compiler validates queries".
30. **Cut adverbs or fix the verb.** "significantly improves" becomes the measured delta.
31. **Plain word.** Utilize and leverage become use; facilitate becomes help; numerous becomes many.
32. **Mannered prose.** Aphorisms, rhetorical fragments, personified code, figurative verbs. Say what you mean.
33. **Over-compression.** Dropped articles, verbless fragments, arrows and abbreviations the reader must decode. Write whole sentences.

## Where it applies here

`AGENTS.md`, `MANUAL.md`, `docs/*.md`, `.agents/skills/*/SKILL.md`, `AGENTS.nix` note bodies, `AUDIT.md` entries, commit messages, and the reply you are about to send.

Apply it to text you write and to text you already touch. Do not open a rewrite of a file just to satisfy rule 13.
