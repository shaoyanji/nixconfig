#!/usr/bin/env bash
# Fixture: emits exactly one code. The `badexit` task's summary promises 7
# against this, which is the `exitDrift` case — the claim is in prose, the code
# is here, and nothing but the gate compares them.
exit 3
