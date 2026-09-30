# AI assistance and review status

This repository was substantially reworked with AI assistance after the
previous project direction was judged too narrow for its intended evaluation.
The current GraphQL-over-HTTP client, initial API shape, implementation,
documentation draft, and automated tests were produced collaboratively with
AI. Do not interpret the presence of this file or passing tests as proof of
independent human authorship.

AI assistance included:

- comparing the former project scope with a broader reusable-library
  direction;
- drafting the client, response decoder, transport seam, tests, and CI setup;
- running local format, static checks, and automated tests and correcting
  issues found during those checks.

## Repository owner review and sign-off

The repository owner (韦昌豪 / Wchwch777) personally:

- made the decision to pivot from the rejected specialized cutting-stock topic to a general-purpose GraphQL HTTP client;
- reviewed the data structures, error types, and transport seam abstraction;
- diagnosed and resolved the native test failure (fixing string interpolation and port binding in loopback tests);
- defined the realistic use scenarios, clarifying that the current repository demonstrates protocol behaviors via mock transports rather than live production integrations;
- completed and signed the owner review record in [`docs/owner-review.md`](docs/owner-review.md);
- authorized merging and pushing the changes to the `main` branch.
