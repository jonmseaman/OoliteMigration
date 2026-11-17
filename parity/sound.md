# Parity findings: sound
Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

## OOALBufferedSound

<a id="ooalbufferedsound"></a>
Upstream `src/Core/OOALBufferedSound.m` ↔ `Core/OOALBufferedSound.cpp` (94 / 85 lines)

**Status:** done — 4 rows: 4 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOALBufferedSound dealloc]` (34) | `~OOALBufferedSound` (default; vector + optional free) `Core/OOALBufferedSound.cpp:34` | ✅ |
| `-[OOALBufferedSound name]` (43) | `OOALBufferedSound::name` `Core/OOALBufferedSound.cpp:36` | ✅ |
| `-[OOALBufferedSound initWithDecoder:]` (48) | `OOALBufferedSound::initWithDecoder` (static) `Core/OOALBufferedSound.cpp:42` — setUp/isSoundOK/nil-decoder gate, then name, rate, read, stereo in the same order | ✅ |
| `-[OOALBufferedSound soundBuffer]` (76) | `OOALBufferedSound::soundBuffer` `Core/OOALBufferedSound.cpp:68` — same log class/text; `_size` → `_buffer.size()` (see decoder note) | ✅ |

**Differences:**

- ✅ note — `[super init]` becomes the private constructor, whose base `OOSound()` re-runs the `setUp` guard, as `-[OOSound init]` did. A fresh AL buffer is still made on every `soundBuffer` call. The byte count now comes from the vector's size, which equals upstream's `*outSize` except in the decode-error underflow case flagged under OOALSoundDecoder. — upstream `Core/OOALBufferedSound.m:48-74` ↔ port `Core/OOALBufferedSound.cpp:42-85`

## OOALMusic

<a id="ooalmusic"></a>
Upstream `src/Core/OOALMusic.m` ↔ `Core/OOALMusic.cpp` (117 / 109 lines)

**Status:** done — 10 rows: 9 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOMusic allocWithZone:]` (36) | none. `new OOMusic()` in `OOMusic::initWithContentsOfFile` `Core/OOALMusic.cpp:50` | ➖ |
| `-[OOMusic dealloc]` (41) | `~OOMusic` `Core/OOALMusic.cpp:41` — stop if playing, then the sound member goes | ✅ |
| `-[OOMusic initWithContentsOfFile:]` (50) | `OOMusic::initWithContentsOfFile` (static) `Core/OOALMusic.cpp:45` | ✅ |
| `-[OOMusic name]` (64) | `OOMusic::name` `Core/OOALMusic.cpp:61` (null sound → nullopt, as `[nil name]`) | ✅ |
| `-[OOMusic setMusicGain:]` (69) | `OOMusic::setMusicGain` `Core/OOALMusic.cpp:65` | ✅ |
| `-[OOMusic musicGain]` (76) | `OOMusic::musicGain` `Core/OOALMusic.cpp:71` | ✅ |
| `-[OOMusic playLooped:]` (83) | `OOMusic::playLooped` `Core/OOALMusic.cpp:76` — stop, setLoop, setSound, play, then `sPlayingMusic` | ✅ |
| `-[OOMusic musicSoundSource]` (98) | `OOMusic::musicSoundSource` `Core/OOALMusic.cpp:94` | ✅ |
| `-[OOMusic isPlaying]` (103) | `OOMusic::isPlaying` `Core/OOALMusic.cpp:96` | ✅ |
| `-[OOMusic stop]` (108) | `OOMusic::stop` `Core/OOALMusic.cpp:101` | ✅ |

**Differences:**

- ➖ **low** — `+allocWithZone:` only bypassed OOSound's class-cluster allocation. The port constructs `OOMusic` directly, and the base constructor still runs `setUp` before `OOSound::initWithContentsOfFile` (which returns null if `!sIsSoundOK`, as upstream). Nothing observable changes. (still open) — upstream `Core/OOALMusic.m:36` ↔ port `Core/OOALMusic.cpp:50`
- ✅ note (bug-compatible) — the single `sMusicSource` is created on the first `playLooped` and never freed. `setMusicGain` before the first play does nothing, so the first track plays at `OO_DEFAULT_SOUNDSOURCE_GAIN` whatever gain was asked. The null checks in `isPlaying`/`stop` mirror messages to nil. — upstream `Core/OOALMusic.m:69-115` ↔ port `Core/OOALMusic.cpp:65-109`

## OOALSound

<a id="ooalsound"></a>
Upstream `src/Core/OOALSound.m` ↔ `Core/OOALSound.cpp` (164 / 176 lines)

