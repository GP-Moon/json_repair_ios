# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses semantic versioning once tagged releases begin.

## [Unreleased]

### Added

- Initial Swift Package Manager library product `JSONRepairIOS`.
- Repair support for common LLM JSON issues: unquoted keys, single quotes, comments, trailing commas, missing commas, Markdown fences, JSONP wrappers, truncated literals, and unclosed containers.
- Public `repair`, `loads`, and `decode` APIs.
- Unit tests for core repair behavior.
