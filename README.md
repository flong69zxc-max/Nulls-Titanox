# Titanox

A tweak for Nulls Brawl on iOS. It reads the battle state, walks the character
out of incoming fire and writes down what it did.

It is built against one specific Nulls Brawl arm64 build. The addresses in
src/core/offsets.h belong to that build, so a game update breaks the tweak and
that one file has to be redone.

## Layout

    src/titanox.h          the master header: config, types, then one header per module
    src/core/imports.h     frameworks and project imports
    src/core/config.h      the build tag and every constant that is not an address
    src/core/offsets.h     every address and structure offset, in one table
    src/core/types.h       every typedef and struct
    src/core/memory.mm     image bounds, the safe readers and writers, the write guard
    src/core/log.mm        the log handle, the line filter, the slot and object reports
    src/core/crash.mm      the phase stages and the signal handler
    src/core/hooks.mm      image load, the hook slots, the objc scrape, the entry points
    src/utils/strings.mm   ascii and word helpers
    src/utils/geometry.mm  floats, clamps, coordinate bounds
    src/helpers/scan.mm    containers, the census, the roster, the projectile scan
    src/helpers/move.mm    the controller, the stick and drag writers, the prediction call
    src/features/autododge.mm  threat build, direction choice, engage and release
    src/features/walls.mm  the tile grid and the wall clip
    src/features/report.mm the stats line

Every module includes src/titanox.h. A module header includes src/core/types.h
only, so there is no include cycle. Nothing is static: a symbol used across
modules is declared in the header of the module that defines it.

## Build

    make package
    make install

theos and the iOS sdk are the only requirements. arm64 only.

## Log

On device the log is at /var/mobile/Documents/Titanox.log. Every line names the
subsystem it came from, so a change can be read back with a grep:

    grep 'dodge ' Titanox.log

The lines worth knowing:

    drag     what the stick was told to do, and whether the engine kept it
    dodge    health before and after a threat, and whether the dodge was moving
    grid     the tile map as the engine sees it, with a mask around the player
    state    one line per tick with every counter

## Notes

The dodge reads the same tile map the game reads and drives the game's own touch
drag instead of poking a movement field, so the movement it asks for is the kind
the engine already knows how to follow. It does not aim and it does not shoot.

Writes go through a guard that refuses an address the process cannot write to,
and every write is kept in a small ring. If the game does abort anyway, the
[CRASH] line in the log is followed by the last writes with their address, size
and the phase they happened in, which is usually enough to name the culprit.