**Status:** done — 12 rows: 10 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOSound setUp]` (46) | `OOSound::setUp` `Core/OOALSound.cpp:59` | ❌ |
| `+[OOSound setMasterVolume:]` (61) | `OOSound::setMasterVolume` `Core/OOALSound.cpp:76` — clamp, compare with listener gain, write pref; nil controller answers 0 | ✅ |
| `+[OOSound masterVolume]` (75) | `OOSound::masterVolume` `Core/OOALSound.cpp:92` | ✅ |
| `-[OOSound init]` (84) | `OOSound::OOSound()` `Core/OOALSound.cpp:99` | ✅ |
| `-[OOSound initWithContentsOfFile:]` (91) | `OOSound::initWithContentsOfFile` (static) `Core/OOALSound.cpp:107` — `!sIsSoundOK` early-out before setUp kept; 1 MB cut-off; same log classes/text | ✅ |
| `-[OOSound initWithDecoder:]` (124) | none. The subclasses' static `initWithDecoder` factories replace it | ➖ |
| `-[OOSound name]` (130) | `OOSound::name` `Core/OOALSound.cpp:138` | ✅ |
| `+[OOSound update]` (136) | `OOSound::update` `Core/OOALSound.cpp:143` | ✅ |
| `+[OOSound isSoundOK]` (143) | `OOSound::isSoundOK` `Core/OOALSound.cpp:148` | ✅ |
| `-[OOSound soundBuffer]` (148) | `OOSound::soundBuffer` `Core/OOALSound.cpp:150` | ✅ |
| `-[OOSound soundIncomplete]` (154) | `OOSound::soundIncomplete` `Core/OOALSound.cpp:155` | ✅ |
| `-[OOSound rewind]` (159) | `OOSound::rewind` `Core/OOALSound.cpp:157` | ✅ |

**Differences:**

- ❌ **low** — `volume_control` default (cross-cutting preference-defaults pattern). Upstream `oo_floatForKey:defaultValue:0.5` goes through `OOFloatFromObject`: a non-numeric string or a non-number object (array, dict) gives **0.5**. The port uses 0.5 only when the key is absent, else `Defaults::floatForKey`, which gives **0** for an unparseable string (`stringDoubleValue`) and for any non-number. A malformed pref therefore mutes the game (0 is then clamped and written back). (still open) — upstream `Core/OOALSound.m:53` (`Core/OOCollectionExtractors.m:727-730,1167-1182`) ↔ port `Core/OOALSound.cpp:65-68` (`oofnd/Defaults.hpp:509-517`)
- ✅ note (bug-compatible) — after a failed `setUp` (`-nosound`), `sIsSetUp` is true, so `setMasterVolume` continues with a null controller and stores **0** into `volume_control` whenever `fraction != 0`. The port reproduces this explicitly. — upstream `Core/OOALSound.m:61-73` ↔ port `Core/OOALSound.cpp:76-90`
- ➖ **low** — base `-initWithDecoder:` (`[self release]; return nil`) has no counterpart; nothing calls it. (still open) — upstream `Core/OOALSound.m:124` ↔ port n/a
- ✅ note — `description()`/`descriptionComponents()` are added; they print `<ClassName 0x…>` with an optional `{…}`, matching upstream's `NSObject (OODescriptionComponents)` `-description` (`Core/OOFoundation.m:44-54`) that `OOSoundSource`'s `%@` used. — port `Core/OOALSound.cpp:161-176`

## OOALSoundChannel

<a id="ooalsoundchannel"></a>
Upstream `src/Core/OOALSoundChannel.m` ↔ `Core/OOALSoundChannel.cpp` (223 / 196 lines)

**Status:** done — 14 rows: 14 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSoundChannel init]` (43) | `OOSoundChannel::init` `Core/OOALSoundChannel.cpp:35` | ✅ |
| `-[OOSoundChannel dealloc]` (61) | `~OOSoundChannel` `Core/OOALSoundChannel.cpp:54` | ✅ |
| `-[OOSoundChannel update]` (68) | `OOSoundChannel::update` `Core/OOALSoundChannel.cpp:59` — stopped / incomplete / loop branches, same `sound.buffer` logs | ✅ |
| `-[OOSoundChannel getNextSoundBuffer]` (89) | `OOSoundChannel::getNextSoundBuffer` `Core/OOALSoundChannel.cpp:81` | ✅ |
| `-[OOSoundChannel setDelegate:]` (115) | `OOSoundChannel::setDelegate` `Core/OOALSoundChannel.cpp:106` | ✅ |
| `-[OOSoundChannel next]` (120) | `OOSoundChannel::next` `Core/OOALSoundChannel.cpp:110` | ✅ |
| `-[OOSoundChannel setNext:]` (125) | `OOSoundChannel::setNext` `Core/OOALSoundChannel.cpp:112` | ✅ |
| `-[OOSoundChannel setPosition:]` (130) | `OOSoundChannel::setPosition` `Core/OOALSoundChannel.cpp:114` | ✅ |
| `-[OOSoundChannel setGain:]` (135) | `OOSoundChannel::setGain` `Core/OOALSoundChannel.cpp:118` | ✅ |
| `-[OOSoundChannel playSound:looped:]` (140) | `OOSoundChannel::playSound` `Core/OOALSoundChannel.cpp:122` | ✅ |
| `-[OOSoundChannel stop]` (159) | `OOSoundChannel::stop` `Core/OOALSoundChannel.cpp:138` | ✅ |
| `-[OOSoundChannel hasStopped]` (168) | `OOSoundChannel::hasStopped` `Core/OOALSoundChannel.cpp:146` — sound cleared before delegate, released after (scope end) | ✅ |
| `-[OOSoundChannel enqueueBuffer:]` (194) | `OOSoundChannel::enqueueBuffer` `Core/OOALSoundChannel.cpp:170` | ✅ |
| `-[OOSoundChannel sound]` (218) | `OOSoundChannel::sound` `Core/OOALSoundChannel.cpp:196` | ✅ |

**Differences:**

