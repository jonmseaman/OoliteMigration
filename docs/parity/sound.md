# Parity findings: Sound and music

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

Each section: method coverage table (every upstream method / C function → C++ counterpart → verdict), then differences with `upstream:line` ↔ `oolite-dev:line`, severity and intent.

Cross-cutting checks for this group:

- **Threading:** none on either side. Upstream `OOSoundAcquireLock()`/`OOSoundReleaseLock()` are empty `do {} while (0)` macros (`Core/OOSoundInternal.h:8`). The port keeps the same empty macros (`Core/OOSoundInternal.h`) and adds no thread, mutex or atomic in any sound file. All OpenAL calls stay on the caller's thread.
- **Constants (all unchanged):** `kMaxBufferedSoundSize = 1<<20` (buffered vs streamed cut-off), `OOAL_STREAM_CHUNK_SIZE = 409600` bytes, `pcmout[4096]` decode scratch, `kMaxDecodeSize` (unused on both sides), `kMixerGeneralChannels = 32`, `OO_DEFAULT_SOUNDSOURCE_GAIN = 1.0f`, master volume default `0.5`, `alDistanceModel(AL_NONE)`, pool expiry `0.5 + randf()*0.1` / `0.5`, `kNoSlot = UINT8_MAX`.
- **Gain curves:** linear on both sides. The master volume is clamped with `OOClamp_0_1_f` and written to `AL_GAIN` on the listener. Music gain is clamped with `OOClamp_0_1_f` in the controller. Source gain goes to `AL_GAIN` on the source unclamped. With no distance model there is no attenuation curve.
- **Channel allocation policy:** unchanged. There are 32 sources, kept on a LIFO free list. A source that finds the list empty plays nothing, so channels are never stolen. The pool chooses a slot in this order: empty, then expired lower priority, then unexpired lower priority that is not the reserved slot, then expired equal priority.
- **Looping:** unchanged. A looped sound is re-queued from `OOSoundChannel::update` through `rewind` + `getNextSoundBuffer`, with two buffers kept in flight.

## OOALBufferedSound

<a id="ooalbufferedsound"></a>
Upstream `src/Core/OOALBufferedSound.m` ↔ `Core/OOALBufferedSound.cpp`

**Status:** done — 4 rows: 4 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOALBufferedSound dealloc]` (34) | `~OOALBufferedSound` `Core/OOALBufferedSound.cpp:34` | ✅ |
| `-[OOALBufferedSound name]` (43) | `OOALBufferedSound::name` `Core/OOALBufferedSound.cpp:40` | ✅ |
| `-[OOALBufferedSound initWithDecoder:]` (48) | `OOALBufferedSound::initWithDecoder` (static) `Core/OOALBufferedSound.cpp:49` | ✅ |
| `-[OOALBufferedSound soundBuffer]` (76) | `OOALBufferedSound::soundBuffer` `Core/OOALBufferedSound.cpp:75` | ✅ |

**Differences:**

- ✅ note — `[super init]` (OOSound `-init`, which runs `setUp`) is replaced by the private constructor, which inherits `OOSound::OOSound()` → `setUp()`. The order is the same: `setUp`/`isSoundOK` run before allocation, as before. The whole sound is decoded at init and a new AL buffer is made on every `soundBuffer` call, as before. — upstream `Core/OOALBufferedSound.m:52` ↔ port `Core/OOALBufferedSound.cpp:54`


## OOALMusic

<a id="ooalmusic"></a>
Upstream `src/Core/OOALMusic.m` ↔ `Core/OOALMusic.cpp`

**Status:** done — 10 rows: 9 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOMusic allocWithZone:]` (36) | none. `new OOMusic` in `OOMusic::initWithContentsOfFile` `Core/OOALMusic.cpp:49` | ➖ |
| `-[OOMusic dealloc]` (41) | `~OOMusic` `Core/OOALMusic.cpp:41` | ✅ |
| `-[OOMusic initWithContentsOfFile:]` (50) | `OOMusic::initWithContentsOfFile` (static) `Core/OOALMusic.cpp:47` | ✅ |
| `-[OOMusic name]` (64) | `OOMusic::name` `Core/OOALMusic.cpp:60` | ✅ |
| `-[OOMusic setMusicGain:]` (69) | `OOMusic::setMusicGain` `Core/OOALMusic.cpp:65` | ✅ |
| `-[OOMusic musicGain]` (76) | `OOMusic::musicGain` `Core/OOALMusic.cpp:72` | ✅ |
| `-[OOMusic playLooped:]` (83) | `OOMusic::playLooped` `Core/OOALMusic.cpp:79` | ✅ |
| `-[OOMusic musicSoundSource]` (98) | `OOMusic::musicSoundSource` `Core/OOALMusic.cpp:94` | ✅ |
| `-[OOMusic isPlaying]` (103) | `OOMusic::isPlaying` `Core/OOALMusic.cpp:99` | ✅ |
| `-[OOMusic stop]` (108) | `OOMusic::stop` `Core/OOALMusic.cpp:104` | ✅ |

**Differences:**

- ➖ **low** — `+allocWithZone:` existed only to bypass OOSound's class-cluster allocation (`NSAllocateObject([OOMusic class])`). C++ constructs `OOMusic` directly, and the base constructor still runs `setUp`. The behaviour is unchanged. — upstream `Core/OOALMusic.m:36` ↔ port `Core/OOALMusic.cpp:49`
- ✅ note (bug-compatible) — the single global `sMusicSource` is created on the first `playLooped` and never freed, on both sides. `setMusicGain` before the first play does nothing because there is no source yet. In `OOMusicController::playMusicNamed` the gain is set *before* `playLooped`, so the very first track always plays at `OO_DEFAULT_SOUNDSOURCE_GAIN`. The port has the same ordering. — upstream `Core/OOALMusic.m:71,87` ↔ port `Core/OOALMusic.cpp:67,83`
- ✅ note — the port adds explicit null checks for messages to nil (`isPlaying`, `stop`). These answer NO or do nothing, as `[nil …]` did. — upstream `Core/OOALMusic.m:105,112` ↔ port `Core/OOALMusic.cpp:101,108`


