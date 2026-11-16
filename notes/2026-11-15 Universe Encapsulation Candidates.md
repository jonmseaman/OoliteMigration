# Universe encapsulation candidates (for later)

Status: **not planned**. Jon wants to consider these later (2026-11-15). `Universe.cpp` is 11,812
lines and `Universe.h` 1,055. The first extraction, espeak-ng, is already a task:
[speech-synthesizer-class.md](speech-synthesizer-class.md).

Counts are references to each cluster's members in `oolite-dev` (2026-11-15). Re-measure before
planning one.

| Candidate | `Universe.cpp` | Other `src/` | Tests | What it is |
|---|---:|---:|---:|---|
| **Post-processing framebuffer pipeline** | 78 | 0 | 0 | About 430 lines at `Universe.cpp:11327-11753`: `initTargetFramebufferWithViewSize`, `resizeTargetFramebufferWithViewSize`, `drawTargetTextureIntoDefaultFramebuffer`, `deleteOpenGLObjects` (and `prepareToRenderIntoDefaultFramebuffer`, `:5745`). About 12 GL members: `msaaTextureID`, `targetTextureID`, `passthroughTextureID[2]`, `targetFramebufferSize`, `msaaFramebufferID`, `msaaDepthBufferID`, `targetDepthBufferID`, `targetFramebufferID`, `passthroughFramebufferID`, `textureProgram`, `blurProgram`, `finalProgram`, `quadTextureVBO/VAO/EBO`. Pure OpenGL resource ownership with no game logic, so a natural `oo::PostProcessPipeline` that owns and frees its GL objects. **Easiest and most valuable.** |
| Entity ID registry | 11 | 0 | 0 | `entity_for_uid[MAX_ENTITY_UID]`, `next_universal_id`. A small `oo::EntityIdRegistry`. |
| System-name search | 11 | 0 | 4 | `system_names[256]`, `system_found[256]`. Tiny. |
| Demo and intro ship carousel | 56 | 0 | 1 | The title screen and ship library: `setupIntroFirstGo` (`:3731`), `setLibraryTextForDemoShip` (`:3843`), `selectIntro2Previous/Next/…Category` (`:4074-4096`), `removeDemoShips` (`:6071`), part of `reinitAndShowDemo` (`:10693`). Members `demo_stage`, `demo_stage_time`, `demo_start_time`, `demo_start_z`, `demo_ship_index`, `demo_ship_subindex`, `demo_ships`, `demo_ship`. Self-contained state, but it adds entities and drives the GUI. |
| Populator settings | 19 | 1 | 3 | `populatorSettings`, `next_repopulation`, `system_repopulator`, `deterministic_population`. |
| Message and comm-log state | 67 | 8 | 6 | `message_gui`, `comm_log_gui`, `currentMessage`, `messageRepeatTime`, `countdown_messageRepeatTime`, `_autoCommLog`, `_permanentCommLog`, `_autoMessageLogBg`, `_permanentMessageLog`. Touches the HUD and the player. |
| Lighting arrays | 60 | 17 | 9 | `stars_ambient`, `sun_diffuse`, `sun_specular`, `main_light_position`, `skyClearColor`, `ambientLightLevel`. Spread through drawing code; not easy. |
| Data tables loaded from plists | 36 | 133 | 23 | `customSounds`, `characters`, `_scenarios`, `globalSettings`, `missiontext`, `equipmentDataOutfitting`, `roleCategories`, `autoAIMap`, `screenBackgrounds`, `explosionSettings`. Mechanical, but a wide fan-out of accessors. |

To recount a row, run from `oolite-dev`:

```bash
grep -cE '<member regex>' src/Core/Universe.cpp
git grep -nE '<member regex>' -- src ':!src/Core/Universe.cpp' ':!src/Core/Universe.h' | wc -l
```

## Things to keep in mind

- **Upstream shape.** Class design stays close to upstream for merges (the old idiom review §2.1
  decision). So an extraction keeps `Universe`'s public methods as one-line forwarders, as the
  speech plan does. The cost is that an upstream change to a moved method body lands in the new
  class's file instead of `Universe.cpp`. That cost is smallest for the framebuffer code, which
  upstream rarely touches.
- **Test stand-ins.** Some tests stub `Universe` methods with their own stand-in `Universe` (for
  example `test_OOJSPlayer.cpp`), or reach into its members directly (`test_Universe.cpp`). Keep the
  public method names, and expect a ledgered test edit wherever a test writes a moved member.
- **Naming.** New classes go in `namespace oo` with no `OO` prefix (`oo::PostProcessPipeline` in
  `PostProcessPipeline.h`).