- ✅ note — the destructor skips `hasStopped()` when `_source == 0` (only after a failed `init()`); upstream ran it against source 0 with a nil delegate, a no-op. — upstream `Core/OOALSoundChannel.m:50,63` ↔ port `Core/OOALSoundChannel.cpp:55`
- ✅ note — `respondsToSelector:` is gone because the delegate is a typed `OOSoundChannelDelegate`; both upstream delegates responded. — upstream `Core/OOALSoundChannel.m:188-190` ↔ port `Core/OOALSoundChannel.cpp:165-167`
- ✅ note (bug-compatible) — if `enqueueBuffer` fails inside `playSound`, `_sound` stays null, so `update`/`stop` never reach `hasStopped` and the channel is never returned to the mixer; same on both sides. — upstream `Core/OOALSoundChannel.m:151-156` ↔ port `Core/OOALSoundChannel.cpp:130-135`
- ✅ note — `ov.debug` formats `%p` through `pointerDescription` and `%d` via `static_cast<int>`; `sound.buffer` logs use `name().value_or("(null)")`. — upstream `Core/OOALSoundChannel.m:78,81,202,211` ↔ port `Core/OOALSoundChannel.cpp:68,72,177,188`

## OOALSoundDecoder

<a id="ooalsounddecoder"></a>
Upstream `src/Core/OOALSoundDecoder.m` ↔ `Core/OOALSoundDecoder.cpp` (461 / 445 lines)

**Status:** done — 22 rows: 20 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOALSoundDecoder initWithPath:]` (60) | `OOALSoundDecoder::initWithPath` (static) `Core/OOALSoundDecoder.cpp:87` — nil path → "" extension → null, as `[nil pathExtension]` | ✅ |
| `+[OOALSoundDecoder codecWithPath:]` (72) | `OOALSoundDecoder::codecWithPath` `Core/OOALSoundDecoder.cpp:98` | ✅ |
| `-[OOALSoundDecoder streamToBuffer:]` (80) | `OOALSoundDecoder::streamToBuffer` `Core/OOALSoundDecoder.cpp:106` | ✅ |
| `-[OOALSoundDecoder readCreatingBuffer:withFrameCount:]` (85) | `OOALSoundDecoder::readCreatingBuffer` `Core/OOALSoundDecoder.cpp:108` | ✅ |
| `-[OOALSoundDecoder sizeAsBuffer]` (95) | `OOALSoundDecoder::sizeAsBuffer` `Core/OOALSoundDecoder.cpp:113` | ✅ |
| `-[OOALSoundDecoder isStereo]` (100) | `OOALSoundDecoder::isStereo` `Core/OOALSoundDecoder.cpp:115` | ✅ |
| `-[OOALSoundDecoder sampleRate]` (105) | `OOALSoundDecoder::sampleRate` `Core/OOALSoundDecoder.cpp:117` | ✅ |
| `-[OOALSoundDecoder reset]` (110) | `OOALSoundDecoder::reset` `Core/OOALSoundDecoder.cpp:119` | ✅ |
| `-[OOALSoundDecoder name]` (115) | `OOALSoundDecoder::name` `Core/OOALSoundDecoder.cpp:123` | ✅ |
| `-[OOALSoundVorbisCodec initWithPath:]` (124) | `OOALSoundVorbisCodec::createWithPath` + `initWithPath` `Core/OOALSoundDecoder.cpp:129,143` — same oxz split, unz calls, 3 `files.notFound` messages | ✅ |
| `-[OOALSoundVorbisCodec dealloc]` (236) | `~OOALSoundVorbisCodec` `Core/OOALSoundDecoder.cpp:250` | ✅ |
| `-[OOALSoundVorbisCodec comments]` (251) | `OOALSoundVorbisCodec::comments` `Core/OOALSoundDecoder.cpp:261` | ✅ |
| `-[OOALSoundVorbisCodec readCreatingBuffer:withFrameCount:]` (284) | `OOALSoundVorbisCodec::readCreatingBuffer` `Core/OOALSoundDecoder.cpp:289` | ❌ |
| `-[OOALSoundVorbisCodec streamToBuffer:]` (352) | `OOALSoundVorbisCodec::streamToBuffer` `Core/OOALSoundDecoder.cpp:341` | ✅ |
| `-[OOALSoundVorbisCodec sizeAsBuffer]` (383) | `OOALSoundVorbisCodec::sizeAsBuffer` `Core/OOALSoundDecoder.cpp:369` | ✅ |
| `-[OOALSoundVorbisCodec isStereo]` (393) | `OOALSoundVorbisCodec::isStereo` `Core/OOALSoundDecoder.cpp:378` | ✅ |
| `-[OOALSoundVorbisCodec description]` (398) | `OOALSoundVorbisCodec::descriptionComponents` `Core/OOALSoundDecoder.cpp:385` (no `description()` on the decoder) | ➖ |
| `-[OOALSoundVorbisCodec sampleRate]` (403) | `OOALSoundVorbisCodec::sampleRate` `Core/OOALSoundDecoder.cpp:398` | ✅ |
| `-[OOALSoundVorbisCodec reset]` (408) | `OOALSoundVorbisCodec::reset` `Core/OOALSoundDecoder.cpp:400` | ✅ |
| `-[OOALSoundVorbisCodec name]` (431) | `OOALSoundVorbisCodec::name` `Core/OOALSoundDecoder.cpp:422` | ✅ |
| `OOReadOXZVorbis` (438) | `OOReadOXZVorbis` `Core/OOALSoundDecoder.cpp:424` — reads straight into `ptr`; same return values | ✅ |
| `OOCloseOXZVorbis` (455) | `OOCloseOXZVorbis` `Core/OOALSoundDecoder.cpp:440` | ✅ |

**Differences:**

- ❌ **low** — decode-error size underflow. Upstream does `sizeInFrames -= remaining` (frames minus *bytes*) and reports `*outSize = sizeInFrames * frameSize`. When `ov_read` fails with less than (frameSize−1)/frameSize of the bytes read (half for mono, ¾ for stereo), this wraps to a huge value, and the `(ALsizei)` cast in `alBufferData` makes it invalid, so the sound is silent. The port clamps with `std::min(buffer.size(), …)`, so it plays the whole buffer: the decoded part plus a zero tail. This only affects corrupt or truncated buffered (≤1 MB) Vorbis files. When nothing wraps, the sizes match. (new) — upstream `Core/OOALSoundDecoder.m:339,344` ↔ port `Core/OOALSoundDecoder.cpp:333,336`
- ➖ **low** — upstream `-description` printed `<OOALSoundVorbisCodec %p>{"name", comments=…}`. The port has only `descriptionComponents()`, which now formats the comments through `oo::DescriptionOf(PList)`. The decoder (an `oo::Object`) has no `description()` wrapper, and nothing formats a decoder. (still open) — upstream `Core/OOALSoundDecoder.m:398-401` ↔ port `Core/OOALSoundDecoder.cpp:382-396`
- ✅ note — `OOReadOXZVorbis` now reads directly into libvorbis's buffer instead of a leaked `malloc` copy. Bytes and return values are identical, and the leak is gone. Upstream's `malloc(0)`→NULL failure path for a zero-frame file returns NO, while the port returns true with an empty buffer. glibc/MSVC return non-NULL for `malloc(0)`, so this is not observable in practice. — upstream `Core/OOALSoundDecoder.m:309-311,438-453` ↔ port `Core/OOALSoundDecoder.cpp:306,424-438`
- ✅ note (bug-compatible) — OXZ failure paths call `unzClose(uf)` and the destructor then calls `unzClose(uf)` again. Buffer constants (4096 scratch, `OOAL_STREAM_CHUNK_SIZE`, `ov_read(…,0,2,1,…)`), `OV_HOLE`→continue, the `.oxz` case-insensitive and `.ogg` case-sensitive matches are all unchanged. — upstream `Core/OOALSoundDecoder.m:136,186-221,246` ↔ port `Core/OOALSoundDecoder.cpp:157,199-235,258`

## OOALSoundMixer

<a id="ooalsoundmixer"></a>
Upstream `src/Core/OOALSoundMixer.m` ↔ `Core/OOALSoundMixer.cpp` (158 / 116 lines)

**Status:** done — 12 rows: 5 ✅ 1 ⚠️ 0 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOSoundMixer sharedMixer]` (39) | `OOSoundMixer::sharedMixer` `Core/OOALSoundMixer.cpp:48` | ⚠️ |
| `-[OOSoundMixer init]` (47) | `OOSoundMixer::init` `Core/OOALSoundMixer.cpp:61` — setUp gate, 32 channels, push then store, failed channels skipped | ✅ |
| `-[OOSoundMixer shutdown]` (81) | `OOSoundMixer::shutdown` `Core/OOALSoundMixer.cpp:85` | ✅ |
| `-[OOSoundMixer update]` (89) | `OOSoundMixer::update` `Core/OOALSoundMixer.cpp:92` (null holes checked, as nil messages) | ✅ |
| `-[OOSoundMixer popChannel]` (97) | `OOSoundMixer::popChannel` `Core/OOALSoundMixer.cpp:99` | ✅ |
| `-[OOSoundMixer pushChannel:]` (106) | `OOSoundMixer::pushChannel` `Core/OOALSoundMixer.cpp:108` | ✅ |
| `+[OOSoundMixer(Singleton) allocWithZone:]` (125) | none. Folded into `sharedMixer` (comment `Core/OOALSoundMixer.cpp:42-47,115-116`) | ➖ |
| `-[OOSoundMixer(Singleton) copyWithZone:]` (134) | none (`Core/OOALSoundMixer.cpp:115`) | ➖ |
| `-[OOSoundMixer(Singleton) retain]` (139) | none (`Core/OOALSoundMixer.cpp:115`) | ➖ |
| `-[OOSoundMixer(Singleton) retainCount]` (144) | none (`Core/OOALSoundMixer.cpp:115`) | ➖ |
| `-[OOSoundMixer(Singleton) release]` (149) | none (`Core/OOALSoundMixer.cpp:115`) | ➖ |
| `-[OOSoundMixer(Singleton) autorelease]` (153) | none (`Core/OOALSoundMixer.cpp:115`) | ➖ |