## OOALSound

<a id="ooalsound"></a>
Upstream `src/Core/OOALSound.m` ↔ `Core/OOALSound.cpp`

**Status:** done — 12 rows: 10 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOSound setUp]` (46) | `OOSound::setUp` `Core/OOALSound.cpp:54` | ❌ |
| `+[OOSound setMasterVolume:]` (61) | `OOSound::setMasterVolume` `Core/OOALSound.cpp:70` | ✅ |
| `+[OOSound masterVolume]` (75) | `OOSound::masterVolume` `Core/OOALSound.cpp:86` | ✅ |
| `-[OOSound init]` (84) | `OOSound::OOSound()` `Core/OOALSound.cpp:95` | ✅ |
| `-[OOSound initWithContentsOfFile:]` (91) | `OOSound::initWithContentsOfFile` (static) `Core/OOALSound.cpp:105` | ✅ |
| `-[OOSound initWithDecoder:]` (124) | none. The subclasses' static `initWithDecoder` factories replace it | ➖ |
| `-[OOSound name]` (130) | `OOSound::name` `Core/OOALSound.cpp:136` | ✅ |
| `+[OOSound update]` (136) | `OOSound::update` `Core/OOALSound.cpp:142` | ✅ |
| `+[OOSound isSoundOK]` (143) | `OOSound::isSoundOK` `Core/OOALSound.cpp:149` | ✅ |
| `-[OOSound soundBuffer]` (148) | `OOSound::soundBuffer` `Core/OOALSound.cpp:154` | ✅ |
| `-[OOSound soundIncomplete]` (154) | `OOSound::soundIncomplete` `Core/OOALSound.cpp:160` | ✅ |
| `-[OOSound rewind]` (159) | `OOSound::rewind` `Core/OOALSound.cpp:165` | ✅ |

**Differences:**

- ❌ **low** — the initial master volume is read differently. Upstream `oo_floatForKey:@"volume_control" defaultValue:0.5` uses `OOFloatFromObject`, which returns **0.5** for a non-numeric string or a non-number object. The port uses 0.5 only when the key is absent and otherwise calls `floatForKey`, which returns **0** for an unparseable string, array or dict. The effect: a corrupt `volume_control` pref mutes the game instead of using 50 %. — upstream `Core/OOALSound.m:53` (`Core/OOCollectionExtractors.m:1171-1180`) ↔ port `Core/OOALSound.cpp:62` (`oofnd/Defaults.hpp:490-497`)
- ✅ note (bug-compatible) — after a failed `setUp` (for example `-nosound`), `sIsSetUp` is YES, so `setMasterVolume` carries on with a nil controller and stores **0** into `volume_control` whenever `fraction != 0`. The port reproduces this explicitly. — upstream `Core/OOALSound.m:63-71` ↔ port `Core/OOALSound.cpp:72-83`
- ➖ **low** — the base `-initWithDecoder:` (`[self release]; return nil`) has no counterpart. Nothing calls it, because the concrete classes have their own static factories. — upstream `Core/OOALSound.m:124` ↔ port n/a
- ✅ note — in `initWithContentsOfFile` the upstream `[self release]` of the placeholder is gone, because the factory is static. The buffered/streamed choice (`sizeAsBuffer() <= 1 MB`) is unchanged. The log classes `sound.load.success` (debug only) and `sound.load.error` and their text are unchanged. A nil path prints `(null)`, as before. — upstream `Core/OOALSound.m:106-119` ↔ port `Core/OOALSound.cpp:119-131`
- ✅ note — the port adds `description()`/`descriptionComponents()`, which print `<ClassName 0x…>`, to stand in for NSObject's `-description` as used by `OOSoundSource`'s `%@`. — port `Core/OOALSound.cpp:170-191`


## OOALSoundChannel

<a id="ooalsoundchannel"></a>
Upstream `src/Core/OOALSoundChannel.m` ↔ `Core/OOALSoundChannel.cpp`

**Status:** done — 14 rows: 14 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSoundChannel init]` (43) | `OOSoundChannel::init` `Core/OOALSoundChannel.cpp:37` | ✅ |
| `-[OOSoundChannel dealloc]` (61) | `~OOSoundChannel` `Core/OOALSoundChannel.cpp:57` | ✅ |
| `-[OOSoundChannel update]` (68) | `OOSoundChannel::update` `Core/OOALSoundChannel.cpp:64` | ✅ |
| `-[OOSoundChannel getNextSoundBuffer]` (89) | `OOSoundChannel::getNextSoundBuffer` `Core/OOALSoundChannel.cpp:85` | ✅ |
| `-[OOSoundChannel setDelegate:]` (115) | `OOSoundChannel::setDelegate` `Core/OOALSoundChannel.cpp:111` | ✅ |
| `-[OOSoundChannel next]` (120) | `OOSoundChannel::next` `Core/OOALSoundChannel.cpp:116` | ✅ |
| `-[OOSoundChannel setNext:]` (125) | `OOSoundChannel::setNext` `Core/OOALSoundChannel.cpp:121` | ✅ |
| `-[OOSoundChannel setPosition:]` (130) | `OOSoundChannel::setPosition` `Core/OOALSoundChannel.cpp:126` | ✅ |
| `-[OOSoundChannel setGain:]` (135) | `OOSoundChannel::setGain` `Core/OOALSoundChannel.cpp:131` | ✅ |
| `-[OOSoundChannel playSound:looped:]` (140) | `OOSoundChannel::playSound` `Core/OOALSoundChannel.cpp:136` | ✅ |
| `-[OOSoundChannel stop]` (159) | `OOSoundChannel::stop` `Core/OOALSoundChannel.cpp:155` | ✅ |
| `-[OOSoundChannel hasStopped]` (168) | `OOSoundChannel::hasStopped` `Core/OOALSoundChannel.cpp:164` | ✅ |
| `-[OOSoundChannel enqueueBuffer:]` (194) | `OOSoundChannel::enqueueBuffer` `Core/OOALSoundChannel.cpp:188` | ✅ |
| `-[OOSoundChannel sound]` (218) | `OOSoundChannel::sound` `Core/OOALSoundChannel.cpp:212` | ✅ |

