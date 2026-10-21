#!/usr/bin/env bash
# Fixture: emits a code inside the 130-137 band. `rangeexit` promises that band
# and must pass; a parser that kept only the left endpoint would still pass here,
# which is why `badrange` exits outside it instead.
exit 134
