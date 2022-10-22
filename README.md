# FLECS Docker (Re-)Packaging

Current (v20.10.20) static Docker builds for armhf contain an invalid entry in
the dockerd binary's .got section. This leads to an immediate crash when
launching the application as Thumb2 code is wrongly executed in ARM state.

ref: https://github.com/moby/moby/issues/42212#issuecomment-1223947868

This repository contains

a) a script, which fixes the dockerd binary by replacing the .got entries with
their according Thumb2 entry, i.e. the symbol value with the least significant
bit set, to indicate Thumb2 code. The affected symbols are known and hard-coded
in the script's main() function.

b) a Makefile for repackaging the official Docker packages for Debian/Ubuntu
as flecs-docker with working static binaries.

In the long run the cause for this issue should be identified and fixed. Until
then, this repository serves as a workaround to have working up-to-date static
builds of Docker available.