**Differences:**

- ✅ note — the destructor skips `hasStopped()` when `_source == 0`, which only happens after a failed `init()`. Upstream's `[self release]` from a failed `-init` ran `hasStopped` against source 0, which was a no-op with a nil delegate. Nothing observable changes. — upstream `Core/OOALSoundChannel.m:50,63` ↔ port `Core/OOALSoundChannel.cpp:59`
- ✅ note — `respondsToSelector:` is gone because the delegate is now a typed `OOSoundChannelDelegate`. Both delegates upstream (an OOSoundSource instance and the OOSoundSource class) responded, so no call is lost. The sound is still cleared before the delegate runs and released after it. — upstream `Core/OOALSoundChannel.m:185-191` ↔ port `Core/OOALSoundChannel.cpp:181-185`
- ✅ note (bug-compatible) — if `enqueueBuffer` fails inside `playSound`, `_sound` stays nil. `update` and `stop` then never reach `hasStopped`, so the channel is never pushed back to the mixer and the owning source keeps reporting `isPlaying`. This is the same on both sides. — upstream `Core/OOALSoundChannel.m:151-156` ↔ port `Core/OOALSoundChannel.cpp:147-152`
- ✅ note — the `ov.debug` log formats `%p` through `pointerDescription`, and `sound.buffer` logs use `name().value_or("(null)")`. The classes and wording are unchanged. — upstream `Core/OOALSoundChannel.m:78,81,202,211` ↔ port `Core/OOALSoundChannel.cpp:74,77,196,205`


## OOALSoundDecoder

<a id="ooalsounddecoder"></a>
Upstream `src/Core/OOALSoundDecoder.m` ↔ `Core/OOALSoundDecoder.cpp`

