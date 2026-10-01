# Nulls-Titanox

Theos tweak for Nulls Brawl. Two things in here: a hardware breakpoint hook on the
game's message handler, and a network logger that was used to work out the protocol.

The actual hook engine is not in this repo. `deps/Titanox` is cloned during the build
and provides `TitanoxHook` (`libtitanox.h`); this repo only decides what to hook.

## Layout

```
src/Tweak.mm        hook test on MessageManager::receiveMessage
src/NetLogger.mm    connect/send/recv/sendto/recvfrom/read/write/dns logging
src/offsets.h       RVA table (main image, offsets measured from the mach header)
layout/             plist filter for nt.nb.ios.app
```

## The hook

`MessageManager::receiveMessage` sits at `RVA_MESSAGEMANAGER_RECEIVEMESSAGE`. It is not
exported and nothing calls it through the GOT, so there is no symbol to rebind and no
page to patch. Instead the address goes into a debug breakpoint register, an exception
port catches the hit, and the thread continues inside `recv_hook`. Nothing is written to
the game's code, which is why this works with the game running from a signed binary.

The original is called straight through on the same address after
`[TitanoxHook suspendBreakpoints]` drops the breakpoints of the calling thread for the
duration of the call, then `[TitanoxHook resumeBreakpoints]` puts them back.

The image is picked by walking `LC_SEGMENT_64` entries and looking for the one whose
executable ranges contain the RVA, so no guessing by file name. The first four bytes at
the target are read back and shown in the alert - if they are zeros or garbage, the RVA
is for a different game build.

## Reading the result

The tweak waits 5 seconds after injection and shows an alert: slot count, self test
result, base, target, target bytes. When the hook fires for the first time the alert
comes back once with the hit count, so it does not fight you for touch input.

`selftest: fail` means the breakpoint mechanism itself is not working on that device and
nothing below it will. `hook: failed` means no free slots or an unusable target address.
`game image not found` means the RVA does not sit in any loaded executable segment.

The image is also checked against the tweak's own dylib and against anything ending in
`.dylib`, so a helper library with a similar size cannot be picked by mistake.

## Build

```
git clone https://github.com/flong69zxc-max/Titanox deps/Titanox
make package
```

`deps/Titanox` is ignored by git, the build workflow fetches it on its own.

## Notes

- RVAs are for one specific game build. After a game update the numbers move.
- Six breakpoint slots per thread is the hardware limit, and they are per thread, not
  per process.
- Each hit costs one exception round trip. Fine for a message handler, not something to
  put inside a render loop.
- `deps/Titanox` must be the reworked Titanox: `libtitanox.h` has to declare
  `originalPointerForBreakpoint:`, `suspendBreakpoints`, `resumeBreakpoints`,
  `breakpointSelfTest` and `breakpointSlotLimit`. Without them this will not link.
- `src/NetLogger.mm` writes `Documents/netlog.log` and starts on its own; delete the file
  if you only want the hook.

## Credits

rage for Titanox and the breakpoint hook, Euclid Jan G. and Saagar Jha for the original
brk hook, ElleKit for the idea.