**Differences:**

- ⚠️ **low** — if `init` fails (`OOSound::setUp` fails), upstream `[super release]` freed the mixer but left `sSingleton` dangling and returned it. The port clears `sSingleton`, returns null and retries on the next call. The code comment says this is deliberate ("a dangling singleton was undefined behaviour"). Nothing observable changes, because `OOSound::update` and `play` check for a null mixer or `sIsSoundOK`. (still open) — upstream `Core/OOALSoundMixer.m:39-45,69-77,125-131` ↔ port `Core/OOALSoundMixer.cpp:42-58`
- ➖ **low** — the singleton category (no-op retain/release, `retainCount = UINT_MAX`) is not translated, and the mixer is leaked (`mixer.release()`). (still open) — upstream `Core/OOALSoundMixer.m:116-158` ↔ port `Core/OOALSoundMixer.cpp:53,115-116`
- ✅ note — the allocation policy is unchanged: a LIFO free list, `popChannel` on an empty list returns null, and nothing is stolen. After `shutdown`, `_freeList` still points at freed channels on both sides (bug-compatible). — upstream `Core/OOALSoundMixer.m:60-111` ↔ port `Core/OOALSoundMixer.cpp:68-113`

## OOALStreamedSound

<a id="ooalstreamedsound"></a>
Upstream `src/Core/OOALStreamedSound.m` ↔ `Core/OOALStreamedSound.cpp` (114 / 104 lines)