**Status:** done — 22 rows: 21 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOALSoundDecoder initWithPath:]` (60) | `OOALSoundDecoder::initWithPath` (static) `Core/OOALSoundDecoder.cpp:84` | ✅ |
| `+[OOALSoundDecoder codecWithPath:]` (72) | `OOALSoundDecoder::codecWithPath` `Core/OOALSoundDecoder.cpp:95` | ✅ |
| `-[OOALSoundDecoder streamToBuffer:]` (80) | `OOALSoundDecoder::streamToBuffer` `Core/OOALSoundDecoder.cpp:103` | ✅ |
| `-[OOALSoundDecoder readCreatingBuffer:withFrameCount:]` (85) | `OOALSoundDecoder::readCreatingBuffer` `Core/OOALSoundDecoder.cpp:108` | ✅ |
| `-[OOALSoundDecoder sizeAsBuffer]` (95) | `OOALSoundDecoder::sizeAsBuffer` `Core/OOALSoundDecoder.cpp:118` | ✅ |
| `-[OOALSoundDecoder isStereo]` (100) | `OOALSoundDecoder::isStereo` `Core/OOALSoundDecoder.cpp:123` | ✅ |
| `-[OOALSoundDecoder sampleRate]` (105) | `OOALSoundDecoder::sampleRate` `Core/OOALSoundDecoder.cpp:128` | ✅ |
| `-[OOALSoundDecoder reset]` (110) | `OOALSoundDecoder::reset` `Core/OOALSoundDecoder.cpp:133` | ✅ |
| `-[OOALSoundDecoder name]` (115) | `OOALSoundDecoder::name` `Core/OOALSoundDecoder.cpp:138` | ✅ |
| `-[OOALSoundVorbisCodec initWithPath:]` (124) | `OOALSoundVorbisCodec::createWithPath` + `initWithPath` `Core/OOALSoundDecoder.cpp:148,159` | ✅ |
| `-[OOALSoundVorbisCodec dealloc]` (236) | `~OOALSoundVorbisCodec` `Core/OOALSoundDecoder.cpp:259` | ✅ |
| `-[OOALSoundVorbisCodec comments]` (251) | `OOALSoundVorbisCodec::comments` `Core/OOALSoundDecoder.cpp:271` | ✅ |
| `-[OOALSoundVorbisCodec readCreatingBuffer:withFrameCount:]` (284) | `OOALSoundVorbisCodec::readCreatingBuffer` `Core/OOALSoundDecoder.cpp:297` | ✅ |
| `-[OOALSoundVorbisCodec streamToBuffer:]` (352) | `OOALSoundVorbisCodec::streamToBuffer` `Core/OOALSoundDecoder.cpp:365` | ✅ |
| `-[OOALSoundVorbisCodec sizeAsBuffer]` (383) | `OOALSoundVorbisCodec::sizeAsBuffer` `Core/OOALSoundDecoder.cpp:396` | ✅ |
| `-[OOALSoundVorbisCodec isStereo]` (393) | `OOALSoundVorbisCodec::isStereo` `Core/OOALSoundDecoder.cpp:406` | ✅ |
| `-[OOALSoundVorbisCodec description]` (398) | `OOALSoundVorbisCodec::descriptionComponents` `Core/OOALSoundDecoder.cpp:414` (no full `description()`) | ➖ |
| `-[OOALSoundVorbisCodec sampleRate]` (403) | `OOALSoundVorbisCodec::sampleRate` `Core/OOALSoundDecoder.cpp:426` | ✅ |
| `-[OOALSoundVorbisCodec reset]` (408) | `OOALSoundVorbisCodec::reset` `Core/OOALSoundDecoder.cpp:431` | ✅ |
| `-[OOALSoundVorbisCodec name]` (431) | `OOALSoundVorbisCodec::name` `Core/OOALSoundDecoder.cpp:454` | ✅ |
| `OOReadOXZVorbis()` (438) | `OOReadOXZVorbis` `Core/OOALSoundDecoder.cpp:459` | ✅ |
| `OOCloseOXZVorbis()` (455) | `OOCloseOXZVorbis` `Core/OOALSoundDecoder.cpp:476` | ✅ |

**Differences:**

- ➖ **low** — upstream `-description` printed `<OOALSoundVorbisCodec %p>{"name", comments=…}`. The port keeps only `descriptionComponents()`, and its comment says the deleted facade wraps it. `OOALSoundDecoder` has no `description()` and nothing formats a decoder, so the full string can no longer be produced. Comment key order (std::map, sorted) may also differ from NSDictionary's description order. — upstream `Core/OOALSoundDecoder.m:398` ↔ port `Core/OOALSoundDecoder.cpp:411-424`
- ✅ note — the decoder buffer sizes are unchanged: 4096-byte `ov_read` scratch, `OOAL_STREAM_CHUNK_SIZE` 409600-byte stream chunks, 16-bit little-endian signed `ov_read(…,0,2,1,…)`, and a 2- or 4-byte frame. `OV_HOLE` still triggers `continue` and any other error triggers `break`. The `sizeInFrames -= remaining` arithmetic, including its mixed bytes/frames units, is preserved verbatim. — upstream `Core/OOALSoundDecoder.m:291-344,355-380` ↔ port `Core/OOALSoundDecoder.cpp:304-357,368-393`
- ✅ note (bug-compatible) — the OXZ failure paths `unzClose(uf)` and then the destructor calls `unzClose(uf)` again. `OOReadOXZVorbis` leaks its `malloc`'d scratch on every read. A failed plain-file `ov_open_callbacks` leaves the `FILE*` to `ov_clear`. All of this is the same on both sides. — upstream `Core/OOALSoundDecoder.m:186,246,442` ↔ port `Core/OOALSoundDecoder.cpp:213,268,463`
- ✅ note — path splitting now goes through `oo::str::pathComponents`/`pathWithComponents`, which mirror GNUstep's Windows rules (both `/` and `\`). The `.oxz` match is case-insensitive and the `.ogg` match is case-sensitive, as before. The log class `files.notFound` (`cxx_kOOLogFileNotFound`) and its three messages are unchanged. — upstream `Core/OOALSoundDecoder.m:132-202` ↔ port `Core/OOALSoundDecoder.cpp:169-227`
- ✅ note — upstream `comments` built each string with `initWithBytesNoCopy:…NSUTF8StringEncoding`, which returns nil for invalid UTF-8. That would have thrown on `setObject:forKey:nil`. The port copies the raw bytes. This only matters inside the (unused) description. — upstream `Core/OOALSoundDecoder.m:265-274` ↔ port `Core/OOALSoundDecoder.cpp:283-289`


## OOALSoundMixer

<a id="ooalsoundmixer"></a>
Upstream `src/Core/OOALSoundMixer.m` ↔ `Core/OOALSoundMixer.cpp`

**Status:** done — 12 rows: 5 ✅ 1 ⚠️ 0 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOSoundMixer sharedMixer]` (39) | `OOSoundMixer::sharedMixer` `Core/OOALSoundMixer.cpp:46` | ⚠️ |
| `-[OOSoundMixer init]` (47) | `OOSoundMixer::init` `Core/OOALSoundMixer.cpp:60` | ✅ |
| `-[OOSoundMixer shutdown]` (81) | `OOSoundMixer::shutdown` `Core/OOALSoundMixer.cpp:86` | ✅ |
| `-[OOSoundMixer update]` (89) | `OOSoundMixer::update` `Core/OOALSoundMixer.cpp:96` | ✅ |
| `-[OOSoundMixer popChannel]` (97) | `OOSoundMixer::popChannel` `Core/OOALSoundMixer.cpp:105` | ✅ |
| `-[OOSoundMixer pushChannel:]` (106) | `OOSoundMixer::pushChannel` `Core/OOALSoundMixer.cpp:115` | ✅ |
| `+[OOSoundMixer(Singleton) allocWithZone:]` (125) | none. Folded into `sharedMixer` (comment `Core/OOALSoundMixer.cpp:123`) | ➖ |
| `-[OOSoundMixer(Singleton) copyWithZone:]` (134) | none (`Core/OOALSoundMixer.cpp:123`) | ➖ |
| `-[OOSoundMixer(Singleton) retain]` (139) | none (`Core/OOALSoundMixer.cpp:123`) | ➖ |
| `-[OOSoundMixer(Singleton) retainCount]` (144) | none (`Core/OOALSoundMixer.cpp:123`) | ➖ |
| `-[OOSoundMixer(Singleton) release]` (149) | none (`Core/OOALSoundMixer.cpp:123`) | ➖ |
| `-[OOSoundMixer(Singleton) autorelease]` (153) | none (`Core/OOALSoundMixer.cpp:123`) | ➖ |

**Differences:**

