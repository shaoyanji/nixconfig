#!/bin/bash
# Pre-commit hook: Check for broken absolute paths in documentation
# Usage: Place in .githooks/check-docs.sh and run via: git config core.hooksPath .githooks

set -euo pipefail

echo "Checking for broken absolute paths in documentation..."

# Check for user-specific absolute paths (common mistake)
if grep -r "/home/" *.md docs/*.md .agents/*.md 2>/dev/null | grep -v "example\|comment\|your-"; then
  echo "ERROR: Found hardcoded /home/ paths in documentation."
  echo "Use relative paths instead (e.g., 'docs/foo.md' not '/home/user/docs/foo.md')."
  exit 1
fi

# Check for other common broken patterns
if grep -rE "file:///home/|file:///Users/" *.md docs/*.md .agents/*.md 2>/dev/null; then
  echo "ERROR: Found broken file:// URLs with absolute home paths."
  exit 1
fi

echo "Documentation paths OK."
exit 0
