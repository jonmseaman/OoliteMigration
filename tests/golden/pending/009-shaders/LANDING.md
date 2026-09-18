# Landing scenario 009-shaders into `goldens/`

## Why this golden is not already in `goldens/`

`tools/guardrails.sh` treats `goldens/**` as a protected path and refuses ANY change there without
a matching line in `tools/rebless-approvals.txt`. It does **not** distinguish CREATE from MODIFY: a
brand-new `goldens/windows-x64/009-shaders/state.json` trips that guard exactly as an edit to an
existing golden would. Adding the approval line is Jon's call, not a worker's, so this bead stages
the artefacts **outside** the protected path and ships a procedure for moving them in.

## What is staged here

| file | what it is |
| --- | --- |
| `state.json` | the blessed dump: quantised world state plus the `evidence` block |
| `frame.grid` | 4096-byte 64x64 luminance grid of the blessed frame (`tests/golden/frame_hash.py`) |
| `frame.png` | the blessed frame itself, for a human to look at |
| `spec.json` | every determinism knob the run reads |
| `provenance.json` | how the golden was produced, the knobs it was blessed with, the renderer, and the two-arm frame differential |

## THE HEADLINE FINDING: shaders DO run here, and the fixture's shader DOES reach the driver

The bead's central risk was that the engine silently falls back to fixed function and the golden
tests nothing while staying green. It does not, and the evidence is the engine's and the GL
driver's own, verbatim from a blessing run's `Latest.log`:

    [rendering.opengl.version]: OpenGL renderer version: 4.6.0 ("4.6 (Compatibility Profile)
        Mesa 26.1.8"). Vendor: "Mesa". Renderer: "llvmpipe (LLVM 22.1.8, 256 bits)".
    [rendering.opengl.shader.support]: Shaders are supported.
    [shader.uniform.set]: Set up uniform <OOShaderUniform ...>{3: int uDiffuseMap = 0;}
    [shader.uniform.set]: Set up uniform <OOShaderUniform ...>{9: float uHullHeatLevel =
        [<ShipEntity ...> hullHeatLevel];}
      [shader.compile.failure]: ***** ERROR: GLSL fragment shader compilation failed for
        ahruman_shader_fallback_test.fragment:
    >>>>> GLSL log:
    0:4(2): error: illegal use of reserved word `this'
    0:4(2): error: syntax error, unexpected ERROR_TOK
    [shader.load.failed]: ***** ERROR: Could not build shader
        oolite-tangent-space-vertex.vertex/ahruman_shader_fallback_test.fragment.

The `[shader.uniform.set]` lines are the anti-vacuity anchor: OOShaderMaterial.m:327 is reached
only after `OK = (shaderProgram != nil)` at :236, i.e. only once `glCompileShaderARB` AND
`glLinkProgramARB` both returned GL_TRUE (OOShaderProgram.m:322/:337/:353, validated at :261-267).
A fixed-function run builds OOSingleTextureMaterial/OOBasicMaterial instead and emits none of them.

The GLSL log text is stronger still: `GetGLSLInfoLog` (OOShaderProgram.m:481) reads it back out of
the GL implementation with `glGetInfoLogARB`, so that wording is **Mesa's GLSL front end reporting
on bytes it was given by `glShaderSourceARB` (:335)**. Oolite cannot synthesise it. Its presence,
naming the expansion's own file, is proof the expansion's shader source reached the compiler.

Measured on the same box without the software override, for a future GPU-equipped run: the NVIDIA
path reports `4.6.0 ("4.6.0 NVIDIA 560.94"). Vendor: "NVIDIA Corporation". Renderer: "NVIDIA
GeForce RTX 4070 Ti/PCIe/SSE2"` and also `Shaders are supported.` This scenario is pinned to
llvmpipe anyway, because that is the rasteriser bead oo-ae9 measured the frame tolerance against
(`frame_hash.REQUIRED_GL_ENV`) and the harness forces it (`console.py:_env`). A tolerance measured
on one rasteriser says nothing about another.

### SCOPE, STATED PLAINLY

This golden covers: the GLSL path is live; real programs compile, link and bind uniforms; and the
expansion's shader file was read, preprocessed and compiled by the driver. It does **NOT** cover a
SUCCESSFUL OXP shader painting pixels, because the only shader test-OXP in this tree ships an
intentionally invalid shader (its own comment says so). `frame.png` shows the cube rendered SOLID
RED, which is the fixture's own documented "no shader in effect" outcome. A future fixture with a
valid shader would extend this scenario, not replace it.

## The two-arm frame differential

| arm | distance | vs tolerance 0.004377 |
| --- | --- | --- |
| same scene, two separate launches | 0.001382 | 0.32x (within) |
| OXP ABSENT vs OXP PRESENT | 0.111030 | **25.37x (beyond)** |

An 80-fold separation between noise and signal, and the answer falls the way it must: removing the
expansion moves the frame far past the tolerance, so the expansion's content demonstrably reached
the screen. The absent arm is corroborated independently by its own evidence block -
`shader_uniform_sets_positive=false`, `shader_compile_failures=[]`, `glsl_driver_log=[]`,
`oxp_standards_errors=0` - i.e. no shader was built at all and the expansion was never on the
search path. `frame_hash.TOLERANCE` was **not** adjusted; it is derived from bead oo-ae9's measured
populations in `tests/golden/calibration.json`.

## The missing `manifest.plist`, established by a real launch

    [oxp-standards.error]: OXP <staged>/Fallback test.oxp has no manifest.plist
    [oxp-standards.error]: OXP <staged>/Fallback test.oxp has no manifest.plist
    [searchPaths.dumpAll]: Resource paths:
        <staged>/Fallback test.oxp

Exactly two, and the path IS on searchPaths - bead oo-kcrw's NOMANIF class, by the mechanism bead
oo-dto proved at ResourceManager.m:636-664 (the `.oxp` branch emits OOStandardsError at :646 then
synthesises a basic manifest at :654-663; an `.oxz` would have returned at :640 and never loaded).
CHOICE: allow-list by EXACT message and EXACT count, no manifest staged - staging one would
fabricate content the fixture does not have. `--stage-double` proves the count predicate fires
(measured: 4 errors, refused).

## The procedure

Run from the repo root, on `main`, after this bead's branch has merged.

    git mv tests/golden/pending/009-shaders/state.json \
           goldens/windows-x64/009-shaders/state.json
    git mv tests/golden/pending/009-shaders/provenance.json \
           goldens/windows-x64/009-shaders/provenance.json
    git mv tests/golden/pending/009-shaders/frame.grid \
           goldens/windows-x64/009-shaders/frame.grid
    git mv tests/golden/pending/009-shaders/frame.png \
           goldens/windows-x64/009-shaders/frame.png
    git mv tests/golden/pending/009-shaders/spec.json \
           tests/golden/scenarios/009-shaders/spec.json

`LANDING.md` itself is deleted by the same commit.

**No code change is required.** The gate, the offline tests and the stability script each resolve
every artefact by searching `goldens/windows-x64/009-shaders/` FIRST and falling back to
`tests/golden/pending/009-shaders/`, so the move flips them over with nothing to edit - the same
shape scenarios 010 and 012 use.

Whoever lands it must add the approval line to `tools/rebless-approvals.txt` in the same commit -
that is the human decision the guard exists to force, and **a worker must never add it**.

## Verifying

    bash tools/guardrails.sh; echo "RC=$?"          # expect RC=0 with the approval line present
    python3 -m pytest tests/golden/test_shader_fallback.py -q
    python3 tests/golden/check_shader_evidence.py goldens/windows-x64/009-shaders/state.json \
        --spec tests/golden/scenarios/009-shaders/spec.json \
        --provenance goldens/windows-x64/009-shaders/provenance.json

## Re-blessing later

Re-run the scenario and overwrite `state.json`, `frame.grid`, `frame.png` and `provenance.json`
together. They are one observation: `provenance.json` records the seed, system, tick count and tick
length the dump was taken with, and `test_shader_fallback.py` asserts `spec.json` still agrees with
them AND that the dump agrees with provenance. That third witness is bead oo-3ya's finding applied:
a spec and a golden re-cut TOGETHER at a new seed move both sides of a fresh-run comparison and
would otherwise stay green.

Do **not** edit `frame_hash`'s tolerance to make a run pass. If the renderer genuinely changed,
re-measure with `tests/golden/calibrate.py` and re-bless.
