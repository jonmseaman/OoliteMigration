# Speech Synthesis (espeak-ng)

## Version

- espeak-ng **1.52.0** everywhere: MSYS2 UCRT64 package `1.52.0.1`, and the Flatpak pins the
  `1.52.0` tag (`oolite-dev/installers/flatpak/space.oolite.Oolite.yaml:44`).
- 1.52.0 is still the latest release. Master's build files say 1.53.0, but it is unreleased and
  makes no change to the synthesizer that would improve how it sounds. An upgrade gains nothing
  audible.

## How the data is assembled

- `oolite-dev/Resources/espeak-ng-data` is not a full data set. It holds two override files.
  `ShellScripts/common/post_build.sh:62-90` copies the system `espeak-ng-data` in with them
  (MSYS `$MINGW_PREFIX/share`, the Linux paths, `/app/share` for Flatpak, Homebrew on macOS).
- `voices/default` is `en-rp`, male, with no variant: plain British Received Pronunciation using
  espeak's own formant voice.
- `voices/!v/f2` is Oolite's version of stock female2. It differs from stock 1.52:
  - pitch is 188–228 (stock 142–220)
  - roughness is 0 (stock 3)
  - the formant 4, 5 and 7 bandwidths are changed
  - `voicing 20` and `breathw` are added, and `consonants` is dropped

  It sounds higher and breathier than stock.
- The default voice name comes from `"espeak-default-voice" = "default"` in
  `Resources/Config/descriptions.plist:2226`.

## Findings

1. **The overrides survive only because of file dates.** `post_build.sh` copies the system data
   with `cp -rfu`, which overwrites a file whenever the system copy is newer. If an espeak-ng
   package is installed or upgraded after the checkout, the stock `f2` and `default` files would
   replace Oolite's, with no error. Today the built tree (`build/meson_debug/.../f2`) still has
   Oolite's version. Fix: copy the repo overrides after the system data, or don't use `-u` for them.
2. **The voice list is every language.** `espeak_ListVoices(nullptr)` (`src/Core/Universe.cpp:370`)
   returns about 130 language voices, so cycling voices in-game mostly moves through other
   languages' pronunciation rules. That call leaves variants such as `f2` out of the list; the
   gender setting reaches them through `espeak_SetVoiceByProperties` in `Universe::setVoice`.
3. **The bundled variants go unused:** `klatt`–`klatt6`, `m1`–`m8`, `f1`–`f5`, `announcer`,
   `Storm` and about 90 more. The Klatt variants use a different synthesis method and often sound
   smoother. To try one:
   `espeak-ng -v en-gb-x-rp+klatt4 "Commander, entering witchspace"`.
   Setting `espeak-default-voice` to `default+klatt4` is untested and probably needs a code change,
   because `voiceNumber` matches names exactly against the list.
4. **MBROLA** (`mb-en1`, `mb-us1`–`us3`) is the biggest quality step espeak-ng itself offers:
   it builds speech from recorded fragments. Against it: a separate download, a non-free licence,
   and the MSYS build may not have MBROLA support.

## Piper (for later)

Piper is neural text-to-speech that uses espeak-ng for pronunciation and puts a neural voice on
top. It sounds much better than any espeak voice. Using it is a dependency and packaging
decision, not a config change. To consider later.

Voice models downloaded for evaluation (not in the repo):

- `C:\Users\jon\Downloads\en_US-kristin-medium.onnx` (about 64 MB, female)
- `C:\Users\jon\Downloads\en_US-mike-medium.onnx` (about 63 MB, male)

Each Piper model also needs its `.onnx.json` config next to it (same name plus `.json`), from the
same `rhasspy/piper-voices` page. Neither is in Downloads yet.

Open questions:
- runtime: ONNX Runtime added as a dependency for each platform
- latency: synthesize ahead of time or stream while playing
- licence for each voice model
- shipping about 60 MB per voice
- keeping espeak as the fallback

## Sources

- [Debian Package Tracker – espeak-ng](https://tracker.debian.org/pkg/src:espeak-ng)
- [FreshPorts – audio/espeak-ng](https://www.freshports.org/audio/espeak-ng/)
- [espeak-ng releases](https://github.com/espeak-ng/espeak-ng/releases)