**Status:** done — 6 rows: 6 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOALStreamedSound dealloc]` (34) | `~OOALStreamedSound` (default) `Core/OOALStreamedSound.cpp:35` | ✅ |
| `-[OOALStreamedSound name]` (43) | `OOALStreamedSound::name` `Core/OOALStreamedSound.cpp:37` | ✅ |
| `-[OOALStreamedSound initWithDecoder:]` (48) | `OOALStreamedSound::initWithDecoder` (static) `Core/OOALStreamedSound.cpp:43` — same field order, chunk buffer, decoder retained (`oo::share`), `rewind` | ✅ |
| `-[OOALStreamedSound rewind]` (79) | `OOALStreamedSound::rewind` `Core/OOALStreamedSound.cpp:72` | ✅ |
| `-[OOALStreamedSound soundIncomplete]` (85) | `OOALStreamedSound::soundIncomplete` `Core/OOALStreamedSound.cpp:77` | ✅ |
| `-[OOALStreamedSound soundBuffer]` (90) | `OOALStreamedSound::soundBuffer` `Core/OOALStreamedSound.cpp:79` | ✅ |

**Differences:**

- ✅ note — the end-of-stream test (`transferred < OOAL_STREAM_CHUNK_SIZE` → `_reachedEnd`) and the one-AL-buffer-per-chunk behaviour are unchanged. Upstream leaked `_name` in `-dealloc`, which is not observable. The null-decoder guards mirror nil messages. — upstream `Core/OOALStreamedSound.m:34-41,90-112` ↔ port `Core/OOALStreamedSound.cpp:35,79-104`

## OOBasicSoundReferencePoint

<a id="oobasicsoundreferencepoint"></a>
Upstream `src/Core/OOBasicSoundReferencePoint.m` ↔ `Core/OOBasicSoundReferencePoint.cpp` (41 / 31 lines)

**Status:** done — 3 rows: 3 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSoundReferencePoint setPosition:]` (29) | `OOSoundReferencePoint::setPosition` `Core/OOBasicSoundReferencePoint.cpp:27` | ✅ |
| `-[OOSoundReferencePoint setVelocity:]` (33) | `OOSoundReferencePoint::setVelocity` `Core/OOBasicSoundReferencePoint.cpp:29` | ✅ |
| `-[OOSoundReferencePoint setOrientation:]` (37) | `OOSoundReferencePoint::setOrientation` `Core/OOBasicSoundReferencePoint.cpp:31` | ✅ |

**Differences:**

- *none*. All three are no-ops on both sides.

## OOMusic

<a id="oomusic"></a>
Upstream `src/Core/OOMusic.m` ↔ *(absorbed — the `OOMusic` class lives in `Core/OOALMusic.cpp`)*

**Status:** done — 1 rows: 0 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| file body `#ifdef LINUX #import "SDLMusic.m"` (9-11) | none. Dead file; the `OOMusic` class is `OOALMusic.m` → `Core/OOALMusic.cpp` | ➖ |

**Differences:**

- ➖ **low** — `OOMusic.m` defines no methods. It is an old OS selector that `#import`s `SDLMusic.m` under `LINUX`, and that file no longer exists upstream. The `OOMusic` class is audited above under OOALMusic. No behaviour is lost. (still open) — upstream `Core/OOMusic.m:9-11` ↔ port `Core/OOALMusic.cpp`

## OOMusicController

<a id="oomusiccontroller"></a>
Upstream `src/Core/OOMusicController.m` ↔ `Core/OOMusicController.cpp` (361 / 245 lines)

