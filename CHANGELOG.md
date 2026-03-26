# Changelog

All notable changes to the GenieArchi ecosystem.

## 2026-03-25 / 2026-03-26

### archlint
- GitHub Action for PR architecture review - live in Marketplace
- Architecture diff between commits - show structural impact of changes
- CI workflow - architecture diff on every push/PR
- Fixed resource leak in MCP server (unclosed log file handle)
- Cleaned up string concatenation patterns in metrics
- Added FEATURES.md - comprehensive index of all features
- Added ROADMAP.md

### costlint
- Cost prediction before execution - estimate spend before running a task
- Master roadmap for the ecosystem
- Added ROADMAP.md

### promptlint
- Added ROADMAP.md

### seclint
- Added ROADMAP.md

### geniearchi
- Status page live at geniearchi.com/status
- Docker setup with deskd runtime
- Collaboration rules documented (COLLABORATION.md)
- Added ROADMAP.md

### assistant-app
- WebView APK built via GitHub Actions
- 12 epics created tracking 67 issues across 7 repos

### What is next
- promptlint HTTP API (POST /analyze)
- costlint tiktoken-accurate token counting
- seclint configurable content policies (.seclint.yaml)
- Architecture drift alerting (baseline + regression detection)
