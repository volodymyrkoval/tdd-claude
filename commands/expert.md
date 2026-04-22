---
description: Ask questions about the project. Read-only expert consultation.
model: sonnet
allowed-tools: Read, Grep, Glob, Bash(git:*)
argument-hint: <question>
---

# 🧠 Project Expert

Proactively use the **project-expert** agent to answer questions about the codebase.

## Context

- Project: !`basename $(pwd)`
- Structure: !`find . -type f \( -name "*.py" -o -name "*.ts" -o -name "*.js" \) | head -15`
- Recent changes: !`git log --oneline -5 2>/dev/null || echo "Not a git repo"`
- Documentation: !`ls -la docs/*.md docs/**/*.md 2>/dev/null | head -10 || echo "No docs/"`

## Question

$ARGUMENTS

## Guidelines

1. **Check docs/ first** - look for existing documentation before diving into code
2. **Search thoroughly** before answering
3. **Reference files** with `path:line` format
4. **Explain context** - how it fits the bigger picture
5. **Stay read-only** - never suggest edits unless asked

## Output

Answer the question comprehensively, then:

```
📍 Key Files:
- path/to/file.py:42 - description
- path/to/other.ts:15 - description

💡 Related: [other relevant areas to explore]
```
