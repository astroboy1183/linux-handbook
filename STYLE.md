# Handbook Style Guide

Every page in `docs/` follows these rules. Read `README.md` first for goals,
roadmap, and conventions.

## Audience

Beginners who want to master Linux. Assume **no prior Linux knowledge** beyond
the earlier chapters. Readers are smart and motivated, and many are
developers or data people. They are not Linux users yet. Explain the *why*
and the *how it works underneath*, not just the *what*. Go deep. This is a
handbook to master the subject, not a quick tutorial.

Reference environment: **Linux Mint 22.3 (Ubuntu 24.04 base), bash, systemd,
apt**. Every command must run there as written.

## Chapter format (mandatory)

Each chapter file uses this skeleton. The H2 headings are fixed.

```markdown
# <Chapter title>

> **Level N · Chapter M** · ⏱️ ~XX min read · Prerequisites: [link](...) or "None"

<one or two sentence intro of what this chapter covers>

## Why it matters

A concrete, real situation where this knowledge saves time or prevents a
mistake. Tell it as a short story.

## Concepts

The ideas in plain language, built up step by step. Use ### subsections.
Use mermaid diagrams or ASCII diagrams where they help. Define every new term
the first time it appears, in **bold**. Explain how things work underneath.

## Commands and examples

Runnable examples, grouped by ### subsections. Show the command AND realistic
output, then explain the output line by line where useful. Teach the classic
tool first, then mention modern alternatives.

## Exercises

3–5 tasks, from easy to hard. Number them. Each one has a collapsible solution:

### Exercise 1: <name> (easy)

<task description>

??? success "Solution"

    <solution with commands, output, and explanation, indented 4 spaces>

## Check yourself

5–8 questions to answer without notes, each with a collapsible answer:

1. Question?

    ??? note "Answer"

        Answer text.

## Key takeaways

- 4–7 bullets.

## Next

Link to the next chapter (or the level capstone).
```

Length: aim for **3,000–6,000 words** per chapter. Depth beats breadth, but
cover every bullet the README roadmap lists for that topic.

## Markdown and MkDocs Material features

The site uses MkDocs Material. Use these:

- Admonitions: `!!! note`, `!!! tip`, `!!! warning`, `!!! danger`, `!!! info`,
  `!!! example`. Collapsible: `??? note "Title"`. Content indented 4 spaces.
- **Risky operations** (deleting system files, partitioning, firewall rules,
  kernel params, anything as root that could break the box) MUST be wrapped:

  ```markdown
  !!! danger "⚠️ VM only"
      Run this in your throwaway VM, never on your main machine. <why>
  ```

- Code blocks always have a language: `bash` for commands, `text` for output,
  `python`, `ini`, `yaml`, and so on. Show a prompt-less command block followed
  by a separate `text` output block, so the copy button copies only the command:

  ````markdown
  ```bash
  ls -l /etc/hostname
  ```

  ```text
  -rw-r--r-- 1 root root 7 Mar  2 09:14 /etc/hostname
  ```
  ````

  When showing an interactive session where the prompt matters, use a
  `console` block with `$ ` prompts. Use this sparingly.
- Diagrams: fenced ` ```mermaid ` blocks (flowchart, sequenceDiagram,
  stateDiagram-v2). Keep labels short and quote labels with special chars.
- Keyboard keys: `++ctrl+c++`.
- Tables for comparisons and option summaries.
- Content tabs (`=== "Tab"`) when showing alternatives, for example classic vs
  modern tool.
- Internal links are **relative** to the current file, e.g.
  `[Permissions](../01-command-line/03-permissions.md)`. Link only to files
  that exist in `mkdocs.yml` nav.

## Writing style

- Plain, direct, friendly. Second person ("you").
- Short paragraphs. Each sentence carries one idea.
- No filler, no hype, and no "In this chapter we will..." padding beyond
  the intro line.
- Bold a new term the first time it appears and define it right there.
- Explain *why* a flag exists, not only what it does.
- Prefer realistic examples: log files, CSVs, config files, web servers, data
  pipelines.
- Call out common mistakes in `!!! warning "Common mistake"` boxes.

## Accuracy

- Accuracy is the top priority. If you're unsure about a flag or output
  format, check it on this machine (it runs Linux Mint 22.3) with `man`,
  `--help`, or by running a **safe, read-only** command.
- **Never** run commands that modify the system, need sudo, delete outside a
  scratch directory, or touch the network config. Do any hands-on
  verification inside a temporary directory under the scratchpad given in
  your instructions.
- Sample output may be lightly trimmed (mark with `...`) but must be realistic
  for Ubuntu 24.04 / Mint 22.3.
- Do not invent personal details. Use the username `alex`, the hostname
  `mint`, and the home directory `/home/alex` in examples.
