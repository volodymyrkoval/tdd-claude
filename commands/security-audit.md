---
description: Deep security audit with OWASP Top 10 checklist. More thorough than /review.
model: sonnet
allowed-tools: Read, Grep, Glob, Bash(git:*), Bash(npm audit:*), Bash(pip-audit:*), Bash(cargo audit:*)
---

# Security Audit

Proactively use the **security-auditor** agent for deep security analysis.

## Context
- Branch: !`git branch --show-current`
- Changes: !`git diff main --name-only 2>/dev/null || git diff --name-only "HEAD~$(( $(git rev-list --count HEAD 2>/dev/null || echo 1) > 5 ? 5 : $(git rev-list --count HEAD 2>/dev/null || echo 1) - 1 ))" 2>/dev/null`

## OWASP Top 10 Quick Reference

| # | Category | Key Checks |
|---|----------|------------|
| A01 | Broken Access Control | Auth on endpoints, IDOR, privilege escalation |
| A02 | Cryptographic Failures | Encryption, secrets exposure, weak algorithms |
| A03 | Injection | SQL, NoSQL, Command, LDAP injection |
| A04 | Insecure Design | Rate limiting, business logic flaws |
| A05 | Security Misconfiguration | Defaults, error leaks, unnecessary features |
| A06 | Vulnerable Components | Outdated deps, known CVEs |
| A07 | Auth Failures | Session management, brute force protection |
| A08 | Data Integrity | CI/CD security, deserialization |
| A09 | Logging Failures | Audit trails, no secrets in logs |
| A10 | SSRF | URL validation, allowlists |

## Grep Patterns to Check

```bash
# Dangerous patterns
eval\(|exec\(|dangerouslySetInnerHTML|innerHTML\s*=
# Hardcoded secrets
(api[_-]?key|password|secret|token)\s*[:=]\s*["'][^"']+["']
# SQL injection risk
(query|execute)\s*\(\s*[`"'].*\$\{|(\+\s*\w+\s*\+)
```

## Process

1. Map attack surface from changed files
2. Check OWASP categories systematically
3. Run dependency audit (`npm audit`, `pip-audit`, etc.)
4. Grep for dangerous patterns
5. Review authentication/authorization flows

## Output

```
# Security Audit: <feature>

## Attack Surface
[Endpoints, inputs, data flows]

## Critical (N) | High (N) | Medium (N) | Low (N)
[Findings by severity]

## Dependencies
[Audit results]

## Verdict
[ ] ✅ No significant concerns
[ ] 🔄 Address before production
[ ] ❌ Critical - do not deploy

To fix: /plan to add items, then TDD cycle.
```
