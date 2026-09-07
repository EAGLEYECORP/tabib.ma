# Content Security Policy Hardening

V17 inherited a permissive compatibility CSP containing `unsafe-inline` and `unsafe-eval`. Before production, replace these directives with nonce/hash-based policy and an explicit allowlist for every required provider. Do not weaken CSP merely to make a third-party widget work.
