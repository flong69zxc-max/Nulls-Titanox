# Titanox

Tweak for **Nulls Brawl v69.225** (iOS)

<p align="center">
  <a href="https://t.me/eurogoth"><img src="https://img.shields.io/badge/Telegram-DM-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram" /></a>
</p>

## Install

`Titanox.dylib` → LiveContainer → `Documents/Tweaks/` → restart the game.

## Build

```
Actions → Titanox → Run workflow
```

or locally, with theos on Linux or macOS:

```
make -j"$(( $(nproc) + 1 ))" ARCHS=arm64 DEBUG=0 FINALPACKAGE=1
```

Addresses in `src/core/offsets.h` are RVAs for that exact build. Other versions
won't work.

## License

MIT, see `LICENSE`.