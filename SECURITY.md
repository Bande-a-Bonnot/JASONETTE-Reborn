# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| v2.0 (in development) | Yes |
| v1.x (archived) | No |

## Reporting a Vulnerability

**Do not open a public issue for security vulnerabilities.**

Email security reports to: **security@jasonette.dev**

Include:
- Description of the vulnerability
- Steps to reproduce
- Affected component (spec, web, iOS, Android)
- Potential impact assessment

## Response Timeline

- **Acknowledgment:** within 48 hours
- **Initial assessment:** within 7 days
- **Fix or mitigation:** within 30 days for critical issues

## Scope

The following are in scope for security reports:

- Template expression sandbox escapes
- SSRF via `$network.request`, mixins, or `$script.include`
- Cross-origin mixin injection
- Prototype pollution via template expressions
- URL scheme bypass (`javascript:`, `file://`, `data:`)
- `html` component XSS vectors
- `$script.include` / JSEP context boundary violations

## Disclosure Policy

We follow coordinated disclosure. We ask reporters to allow 90 days before public disclosure to give us time to develop and release a fix.
