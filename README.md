# Titanox

Tweak for **Nulls Brawl v69.225** (iOS)

<p align="center">
  <a href="https://t.me/eurogoth"><img src="https://img.shields.io/badge/Telegram-%40eurogoth-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram @eurogoth" /></a>
</p>

## Install

1. LiveContainer → **Tweaks** → **Add** → `Titanox.dylib`
2. Sign it with the button at the top of that screen — unsigned, it won't load
3. Launch the game

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

## Credits

Hooking framework: [Ragekill3377/Titanox](https://github.com/Ragekill3377/Titanox), MIT.