**Status:** done — 31 rows: 23 ✅ 0 ⚠️ 0 ❌ 8 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOMusicController sharedController]` (51) | `OOMusicController::sharedController` `Core/OOMusicController.cpp:44` | ✅ |
| `-[OOMusicController init]` (60) | `OOMusicController::OOMusicController()` `Core/OOMusicController.cpp:57` — `music mode` off/iTunes/else On, clamp to `kOOMusicModeMax` (= On, non-Mac), mission music `OoliteTheme.ogg` | ✅ |
| `-[OOMusicController playMusicNamed:loop:]` (82) | `playMusicNamed(name, loop)` `Core/OOMusicController.cpp:75` | ✅ |
| `-[OOMusicController playMusicNamed:loop:gain:]` (87) | `playMusicNamed(name, loop, gain)` `Core/OOMusicController.cpp:79` — stop current, clamped gain, playLooped, replace | ✅ |
| `-[OOMusicController playThemeMusic]` (106) | `OOMusicController::playThemeMusic` `Core/OOMusicController.cpp:98` | ✅ |
| `-[OOMusicController playDockingMusic]` (112) | `OOMusicController::playDockingMusic` `Core/OOMusicController.cpp:103` | ✅ |
| `-[OOMusicController playDockedMusic]` (123) | `OOMusicController::playDockedMusic` `Core/OOMusicController.cpp:113` | ✅ |
| `-[OOMusicController setMissionMusic:]` (134) | `OOMusicController::setMissionMusic` `Core/OOMusicController.cpp:123` | ✅ |
| `-[OOMusicController playMissionMusic]` (140) | `OOMusicController::playMissionMusic` `Core/OOMusicController.cpp:128` | ✅ |
| `-[OOMusicController justStop]` (149) | `OOMusicController::justStop` `Core/OOMusicController.cpp:136` | ✅ |
| `-[OOMusicController stop]` (157) | `OOMusicController::stop` `Core/OOMusicController.cpp:142` | ✅ |
| `-[OOMusicController stopMusicNamed:]` (166) | `OOMusicController::stopMusicNamed` `Core/OOMusicController.cpp:150` — `string == nullopt` is false, as `[name isEqual:nil]` | ✅ |
| `-[OOMusicController stopThemeMusic]` (172) | `OOMusicController::stopThemeMusic` `Core/OOMusicController.cpp:154` | ✅ |
| `-[OOMusicController stopDockingMusic]` (180) | `OOMusicController::stopDockingMusic` `Core/OOMusicController.cpp:161` | ✅ |
| `-[OOMusicController stopMissionMusic]` (186) | `OOMusicController::stopMissionMusic` `Core/OOMusicController.cpp:165` | ✅ |
| `-[OOMusicController toggleDockingMusic]` (192) | `OOMusicController::toggleDockingMusic` `Core/OOMusicController.cpp:169` | ✅ |
| `-[OOMusicController soundSource]` (203) | `OOMusicController::soundSource` `Core/OOMusicController.cpp:178` | ✅ |
| `-[OOMusicController playingMusic]` (208) | `OOMusicController::playingMusic` `Core/OOMusicController.cpp:182` | ✅ |
| `-[OOMusicController isPlaying]` (213) | `OOMusicController::isPlaying` `Core/OOMusicController.cpp:186` | ✅ |
| `-[OOMusicController mode]` (218) | `OOMusicController::mode` `Core/OOMusicController.cpp:190` | ✅ |
| `-[OOMusicController setMode:]` (223) | `OOMusicController::setMode` `Core/OOMusicController.cpp:192` — same switch, pref strings off/on/iTunes | ✅ |
| `+[OOMusicController(Singleton) allocWithZone:]` (282) | none (comment `Core/OOMusicController.cpp:239-240`) | ➖ |
| `-[OOMusicController(Singleton) copyWithZone:]` (291) | none (`Core/OOMusicController.cpp:239`) | ➖ |
| `-[OOMusicController(Singleton) retain]` (296) | none (`Core/OOMusicController.cpp:239`) | ➖ |
| `-[OOMusicController(Singleton) retainCount]` (301) | none (`Core/OOMusicController.cpp:239`) | ➖ |
| `-[OOMusicController(Singleton) release]` (306) | none (`Core/OOMusicController.cpp:239`) | ➖ |
| `-[OOMusicController(Singleton) autorelease]` (310) | none (`Core/OOMusicController.cpp:239`) | ➖ |
| `-[OOMusicController(Private) playiTunesPlaylist:]` (320, Mac) | none. Only the no-op stub remains `Core/OOMusicController.cpp:244` (comment 242-243) | ➖ |
| `-[OOMusicController(Private) pauseiTunes]` (342, Mac) | none. Only the no-op stub remains `Core/OOMusicController.cpp:245` | ➖ |
| `-[OOMusicController(Private) playiTunesPlaylist:]` (353, non-Mac stub) | `OOMusicController::playiTunesPlaylist` `Core/OOMusicController.cpp:244` | ✅ |
| `-[OOMusicController(Private) pauseiTunes]` (356, non-Mac stub) | `OOMusicController::pauseiTunes` `Core/OOMusicController.cpp:245` | ✅ |

**Differences:**

- ➖ **low** — the singleton category is not translated, and the controller is leaked through a never-deleted holder. (still open) — upstream `Core/OOMusicController.m:273-315` ↔ port `Core/OOMusicController.cpp:44-54,239-240`
- ➖ **low** — the Mac-only AppleScript iTunes bodies (`playiTunesPlaylist:`, `pauseiTunes`, the `sound.music.iTunesIntegration.failed` log) are gone; only the non-Mac no-op stubs remain, per the comment. The previous run mapped them to port lines 269/292, which no longer exist. Non-Mac builds behave the same, since `kOOMusicModeMax` = On means iTunes mode can't be reached. (new) — upstream `Core/OOMusicController.m:319-351` ↔ port `Core/OOMusicController.cpp:242-245`
- ✅ note — track names (`OoliteTheme.ogg`, `BlueDanube.ogg` looped, `OoliteDocked.ogg` not looped, mission music not looped) and the `_special` state machine are unchanged. Music isn't cached (`cache:NULL`), so every call makes a fresh `OOMusic`. The old `_current` is released after the new one has started, and its destructor's `stop` is a no-op because `sPlayingMusic` has already moved on, as upstream. — upstream `Core/OOMusicController.m:87-104` ↔ port `Core/OOMusicController.cpp:79-96`

## OOOpenALController

<a id="ooopenalcontroller"></a>
Upstream `src/Core/OOOpenALController.m` ↔ `Core/OOOpenALController.cpp` (102 / 102 lines)

**Status:** done — 5 rows: 5 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOOpenALController sharedController]` (34) | `OOOpenALController::sharedController` `Core/OOOpenALController.cpp:39` — null on failure, retried next call, as nil `sSingleton` | ✅ |
| `-[OOOpenALController init]` (43) | `OOOpenALController::init` `Core/OOOpenALController.cpp:58` | ✅ |
| `-[OOOpenALController setMasterVolume:]` (80) | `OOOpenALController::setMasterVolume` `Core/OOOpenALController.cpp:85` | ✅ |
| `-[OOOpenALController masterVolume]` (85) | `OOOpenALController::masterVolume` `Core/OOOpenALController.cpp:89` | ✅ |
| `-[OOOpenALController shutdown]` (94) | `OOOpenALController::shutdown` `Core/OOOpenALController.cpp:97` | ✅ |

