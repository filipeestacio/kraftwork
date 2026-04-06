---
name: intel-eval
description: Run quality evaluations against skills using recorded session interactions. Use when you want to check if a skill is performing well, after modifying a skill, or to identify degrading skills.
---

# Intel Eval

Run evaluations against skills to measure quality using real interaction data.

## Prerequisites

- `bun` installed
- `kraftwork-intel` plugin installed and configured via `/kraft-config`
- For LLM scoring: Ollama running with `llama3.2:3b` model

## Workflow

### Step 1: Determine scope

Options:
- **Single skill**: evaluate interactions for one specific skill
- **All skills**: evaluate all interactions that have a skill_name
- **Flagged skills**: evaluate skills with less than 70% success rate in metrics

### Step 2: Run the eval

For a single skill:

    ~/.claude/kraftwork-intel/cli eval <skill-name>

For all skills:

    ~/.claude/kraftwork-intel/cli eval --all

For flagged skills (low success rate):

    ~/.claude/kraftwork-intel/cli eval --flagged

To include Ollama LLM scoring (slower but more nuanced):

    ~/.claude/kraftwork-intel/cli eval <skill-name> --llm

### Step 3: Present results

Format the output as a readable summary. Each eval result includes:
- Skill name and number of interactions evaluated
- Average score across all scorers
- Per-scorer breakdown (responseLength, askedClarifyingQuestions, followedTDD, noComments, llm-judge)
- Highlight any skills or scorers with low scores (below 0.7)

If no interactions found for the requested skill, report that clearly.

### Scoring

**Heuristic scorers (always run):**
- `responseLength` — penalizes too-short or too-long responses
- `askedClarifyingQuestions` — brainstorming skill: did it ask questions?
- `followedTDD` — TDD skill: did it write tests before implementation?
- `noComments` — did code blocks avoid adding comments? (project convention)

**LLM scorer (opt-in with --llm):**
- Uses local Ollama with llama3.2:3b
- Evaluates response quality against a general rubric
- Slower but provides nuanced quality judgment
