# Security Policy

## Reporting a vulnerability

Please do not open a public issue for security vulnerabilities.

Use GitHub's private vulnerability reporting:
https://github.com/garymike/security-agents/security/advisories/new

I will acknowledge receipt within 48 hours and aim to resolve critical issues within 14 days.

## Note on this repo's nature

This repo builds tools that run untrusted code in a sandbox (dynamic analysis). The
sandboxes are egress-gated and credential-free by design; if you find a way for a target
under review to escape the sandbox or reach host credentials, that is a critical finding.
Please report it privately.
