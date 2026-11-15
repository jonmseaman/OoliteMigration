# Encapsulate espeak-ng in `oo::SpeechSynthesizer`

Status: **Tasks** (ready). Related: [make-espeak-mandatory.md](make-espeak-mandatory.md) (undecided). This
plan works whichever way that one goes; see "With or without the build option".

## Why

espeak-ng's C API is used directly in four places, and its types sit in `Universe.h`:
- `#include <espeak-ng/speak_lib.h>` and an `espeak_VOICE**` member, so every file that includes
  `Universe.h` sees espeak;
- start-up in `MyOpenGLView.cpp`;
- a volume call in `PlayerEntityControls.cpp`;
- `Universe`'s speech and voice methods.

Putting it behind one game class keeps the library in one `.cpp`. It also gives the voice logic a
seam to test without espeak, and turns the `#if OOLITE_ESPEAK` blocks into a single file choice.

## What touches espeak today (`oolite-dev`, 2026-11-15)

| Where | What |
|---|---|
| `Universe.h:68-69` | `#include <espeak-ng/speak_lib.h>` |
| `Universe.h:463-468` | members `espeak_voices` (`const espeak_VOICE**`), `espeak_voice_count`, `speechArray` |
| `Universe.h:953-962` | `startSpeakingString`, `stopSpeaking`, `isSpeaking`; `voiceName`, `voiceNumber`, `nextVoice`, `prevVoice`, `setVoice` |
| `Universe.cpp:365-374` | set punctuation and volume, list the voices, count them |
| `Universe.cpp:494-498` | `espeak_Cancel()` in teardown |
| `Universe.cpp:7237-7291` | the pronunciation-guide substitution, then stop and speak. Column 2 of a pair is espeak's replacement (`:7263-7265`, the latent uninitialised `replacementIndex` from code review C4-13) |
| `Universe.cpp:10444-10511` | the eight methods' bodies; no-op stubs in the `#else` |
| `SDL/MyOpenGLView.cpp:427-436` | `espeak_Initialize` (data path from `ResourceManager::builtInPath()` unless `ESPEAK_DATA_PATH` is set) |
| `PlayerEntityControls.cpp:4013-4015` | `espeak_SetParameter(espeakVOLUME, vol * 5, 0)` when the options-screen volume changes |

The callers of `Universe`'s methods are `PlayerEntity.cpp` (1416, 1830, 2553, 9362),
`PlayerEntityControls.cpp` (3805-3918) and `OOJSPlayer.cpp:635,836`.

## Design

**`src/Core/SpeechSynthesizer.{h,cpp}`**, game code. It doesn't go in `oofnd`, which is being
retired, or in `src/platform/`, because espeak-ng is the same library on every OS.

```cpp
namespace oo {
class SpeechSynthesizer {
 public:
  static SpeechSynthesizer& shared();            // function-local static: espeak's state is process-wide

  void initialize(const std::optional<std::string>& dataPath);   // was MyOpenGLView.cpp:427-436
  void loadVoices(int volumePercent);              // was Universe.cpp:365-374
  void setVolume(int volumePercent);               // was PlayerEntityControls.cpp:4014 (passes vol * 5)

  void speak(const std::string& text);             // startSpeakingString
  void stop();                                     // stopSpeaking, and the teardown cancel
  bool isSpeaking() const;

  std::optional<std::string> voiceName(unsigned index) const;
  unsigned voiceNumber(const std::string& name) const;
  unsigned nextVoice(unsigned index) const;
  unsigned prevVoice(unsigned index) const;
  unsigned setVoice(unsigned index, bool isMale);  // UINT_MAX → the "espeak-default-voice" description

  std::size_t pronunciationColumn(std::size_t pairSize) const;   // 2 if the pair has one, else 1

  // test seam: the voice list without espeak
  void setVoiceNamesForTesting(std::vector<std::string> names);

 private:
  std::vector<std::string> _voiceNames;            // copied from espeak_ListVoices at loadVoices
};
}  // namespace oo
```

- **The header includes no espeak header.** The voice list is copied into
  `std::vector<std::string>` once, so `Universe.h` and every caller lose `<espeak-ng/speak_lib.h>`.
  `setVoice` passes `_voiceNames[i].c_str()` to `espeak_SetVoiceByProperties`.
- **The index arithmetic stays exactly as it is,** including unsigned wrap-around:
  - `prevVoice(0)` gives the last voice, and with no voices it gives `UINT_MAX`.
  - `nextVoice` wraps to 0.
  - `voiceName` of an index out of range is `"-"`.
  - `voiceNumber` of an unknown name is `UINT_MAX`.
  - `setVoice` on an index out of range does nothing and returns the index.
  - `speak` passes the text up to its first NUL, with the same flags.
