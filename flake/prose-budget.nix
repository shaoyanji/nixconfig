# The prose budget as data — what each page's body costs, and why.
#
# Two readers: `checks.policies` (#agent-prose-budget) compares `pages` to the
# tree, so a page that grows must be re-recorded in the same commit — a decision
# with a diff instead of a slide — and the agent form is
# `nix eval --json .#proseBudget | toon -e` (TOON is the token-cheap shape).
#
# `pages` counts the body only: frontmatter is compiled metadata (`lib/skills.nix`
# turns it into the one-line index), not context a turn carries. `notes` is
# required above `argueAbove` lines: a long page has to say what it earns them
# with, because length without an argument is the thing this file exists to stop.
{lib}: let
  argueAbove = 200;
  pages = {
    ".agents/skills/agent-browser/SKILL.md" = 86;
    ".agents/skills/agents-notes/SKILL.md" = 219;
    ".agents/skills/agents/SKILL.md" = 18;
    ".agents/skills/ai-memory/SKILL.md" = 68;
    ".agents/skills/antigravity/SKILL.md" = 122;
    ".agents/skills/apps/SKILL.md" = 54;
    ".agents/skills/atuin/SKILL.md" = 154;
    ".agents/skills/bountystash/SKILL.md" = 72;
    ".agents/skills/brainstorm/SKILL.md" = 81;
    ".agents/skills/burgernas/SKILL.md" = 114;
    ".agents/skills/calendar/SKILL.md" = 205;
    ".agents/skills/checks/SKILL.md" = 80;
    ".agents/skills/codespace/SKILL.md" = 99;
    ".agents/skills/confirm-before-destructive/SKILL.md" = 45;
    ".agents/skills/correct/SKILL.md" = 46;
    ".agents/skills/cpg/SKILL.md" = 308;
    ".agents/skills/crush/SKILL.md" = 13;
    ".agents/skills/data/SKILL.md" = 39;
    ".agents/skills/dev/SKILL.md" = 53;
    ".agents/skills/dragoncourt/SKILL.md" = 53;
    ".agents/skills/eisen-status/SKILL.md" = 67;
    ".agents/skills/envs/SKILL.md" = 92;
    ".agents/skills/fleet-sentinel/SKILL.md" = 144;
    ".agents/skills/frieren-offload/SKILL.md" = 88;
    ".agents/skills/google-drive/SKILL.md" = 55;
    ".agents/skills/home-assistant/SKILL.md" = 91;
    ".agents/skills/host-facts/SKILL.md" = 80;
    ".agents/skills/image-generate/SKILL.md" = 56;
    ".agents/skills/infra/SKILL.md" = 61;
    ".agents/skills/instabox/SKILL.md" = 104;
    ".agents/skills/iventoy/SKILL.md" = 108;
    ".agents/skills/jevdecide/SKILL.md" = 139;
    ".agents/skills/knowledge-base/SKILL.md" = 195;
    ".agents/skills/mail-alias/SKILL.md" = 81;
    ".agents/skills/mail-archive/SKILL.md" = 167;
    ".agents/skills/master-toon/SKILL.md" = 143;
    ".agents/skills/microvm/SKILL.md" = 72;
    ".agents/skills/moto/SKILL.md" = 29;
    ".agents/skills/neocities/SKILL.md" = 53;
    ".agents/skills/nix-eval/SKILL.md" = 109;
    ".agents/skills/nixos-deploy/SKILL.md" = 55;
    ".agents/skills/no-comments/SKILL.md" = 37;
    ".agents/skills/officecli/SKILL.md" = 41;
    ".agents/skills/parallel-cli/SKILL.md" = 36;
    ".agents/skills/paste/SKILL.md" = 119;
    ".agents/skills/pdfvision/SKILL.md" = 37;
    ".agents/skills/philips-tv-cast/SKILL.md" = 133;
    ".agents/skills/prove-it-works/SKILL.md" = 35;
    ".agents/skills/qmd/SKILL.md" = 153;
    ".agents/skills/reasonix/SKILL.md" = 68;
    ".agents/skills/serv00/SKILL.md" = 50;
    ".agents/skills/services/SKILL.md" = 22;
    ".agents/skills/simplex-admin/SKILL.md" = 11;
    ".agents/skills/stt/SKILL.md" = 74;
    ".agents/skills/task-plane/SKILL.md" = 155;
    ".agents/skills/tmux/SKILL.md" = 108;
    ".agents/skills/unslop/SKILL.md" = 69;
    ".agents/skills/voice-loop/SKILL.md" = 71;
    ".agents/skills/wikisearch/SKILL.md" = 148;
    ".agents/skills/xs-turns/SKILL.md" = 192;
    "AGENTS.md" = 225;
    "modules/user/ai/skills/jev-ultrafast/SKILL.md" = 108;
    "modules/user/ai/skills/nix-preflight-editor/SKILL.md" = 50;
    "modules/user/ai/skills/simplex-admin/SKILL.md" = 190;
    "modules/user/ai/skills/system-triage-decision/SKILL.md" = 72;
    "modules/user/ai/skills/wiki-decision-recommend/SKILL.md" = 26;
    "modules/user/ai/skills/wsl-browser-controller/SKILL.md" = 72;
  };
  notes = {
    ".agents/skills/agents-notes/SKILL.md" = "the note contract, the status table, and the promotion ladder that keeps a note code-shaped";
    ".agents/skills/calendar/SKILL.md" = "two calendars and a consent flow with three documented dead ends";
    ".agents/skills/cpg/SKILL.md" = "four lanes over one client, one auth story, two budgets, one shared failure table";
    "AGENTS.md" = "the operator manual: the routing table, the gates, and the contracts a turn must honour";
  };
in {
  inherit argueAbove pages notes;
  total = lib.foldl' (acc: n: acc + n) 0 (builtins.attrValues pages);
}