**Differences:**

- ✅ note — `-nosound`/`--nosound` are exact matches over all of argv (`oo::process::hasArgument`, `oofnd/Process.hpp:90`). The default device and context are unchanged, `AL_NONE` is still the distance model, and the three `sound.initialization.error` messages are unchanged (`%d` of an ALuint becomes `{}`, which prints the same for real AL error codes). `shutdown` null-checks the mixer, as a nil message would. — upstream `Core/OOOpenALController.m:34-100` ↔ port `Core/OOOpenALController.cpp:39-102`

## OOSoundSource

<a id="oosoundsource"></a>
Upstream `src/Core/OOSoundSource.m` ↔ `Core/OOSoundSource.cpp` (299 / 291 lines)

**Status:** done — 32 rows: 31 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOSoundSource sourceWithSound:]` (36) | `OOSoundSource::sourceWithSound` `Core/OOSoundSource.cpp:59` | ✅ |
| `-[OOSoundSource init]` (41) | `OOSoundSource::OOSoundSource()` `Core/OOSoundSource.cpp:64` — not positional, zero position, gain `OO_DEFAULT_SOUNDSOURCE_GAIN` | ✅ |
| `-[OOSoundSource initWithSound:]` (53) | `OOSoundSource::OOSoundSource(OOSound*)` `Core/OOSoundSource.cpp:70` | ✅ |
| `-[OOSoundSource dealloc]` (64) | `~OOSoundSource` `Core/OOSoundSource.cpp:77` | ✅ |
| `-[OOSoundSource descriptionComponents]` (72) | `OOSoundSource::descriptionComponents` `Core/OOSoundSource.cpp:82` — same text, `%u` of repeatCount, `<Class 0x…>` for sound and channel | ✅ |
| `-[OOSoundSource sound]` (81) | `OOSoundSource::sound` `Core/OOSoundSource.cpp:100` | ✅ |
| `-[OOSoundSource setSound:]` (86) | `OOSoundSource::setSound` `Core/OOSoundSource.cpp:102` | ✅ |
| `-[OOSoundSource loop]` (95) | `OOSoundSource::loop` `Core/OOSoundSource.cpp:109` | ✅ |
| `-[OOSoundSource setLoop:]` (100) | `OOSoundSource::setLoop` `Core/OOSoundSource.cpp:111` | ✅ |
| `-[OOSoundSource repeatCount]` (105) | `OOSoundSource::repeatCount` `Core/OOSoundSource.cpp:113` | ✅ |
| `-[OOSoundSource setRepeatCount:]` (110) | `OOSoundSource::setRepeatCount` `Core/OOSoundSource.cpp:115` | ✅ |
| `-[OOSoundSource isPlaying]` (115) | `OOSoundSource::isPlaying` `Core/OOSoundSource.cpp:117` | ✅ |
| `-[OOSoundSource play]` (120) | `OOSoundSource::play` `Core/OOSoundSource.cpp:123` | ✅ |
| `-[OOSoundSource playOrRepeat]` (148) | `OOSoundSource::playOrRepeat` `Core/OOSoundSource.cpp:153` | ✅ |
| `-[OOSoundSource stop]` (156) | `OOSoundSource::stop` `Core/OOSoundSource.cpp:160` | ✅ |
| `+[OOSoundSource stopAll]` (172) | `OOSoundSource::stopAll` `Core/OOSoundSource.cpp:182` | ⚠️ |
| `-[OOSoundSource playSound:]` (186) | `OOSoundSource::playOOSound` `Core/OOSoundSource.cpp:199` (raw `_repeatCount`, as upstream) | ✅ |
| `-[OOSoundSource playSound:repeatCount:]` (191) | `OOSoundSource::playSound(sound, count)` `Core/OOSoundSource.cpp:203` | ✅ |
| `-[OOSoundSource playOrRepeatSound:]` (199) | `OOSoundSource::playOrRepeatSound` `Core/OOSoundSource.cpp:210` | ✅ |
| `-[OOSoundSource setPositional:]` (207) | `OOSoundSource::setPositional` `Core/OOSoundSource.cpp:217` | ✅ |
| `-[OOSoundSource positional]` (220) | `OOSoundSource::positional` `Core/OOSoundSource.cpp:229` | ✅ |
| `-[OOSoundSource setPosition:]` (225) | `OOSoundSource::setPosition` `Core/OOSoundSource.cpp:231` | ✅ |
| `-[OOSoundSource position]` (236) | `OOSoundSource::position` `Core/OOSoundSource.cpp:241` | ✅ |
| `-[OOSoundSource setGain:]` (241) | `OOSoundSource::setGain` `Core/OOSoundSource.cpp:243` (unclamped, as upstream) | ✅ |
| `-[OOSoundSource gain]` (249) | `OOSoundSource::gain` `Core/OOSoundSource.cpp:250` | ✅ |
| `-[OOSoundSource setVelocity:]` (255) | `OOSoundSource::setVelocity` `Core/OOSoundSource.cpp:253` | ✅ |
| `-[OOSoundSource setOrientation:]` (259) | `OOSoundSource::setOrientation` `Core/OOSoundSource.cpp:255` | ✅ |
| `-[OOSoundSource setConeAngle:]` (263) | `OOSoundSource::setConeAngle` `Core/OOSoundSource.cpp:257` | ✅ |
| `-[OOSoundSource setGainInsideCone:outsideCone:]` (267) | `OOSoundSource::setGainInsideCone` `Core/OOSoundSource.cpp:259` | ✅ |
| `-[OOSoundSource positionRelativeTo:]` (271) | `OOSoundSource::positionRelativeTo` `Core/OOSoundSource.cpp:262` | ✅ |
| `-[OOSoundSource channel:didFinishPlayingSound:]` (276) | `OOSoundSource::channel` `Core/OOSoundSource.cpp:265` | ✅ |
| `+[OOSoundSource channel:didFinishPlayingSound:]` (293) | `OOSoundSource::channelOfStoppedSource` via `StoppedSourceHandler` `Core/OOSoundSource.cpp:44,286` | ✅ |

**Differences:**

- ⚠️ **low** — `stopAll` stops sources in the order they started playing, where upstream used NSMutableSet hash order (code comment `Core/OOSoundSource.cpp:192`). The only effect is the order in which channels go back onto the LIFO free list, which decides the AL source later sounds get. Nothing audible changes. (still open) — upstream `Core/OOSoundSource.m:179-183` ↔ port `Core/OOSoundSource.cpp:188-196`
- ✅ note — the retain discipline is preserved through `_playingHold`. `play` takes the hold only when it gets a channel, but adds the source to the playing set (deduplicated) even when it gets none. `stop` removes the source from the set and drops the hold. A natural finish drops the hold and pushes the channel back but leaves the source in the set until `stopAll` (bug-compatible). Every creator uses `oo::makeShared`, so `oo::share(this)` cannot throw (`PlayerEntitySound.cpp:68`, `OOSoundSourcePool.cpp:104`, `OOALMusic.cpp:82`, `OOTrumble.cpp:900`, `OOJSSoundSource.cpp:159`). — upstream `Core/OOSoundSource.m:120-170,276-291` ↔ port `Core/OOSoundSource.cpp:123-180,265-284`
- ✅ note — the repeat logic is unchanged: `_remainingCount = repeatCount()` (0 is treated as 1), and `--_remainingCount` replays with `looped:false`. `setPosition` sets `_positional` for a non-zero vector, and `setPositional(false)` zeroes the position. — upstream `Core/OOSoundSource.m:132,148-154,207-234,282-284` ↔ port `Core/OOSoundSource.cpp:133,153-158,217-239,270-271`

## OOSoundSourcePool

<a id="oosoundsourcepool"></a>
Upstream `src/Core/OOSoundSourcePool.m` ↔ `Core/OOSoundSourcePool.cpp` (249 / 187 lines)

**Status:** done — 12 rows: 12 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOSoundSourcePool poolWithCount:minRepeatTime:]` (50) | `OOSoundSourcePool::poolWithCount` `Core/OOSoundSourcePool.cpp:40` | ✅ |
| `-[OOSoundSourcePool initWithCount:minRepeatTime:]` (55) | `OOSoundSourcePool::initWithCount` `Core/OOSoundSourcePool.cpp:49` — count clamp [1,254], minRepeat ≥ 0, zeroed elements | ✅ |
| `-[OOSoundSourcePool dealloc]` (80) | `~OOSoundSourcePool` (default) `Core/OOSoundSourcePool.cpp:66` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:priority:expiryTime:overlap:position:]` (94) | `playSoundWithKey(key, float, OOTimeDelta, bool, Vector)` `Core/OOSoundSourcePool.cpp:72` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:priority:expiryTime:]` (154) | `playSoundWithKey(key, float, OOTimeDelta)` `Core/OOSoundSourcePool.cpp:124` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:priority:position:]` (165) | `playSoundWithKey(key, float, Vector)` `Core/OOSoundSourcePool.cpp:129` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:priority:]` (176) | `playSoundWithKey(key, float)` `Core/OOSoundSourcePool.cpp:134` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:]` (184) | `playSoundWithKey(key)` `Core/OOSoundSourcePool.cpp:139` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:position:]` (189) | `playSoundWithKey(key, Vector)` `Core/OOSoundSourcePool.cpp:143` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:overlap:]` (194) | `playSoundWithKey(key, bool)` `Core/OOSoundSourcePool.cpp:148` | ✅ |
| `-[OOSoundSourcePool playSoundWithKey:overlap:position:]` (203) | `playSoundWithKey(key, bool, Vector)` `Core/OOSoundSourcePool.cpp:152` | ✅ |
| `-[OOSoundSourcePool(Private) selectSlotForPriority:]` (216) | `OOSoundSourcePool::selectSlotForPriority` `Core/OOSoundSourcePool.cpp:158` | ✅ |

**Differences:**

- ✅ note — the slot policy is unchanged. The search is a round-robin from `_latest`, and the order of preference is empty > expired lower priority > unexpired lower priority (not the reserved slot) > expired equal priority. Overlap reservation and `_nextRepeat`/`_lastKey` repeat suppression are also unchanged. `_lastKey` is an `optional` that starts as nullopt, so it never matches, as `[key isEqualToString:nil]` didn't. With a null `UNIVERSE` the time is 0.0. `[OOSound soundWithCustomSoundKey:]` becomes `OOSoundWithCustomSoundKey`, which does the same lookup (`Core/Universe.cpp:1160` ↔ `Core/Universe.m:9946`). A null reserved source is guarded, as a nil `isPlaying` was. — upstream `Core/OOSoundSourcePool.m:55-247` ↔ port `Core/OOSoundSourcePool.cpp:49-187`
- ✅ note — the expiry defaults are unchanged: `0.5 + randf()*0.1` with one `randf` per call, and a fixed 0.5 for the overlap variants. — upstream `Core/OOSoundSourcePool.m:171,181,198,207` ↔ port `Core/OOSoundSourcePool.cpp:131,136,149,154`

