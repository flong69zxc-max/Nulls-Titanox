# Titanox

A tweak for Nulls Brawl on iOS. It walks the character out of incoming fire
and writes down what it did.

It is built against one specific Nulls Brawl arm64 build. The addresses in
src/offsets.h and src/lc_detect.h belong to that build, so a game update
breaks the tweak and those two files have to be redone.

## Layout

src/core holds the image bounds, the safe readers and writers, the log, the
crash handler and the hook slots. src/utils is the small stuff: strings,
floats, coordinate clamping. src/helpers finds the game objects and drives the
movement. src/features is the dodge, the tile grid it reads and the stats line.

Everything the modules share lives in src/titanox.h, which pulls in the config,
the types and then one header per module. Nothing is static, so a symbol used
across modules is declared in the header of the module that defines it.

## Build

    make package
    make install

theos and the iOS sdk are the only requirements. arm64 only.

## Log

On device the log is at /var/mobile/Documents/Titanox.log. Every line carries a
version tag, so a change can be read back with a grep on the tag:

    grep 'v246 dodge' Titanox.log

The lines worth knowing:

    v244 drag     what the stick was told to do, and whether the engine kept it
    v246 dodge    health before and after a threat, and whether the dodge was moving
    v242 grid     the tile map as the engine sees it, with a mask around the player
    v211 state    one line per tick with every counter

## Notes

The dodge reads the same tile map the game reads and drives the game's own touch
drag instead of poking a movement field, so the movement it asks for is the kind
the engine already knows how to follow. It does not aim and it does not shoot.

Writes go through a guard that refuses an address the process cannot write to,
and every write is kept in a small ring. If the game does abort anyway, the
[CRASH] line in the log is followed by the last writes with their address, size
and the phase they happened in, which is usually enough to name the culprit.
