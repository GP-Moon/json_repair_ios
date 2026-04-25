# Contributing

Thanks for helping improve `json_repair_ios`.

## Local Setup

```bash
swift build
swift test
```

## Pull Request Guidelines

- Keep the package dependency-free unless there is a strong reason to add a dependency.
- Add or update tests for every behavior change.
- Prefer small, focused pull requests.
- Document user-visible API changes in `README.md` and `CHANGELOG.md`.
- Do not add real API keys, private model output, or sensitive user data to fixtures.

## Design Notes

The repair parser is heuristic by design. When adding a new repair rule, include tests that show:

- The malformed input.
- The repaired output.
- A nearby valid input that must not regress.

If a repair would be ambiguous or likely to destroy user data, prefer returning a conservative string value over inventing structure.