- ⚠️ **low** — if `-init` fails (`OOSound setUp` fails), upstream did `[super release]` but left `sSingleton` dangling and returned it. The port clears `sSingleton`, returns null and retries on the next call. This is cited as amendment oo-r7m0 item 2. Nothing observable changes, because no sound can load once `sIsSoundOK` is NO, and `OOSound::update` checks it. — upstream `Core/OOALSoundMixer.m:69-77,127-129` ↔ port `Core/OOALSoundMixer.cpp:41-57`
- ➖ **low** — the singleton category (retain/release no-ops, `retainCount = UINT_MAX`) is not translated, and the mixer is simply leaked (amendment oo-r7m0 item 1). — upstream `Core/OOALSoundMixer.m:116-158` ↔ port `Core/OOALSoundMixer.cpp:123`
- ✅ note — the channel allocation policy is unchanged: 32 `OOSoundChannel`s are created in order and each is pushed on a LIFO free list as it is made. A channel whose `alGenSources` fails is skipped, so it leaves a null hole in `_channels` and the port null-checks those holes in `update`/`shutdown`. `popChannel` on an empty list returns null and does not steal. After `shutdown`, `_freeList` still points at freed channels on both sides (bug-compatible). — upstream `Core/OOALSoundMixer.m:60-66,84-111` ↔ port `Core/OOALSoundMixer.cpp:71-120`


## OOALStreamedSound

<a id="ooalstreamedsound"></a>
Upstream `src/Core/OOALStreamedSound.m` ↔ `Core/OOALStreamedSound.cpp`

**Status:** done — 6 rows: 6 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOALStreamedSound dealloc]` (34) | `~OOALStreamedSound` `Core/OOALStreamedSound.cpp:33` | ✅ |
| `-[OOALStreamedSound name]` (43) | `OOALStreamedSound::name` `Core/OOALStreamedSound.cpp:39` | ✅ |
| `-[OOALStreamedSound initWithDecoder:]` (48) | `OOALStreamedSound::initWithDecoder` (static) `Core/OOALStreamedSound.cpp:48` | ✅ |
| `-[OOALStreamedSound rewind]` (79) | `OOALStreamedSound::rewind` `Core/OOALStreamedSound.cpp:77` | ✅ |
| `-[OOALStreamedSound soundIncomplete]` (85) | `OOALStreamedSound::soundIncomplete` `Core/OOALStreamedSound.cpp:84` | ✅ |
| `-[OOALStreamedSound soundBuffer]` (90) | `OOALStreamedSound::soundBuffer` `Core/OOALStreamedSound.cpp:89` | ✅ |

**Differences:**

- ✅ note — the end-of-stream test is unchanged: `transferred < OOAL_STREAM_CHUNK_SIZE` sets `_reachedEnd`. A fresh AL buffer is made for each chunk. The unused `_size` ivar is dropped. Upstream leaked `_name` in `-dealloc`, while the port frees it through `std::optional`, which is not observable. — upstream `Core/OOALStreamedSound.m:34-41,92-96` ↔ port `Core/OOALStreamedSound.cpp:33-37,91-95`


## OOBasicSoundReferencePoint

<a id="oobasicsoundreferencepoint"></a>
Upstream `src/Core/OOBasicSoundReferencePoint.m` ↔ `Core/OOBasicSoundReferencePoint.cpp`

**Status:** done — 3 rows: 3 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSoundReferencePoint setPosition:]` (29) | `OOSoundReferencePoint::setPosition` `Core/OOBasicSoundReferencePoint.cpp:27` | ✅ |
| `-[OOSoundReferencePoint setVelocity:]` (33) | `OOSoundReferencePoint::setVelocity` `Core/OOBasicSoundReferencePoint.cpp:31` | ✅ |
| `-[OOSoundReferencePoint setOrientation:]` (37) | `OOSoundReferencePoint::setOrientation` `Core/OOBasicSoundReferencePoint.cpp:35` | ✅ |

**Differences:**

- *none*. All three are no-ops on both sides.


## OOMusic

<a id="oomusic"></a>
Upstream `src/Core/OOMusic.m` ↔ *(absorbed — the class lives in `Core/OOALMusic.cpp`)*

**Status:** done — 1 row: 0 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| file body `#ifdef LINUX #import "SDLMusic.m"` (9-11) | none. Dead file: the class `OOMusic` is implemented by `OOALMusic.m` → `Core/OOALMusic.cpp` | ➖ |

**Differences:**

