#!/bin/bash
# Setup script to configure git to use the custom hooks directory
# Run once: bash .git-hooks-setup.sh

git config core.hooksPath .githooks
echo "Git hooks path set to .githooks/"
echo "The check-docs.sh hook will run on commit."
