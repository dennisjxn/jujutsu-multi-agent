# Jujutsu for Multi-Agent Coding

A self-paced course, with labs and a working cross-host plugin, on using Jujutsu (jj) for version
control when several AI coding agents (Claude Code, OpenAI Codex, Kiro) work in one repository.

- **Start here:** [`course/README.md`](course/README.md) (syllabus, objectives, outcomes map).
- **Labs:** `course/labs/` (lab builder, scripted agents, broken-state scenarios, self-checks).
- **Plugin:** [`plugins/jj-agents/`](plugins/jj-agents/README.md): a jj skill, MCP server, and hooks
  that install from one folder into Claude Code, Codex, and Kiro.
- **Marketplace:** `.claude-plugin/marketplace.json` (read by Claude Code and Codex).
- **Read online:** https://rationalstuff.com/apps/jujutsu-multi-agent.html

## Quick start

```bash
git clone https://github.com/jacksodj/jujutsu-multi-agent.git
cd jujutsu-multi-agent
# then follow course/00-setup.md

# Install the plugin directly from GitHub:
claude plugin marketplace add jacksodj/jujutsu-multi-agent
claude plugin install jj-agents@jj-agents-course
codex plugin marketplace add jacksodj/jujutsu-multi-agent
codex plugin add jj-agents@jj-agents-course
```

Verified September 26, 2026 against jj 0.45.1, Claude Code 2.1.283, and Codex CLI 0.157.1;
Kiro (IDE 1.1.70, CLI 2.24.0) from its documentation.

License: MIT (see `LICENSE`).