- ➖ **low** — upstream `OOMusic.m` defines no methods. It is an old OS selector that `#import`s `SDLMusic.m` under `LINUX`, and `SDLMusic.m` no longer exists in the upstream tree. `OOMusic.m` is also absent from upstream `src/Core/meson.build`, which lists `OOALMusic.m`, so it was never compiled. The `OOMusic` class is in `OOALMusic.m`, audited above against `Core/OOALMusic.cpp` (listed in the port's `src/Core/meson.build:11`). No behaviour is lost. — upstream `Core/OOMusic.m:9-11` ↔ port `Core/OOALMusic.cpp`


## OOMusicController

<a id="oomusiccontroller"></a>
Upstream `src/Core/OOMusicController.m` ↔ `Core/OOMusicController.cpp`

**Status:** done — 31 rows: 25 ✅ 0 ⚠️ 0 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOMusicController sharedController]` (51) | `OOMusicController::sharedController` `Core/OOMusicController.cpp:47` | ✅ |
| `-[OOMusicController init]` (60) | `OOMusicController::OOMusicController()` `Core/OOMusicController.cpp:57` | ✅ |
| `-[OOMusicController playMusicNamed:loop:]` (82) | `OOMusicController::playMusicNamed(name, loop)` `Core/OOMusicController.cpp:76` | ✅ |
| `-[OOMusicController playMusicNamed:loop:gain:]` (87) | `OOMusicController::playMusicNamed(name, loop, gain)` `Core/OOMusicController.cpp:81` | ✅ |
| `-[OOMusicController playThemeMusic]` (106) | `OOMusicController::playThemeMusic` `Core/OOMusicController.cpp:100` | ✅ |
| `-[OOMusicController playDockingMusic]` (112) | `OOMusicController::playDockingMusic` `Core/OOMusicController.cpp:106` | ✅ |
| `-[OOMusicController playDockedMusic]` (123) | `OOMusicController::playDockedMusic` `Core/OOMusicController.cpp:117` | ✅ |
| `-[OOMusicController setMissionMusic:]` (134) | `OOMusicController::setMissionMusic` `Core/OOMusicController.cpp:128` | ✅ |
| `-[OOMusicController playMissionMusic]` (140) | `OOMusicController::playMissionMusic` `Core/OOMusicController.cpp:133` | ✅ |
| `-[OOMusicController justStop]` (149) | `OOMusicController::justStop` `Core/OOMusicController.cpp:142` | ✅ |
| `-[OOMusicController stop]` (157) | `OOMusicController::stop` `Core/OOMusicController.cpp:150` | ✅ |
| `-[OOMusicController stopMusicNamed:]` (166) | `OOMusicController::stopMusicNamed` `Core/OOMusicController.cpp:159` | ✅ |
| `-[OOMusicController stopThemeMusic]` (172) | `OOMusicController::stopThemeMusic` `Core/OOMusicController.cpp:165` | ✅ |
| `-[OOMusicController stopDockingMusic]` (180) | `OOMusicController::stopDockingMusic` `Core/OOMusicController.cpp:173` | ✅ |
| `-[OOMusicController stopMissionMusic]` (186) | `OOMusicController::stopMissionMusic` `Core/OOMusicController.cpp:179` | ✅ |
| `-[OOMusicController toggleDockingMusic]` (192) | `OOMusicController::toggleDockingMusic` `Core/OOMusicController.cpp:185` | ✅ |
| `-[OOMusicController soundSource]` (203) | `OOMusicController::soundSource` `Core/OOMusicController.cpp:196` | ✅ |
| `-[OOMusicController playingMusic]` (208) | `OOMusicController::playingMusic` `Core/OOMusicController.cpp:201` | ✅ |
| `-[OOMusicController isPlaying]` (213) | `OOMusicController::isPlaying` `Core/OOMusicController.cpp:206` | ✅ |
| `-[OOMusicController mode]` (218) | `OOMusicController::mode` `Core/OOMusicController.cpp:211` | ✅ |
| `-[OOMusicController setMode:]` (223) | `OOMusicController::setMode` `Core/OOMusicController.cpp:216` | ✅ |
| `+[OOMusicController(Singleton) allocWithZone:]` (282) | none (comment `Core/OOMusicController.cpp:264`) | ➖ |
| `-[OOMusicController(Singleton) copyWithZone:]` (291) | none (`Core/OOMusicController.cpp:264`) | ➖ |
| `-[OOMusicController(Singleton) retain]` (296) | none (`Core/OOMusicController.cpp:264`) | ➖ |
| `-[OOMusicController(Singleton) retainCount]` (301) | none (`Core/OOMusicController.cpp:264`) | ➖ |
| `-[OOMusicController(Singleton) release]` (306) | none (`Core/OOMusicController.cpp:264`) | ➖ |
| `-[OOMusicController(Singleton) autorelease]` (310) | none (`Core/OOMusicController.cpp:264`) | ➖ |
| `-[OOMusicController(Private) playiTunesPlaylist:]` (320, Mac) | `OOMusicController::playiTunesPlaylist` `Core/OOMusicController.cpp:269` | ✅ |
| `-[OOMusicController(Private) pauseiTunes]` (342, Mac) | `OOMusicController::pauseiTunes` `Core/OOMusicController.cpp:292` | ✅ |
| `-[OOMusicController(Private) playiTunesPlaylist:]` (353, non-Mac stub) | `OOMusicController::playiTunesPlaylist` stub `Core/OOMusicController.cpp:303` | ✅ |
| `-[OOMusicController(Private) pauseiTunes]` (356, non-Mac stub) | `OOMusicController::pauseiTunes` stub `Core/OOMusicController.cpp:304` | ✅ |

**Differences:**

- ➖ **low** — the singleton category is not translated, and the controller is leaked (amendment oo-r7m0 item 1). — upstream `Core/OOMusicController.m:273-315` ↔ port `Core/OOMusicController.cpp:264`
- ✅ note — the track names (`OoliteTheme.ogg`, `BlueDanube.ogg` looped, `OoliteDocked.ogg` not looped, mission music not looped), the `music mode` pref strings (`off`/`on`/`iTunes`), the clamp to `kOOMusicModeMax` (On off-Mac) and the `_special` state machine are all unchanged. `name == playingMusic()` is false when nothing is playing (nullopt), matching `[name isEqual:nil]`. — upstream `Core/OOMusicController.m:64-269` ↔ port `Core/OOMusicController.cpp:60-261`
- ✅ note — `playMusicNamed` keeps upstream's order: `_current->stop()`, then `setMusicGain(OOClamp_0_1_f(gain))`, then `playLooped`, then replace `_current`. Music is not cached (`ResourceManager ooMusicNamed` with `cache:NULL`), so every call creates a fresh `OOMusic` and sound. — upstream `Core/OOMusicController.m:93-101` ↔ port `Core/OOMusicController.cpp:87-95`


## OOOpenALController

<a id="ooopenalcontroller"></a>
Upstream `src/Core/OOOpenALController.m` ↔ `Core/OOOpenALController.cpp`

**Status:** done — 5 rows: 5 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOOpenALController sharedController]` (34) | `OOOpenALController::sharedController` `Core/OOOpenALController.cpp:38` | ✅ |
| `-[OOOpenALController init]` (43) | `OOOpenALController::init` `Core/OOOpenALController.cpp:50` | ✅ |
| `-[OOOpenALController setMasterVolume:]` (80) | `OOOpenALController::setMasterVolume` `Core/OOOpenALController.cpp:75` | ✅ |
| `-[OOOpenALController masterVolume]` (85) | `OOOpenALController::masterVolume` `Core/OOOpenALController.cpp:80` | ✅ |
| `-[OOOpenALController shutdown]` (94) | `OOOpenALController::shutdown` `Core/OOOpenALController.cpp:89` | ✅ |

