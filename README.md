# Titanox

A Nulls Brawl tweak: autododge and the bits around it.

It works **only when injected into LiveContainer**. There is no Cydia/Sileo
install path — the build produces a dylib, not a package.

## Install

1. Get `Titanox.dylib` (see Build below).
2. Drop it into the LiveContainer container:
   in the Files app `On My iPhone → LiveContainer → Tweaks`, which is
   `Documents/Tweaks/Titanox.dylib` inside the app container.
3. Restart the game.

The tweak is loaded when the game starts, so after replacing the dylib close the
game and open it again.

## Build

Everything is built in GitHub Actions; nothing is needed locally.

`Actions → Titanox → Run workflow` → wait → download the `Titanox` artifact,
which contains `Titanox.dylib`.

The workflow is **manual only**: it does not run on push, so there are no
automatic builds.

## Log

`Documents/Titanox.log` inside the LiveContainer container. If the game crashes,
the crash breakdown is written there as well.

## Game version

Every game function address and field offset lives in one file,
`src/core/offsets.h`, and is tied to game version **69.230**. The hero and
projectile tables in `data/` come from a third-party source for the same
version. When the game updates, those are the only things that change.

## License

MIT, see `LICENSE`.