- **`Universe` keeps its eight public methods as one-line forwarders** to
  `oo::SpeechSynthesizer::shared()`. That leaves the `PlayerEntity*` and `OOJSPlayer.cpp` callers
  unchanged, keeps `Universe` shaped like upstream for merges, and keeps `test_OOJSPlayer.cpp`
  working: it stubs `Universe::startSpeakingString`/`isSpeaking`/`stopSpeaking` and links
  `OOJSPlayer.cpp` alone.
- **`speechArray` and the substitution at `Universe.cpp:7237-7291` stay in `Universe`.** They read
  `PLAYER` and the system names, which is game logic. Only the column choice calls
  `pronunciationColumn`, which also fixes the uninitialised `replacementIndex`.
- **The timing doesn't change.** `initialize` is still called where `MyOpenGLView` calls it now, and
  `loadVoices` where `Universe` sets up.

## With or without the build option

- **If espeak becomes mandatory** ([make-espeak-mandatory.md](make-espeak-mandatory.md)): one
  `SpeechSynthesizer.cpp`, and the `#if`s at the call sites simply go.
- **If it stays optional:** Meson picks `SpeechSynthesizer_espeak.cpp` or
  `SpeechSynthesizer_none.cpp`. The none file holds today's `#else` stubs (silent, not speaking,
  no voices). Every `#if OOLITE_ESPEAK` outside those files goes.
  - The `OOLITE_SPEECH_SYNTH` options-screen rows in `PlayerEntity.h:200-212` and
    `PlayerEntityControls.cpp` become `if constexpr (oo::SpeechSynthesizer::kAvailable)`. The row
    numbers become `constexpr` values computed from it.

Either way the class does the same work. Do this plan first: it shrinks the mandatory-espeak change
to deleting the none file and the option.

## Steps

1. Add `SpeechSynthesizer.{h,cpp}`. Register them in `src/Core/meson.build` (and its header in
   the headers self-containment test, if there is one).
   - Add `tests/unit/core/test_SpeechSynthesizer.cpp`, which sets voice names through the seam
     and checks next, prev, name and number, including the empty list and the wrap-arounds above.
     Write it first: it fails to compile until the class exists.
2. Move the bodies: `Universe.cpp:10444-10511` into the class, and `Universe`'s methods become
   forwarders. Move the start-up into `initialize` and `loadVoices`, the teardown cancel into
   `stop()`, and the volume call into `setVolume`.
3. Remove `<espeak-ng/speak_lib.h>`, `espeak_voices` and `espeak_voice_count` from `Universe.h`.
4. Update `test_Universe.cpp`'s `slice24Voices` (see the ledger; signed off 2026-11-15).
5. Build, run the tests, then run the game once. Speech should work on the options screen (cycle
   voices, change the gender, change the volume) and for a comms message.

## Done check

From `oolite-dev`, this exits nonzero before the change and zero after:

```bash
! git grep -nE 'espeak_|<espeak-ng/' -- src ':!src/Core/SpeechSynthesizer*.cpp'
```

Also run `./mk.sh build dev` (no new warnings), `tests/run.sh unit` (with `test_SpeechSynthesizer`
and `slice24Voices` passing) and `tests/run.sh smoke`.

## Test-change ledger (signed off: Jon, 2026-11-15)

| File | Edit | Assertion meaning |
|---|---|---|
| `tests/unit/core/test_Universe.cpp:1253-1275` (`slice24Voices`) | Today it plants three `espeak_VOICE`s straight into `u->espeak_voices` / `u->espeak_voice_count`, which no longer exist. Change it to `oo::SpeechSynthesizer::shared().setVoiceNamesForTesting({"zero", "one", "two"})` and restore `{}` at the end. The four `OO_CHECK`s on `u->nextVoice`/`prevVoice`/`voiceName`/`voiceNumber` stay word for word, still called through `Universe`. | Same |

`test_OOJSPlayer.cpp` needs no edit (its stand-in `Universe` keeps the three method names).

## Decisions (defaults taken)

- **Singleton, not owned by `Universe`.** espeak-ng is process-global and is initialised before
  `Universe` exists. A function-local static (the idiom plan's rule for singletons) matches that
  without moving start-up.
- **Forwarders on `Universe`** instead of changing about 20 call sites: smaller diff, upstream-shaped,
  and no test edit for `test_OOJSPlayer`.
- **Voice names are copied once.** espeak's list is static for the process, so the copy can't go
  stale.
- **Name: `oo::SpeechSynthesizer`** in `src/Core/SpeechSynthesizer.{h,cpp}`. New code uses the `oo`
  namespace, with no `OO` prefix on the type or the file (Jon, 2026-11-15).