**Differences:**

- ✅ note — `-nosound`/`--nosound` are exact argv matches on both sides (`oo::process::hasArgument`). When init fails, the singleton stays null and the next call tries again, as upstream's nil `sSingleton` did. The default device and context are unchanged, `AL_NONE` is still the distance model, and the three `sound.initialization.error` messages are unchanged. `shutdown` null-checks the mixer, matching a message to nil. — upstream `Core/OOOpenALController.m:36-100` ↔ port `Core/OOOpenALController.cpp:40-95`


## OOSoundSource

<a id="oosoundsource"></a>
Upstream `src/Core/OOSoundSource.m` ↔ `Core/OOSoundSource.cpp`

**Status:** done — 32 rows: 31 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOSoundSource sourceWithSound:]` (36) | `OOSoundSource::sourceWithSound` `Core/OOSoundSource.cpp:60` | ✅ |
| `-[OOSoundSource init]` (41) | `OOSoundSource::OOSoundSource()` `Core/OOSoundSource.cpp:65` | ✅ |
| `-[OOSoundSource initWithSound:]` (53) | `OOSoundSource::OOSoundSource(OOSound*)` `Core/OOSoundSource.cpp:72` | ✅ |
| `-[OOSoundSource dealloc]` (64) | `~OOSoundSource` `Core/OOSoundSource.cpp:80` | ✅ |
| `-[OOSoundSource descriptionComponents]` (72) | `OOSoundSource::descriptionComponents` `Core/OOSoundSource.cpp:88` | ✅ |
| `-[OOSoundSource sound]` (81) | `OOSoundSource::sound` `Core/OOSoundSource.cpp:99` | ✅ |
| `-[OOSoundSource setSound:]` (86) | `OOSoundSource::setSound` `Core/OOSoundSource.cpp:104` | ✅ |
| `-[OOSoundSource loop]` (95) | `OOSoundSource::loop` `Core/OOSoundSource.cpp:112` | ✅ |
| `-[OOSoundSource setLoop:]` (100) | `OOSoundSource::setLoop` `Core/OOSoundSource.cpp:117` | ✅ |
| `-[OOSoundSource repeatCount]` (105) | `OOSoundSource::repeatCount` `Core/OOSoundSource.cpp:122` | ✅ |
| `-[OOSoundSource setRepeatCount:]` (110) | `OOSoundSource::setRepeatCount` `Core/OOSoundSource.cpp:127` | ✅ |
| `-[OOSoundSource isPlaying]` (115) | `OOSoundSource::isPlaying` `Core/OOSoundSource.cpp:132` | ✅ |
| `-[OOSoundSource play]` (120) | `OOSoundSource::play` `Core/OOSoundSource.cpp:141` | ✅ |
| `-[OOSoundSource playOrRepeat]` (148) | `OOSoundSource::playOrRepeat` `Core/OOSoundSource.cpp:172` | ✅ |
| `-[OOSoundSource stop]` (156) | `OOSoundSource::stop` `Core/OOSoundSource.cpp:180` | ✅ |
| `+[OOSoundSource stopAll]` (172) | `OOSoundSource::stopAll` `Core/OOSoundSource.cpp:200` | ⚠️ |
| `-[OOSoundSource playSound:]` (186) | `OOSoundSource::playOOSound` `Core/OOSoundSource.cpp:218` | ✅ |
| `-[OOSoundSource playSound:repeatCount:]` (191) | `OOSoundSource::playSound(sound, count)` `Core/OOSoundSource.cpp:223` | ✅ |
| `-[OOSoundSource playOrRepeatSound:]` (199) | `OOSoundSource::playOrRepeatSound` `Core/OOSoundSource.cpp:231` | ✅ |
| `-[OOSoundSource setPositional:]` (207) | `OOSoundSource::setPositional` `Core/OOSoundSource.cpp:239` | ✅ |
| `-[OOSoundSource positional]` (220) | `OOSoundSource::positional` `Core/OOSoundSource.cpp:252` | ✅ |
| `-[OOSoundSource setPosition:]` (225) | `OOSoundSource::setPosition` `Core/OOSoundSource.cpp:257` | ✅ |
| `-[OOSoundSource position]` (236) | `OOSoundSource::position` `Core/OOSoundSource.cpp:268` | ✅ |
| `-[OOSoundSource setGain:]` (241) | `OOSoundSource::setGain` `Core/OOSoundSource.cpp:273` | ✅ |
| `-[OOSoundSource gain]` (249) | `OOSoundSource::gain` `Core/OOSoundSource.cpp:281` | ✅ |
| `-[OOSoundSource setVelocity:]` (255) | `OOSoundSource::setVelocity` `Core/OOSoundSource.cpp:287` | ✅ |
| `-[OOSoundSource setOrientation:]` (259) | `OOSoundSource::setOrientation` `Core/OOSoundSource.cpp:291` | ✅ |
| `-[OOSoundSource setConeAngle:]` (263) | `OOSoundSource::setConeAngle` `Core/OOSoundSource.cpp:295` | ✅ |
| `-[OOSoundSource setGainInsideCone:outsideCone:]` (267) | `OOSoundSource::setGainInsideCone` `Core/OOSoundSource.cpp:299` | ✅ |
| `-[OOSoundSource positionRelativeTo:]` (271) | `OOSoundSource::positionRelativeTo` `Core/OOSoundSource.cpp:303` | ✅ |
| `-[OOSoundSource channel:didFinishPlayingSound:]` (276) | `OOSoundSource::channel` `Core/OOSoundSource.cpp:308` | ✅ |
| `+[OOSoundSource channel:didFinishPlayingSound:]` (293) | `OOSoundSource::channelOfStoppedSource` via `StoppedSourceHandler` `Core/OOSoundSource.cpp:43,328` | ✅ |

**Differences:**

- ⚠️ **low** — `stopAll` stops sources in the order they started playing, where upstream used NSMutableSet hash order (the code comment says so). The only effect is the order in which channels go back onto the LIFO free list, and so which AL source later sounds are given. Nothing is audible. — upstream `Core/OOSoundSource.m:179-183` ↔ port `Core/OOSoundSource.cpp:207-215`
- ✅ note — the retain discipline is preserved. `play` takes a self-retain only when a channel was obtained, and adds the source to the playing set **even with no channel** (deduplicated, as a set would be). `stop` removes it from the set and drops the self-retain. A natural finish (`channel(...)`) drops the self-retain and pushes the channel back but does **not** remove the source from the set, so finished sources stay alive until `stopAll`. All of this is bug-compatible with upstream. — upstream `Core/OOSoundSource.m:130-143,160-167,285-288` ↔ port `Core/OOSoundSource.cpp:152-167,184-195,317-323`
- ✅ note — the repeat logic is unchanged: `_remainingCount = repeatCount()` (0 is treated as 1). `--_remainingCount` replays with `looped:NO`, and `playOrRepeat` increments the count while playing. `playSound:` passes the raw `_repeatCount`, not the accessor, as before. `setPosition` still sets `_positional` for a non-zero vector, and `setPositional(false)` zeroes the position. — upstream `Core/OOSoundSource.m:132,148-154,188,225-234,282-284` ↔ port `Core/OOSoundSource.cpp:154,172-178,220,257-266,314-315`
- ✅ note — `descriptionComponents` prints `sound=<OOALBufferedSound 0x…>` through `OOSound::description()` and `<OOSoundChannel 0x…>` for the channel. Those are the strings NSObject's `-description` gave upstream. — upstream `Core/OOSoundSource.m:74-78` ↔ port `Core/OOSoundSource.cpp:88-97`


## OOSoundSourcePool

<a id="oosoundsourcepool"></a>
Upstream `src/Core/OOSoundSourcePool.m` ↔ `Core/OOSoundSourcePool.cpp`

**Status:** done — 12 rows: 12 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOSoundSourcePool poolWithCount:minRepeatTime:]` (50) | `OOSoundSourcePool::poolWithCount` `Core/OOSoundSourcePool.cpp:42` | ✅ |
| `-[OOSoundSourcePool initWithCount:minRepeatTime:]` (55) | `OOSoundSourcePool::initWithCount` `Core/OOSoundSourcePool.cpp:51` | ✅ |
| `-[OOSoundSourcePool dealloc]` (80) | `~OOSoundSourcePool` `Core/OOSoundSourcePool.cpp:75` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:priority:expiryTime:overlap:position:]` (94) | `playSoundWithKey(key, float, OOTimeDelta, bool, Vector)` `Core/OOSoundSourcePool.cpp:89` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:priority:expiryTime:]` (154) | `playSoundWithKey(key, float, OOTimeDelta)` `Core/OOSoundSourcePool.cpp:148` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:priority:position:]` (165) | `playSoundWithKey(key, float, Vector)` `Core/OOSoundSourcePool.cpp:159` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:priority:]` (176) | `playSoundWithKey(key, float)` `Core/OOSoundSourcePool.cpp:170` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:]` (184) | `playSoundWithKey(key)` `Core/OOSoundSourcePool.cpp:178` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:position:]` (189) | `playSoundWithKey(key, Vector)` `Core/OOSoundSourcePool.cpp:183` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:overlap:]` (194) | `playSoundWithKey(key, bool)` `Core/OOSoundSourcePool.cpp:188` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:overlap:position:]` (203) | `playSoundWithKey(key, bool, Vector)` `Core/OOSoundSourcePool.cpp:197` | ✅ |
| `-[OOSoundSourcePool(Private) selectSlotForPriority:]` (216) | `OOSoundSourcePool::selectSlotForPriority` `Core/OOSoundSourcePool.cpp:207` | ✅ |

**Differences:**

- ✅ note — the extractor had mislabelled rows 154/165/176/184 as `playSoundWithKey:`. They are corrected above.
- ✅ note — the slot policy is unchanged: count is clamped to `[1, 254]`, `minRepeat` is clamped to ≥ 0, the search is a round-robin from `_latest`, and preference runs empty > expired-lower > unexpired-lower (not reserved) > expired-equal. The overlap reservation and the `_nextRepeat`/`_lastKey` repeat suppression are also unchanged. With a null `UNIVERSE` the time is 0.0, as `[nil getTime]` answered. The `[OOSound soundWithCustomSoundKey:]` call becomes `OOSoundWithCustomSoundKey` (`Core/Universe.cpp:1119`), which is the same lookup. — upstream `Core/OOSoundSourcePool.m:55-247` ↔ port `Core/OOSoundSourcePool.cpp:51-238`
- ✅ note — overloads now replace selectors. A priority is a `float` and an overlap is a `bool`, so an `int` or `double` literal argument would be an ambiguous call and fail to compile rather than resolve silently. All current callers pass `1.0f`-style floats or `static_cast<bool>` (`Core/Entities/PlayerEntitySound.cpp:490-705`). — port `Core/OOSoundSourcePool.h:60-71`
