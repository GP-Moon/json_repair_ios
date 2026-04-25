# Security Policy

## Supported Versions

Until the first tagged release, security fixes are applied to the `main` branch.

## Reporting a Vulnerability

Please report security issues privately to the maintainers instead of opening a public issue.

Include:

- A short description of the issue.
- A minimal input that reproduces the behavior.
- The expected impact.
- Any relevant environment details.

Do not include private user data or production secrets in reports.

## Scope

`json_repair_ios` repairs malformed JSON text. It does not validate business schemas, enforce authorization, sanitize HTML, or make untrusted content safe to execute. Applications should still validate decoded data against their own domain rules.
