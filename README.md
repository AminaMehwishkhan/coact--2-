# CoAct

**Two robots can see the same instruction differently. CoAct makes them agree before either one acts.**
And when the human corrects them mid-motion, it stops, re-grounds, and asks for consensus again.

CoAct is a pre-execution consensus layer for embodied agents. Two SO-ARM100 arms watch a shared
table from opposite sides, each grounds a spoken instruction **in its own camera image**, and
nothing is allowed to move until both independently localise the same physical object.

Across 90 randomised trials, a single-camera agent places the cup on the wrong object **30%** of
the time. CoAct brings that to **5.6%**, with every remaining failure in the one condition where a
plate is hidden from a camera — and one spoken correction then recovers task completion from 35.6%
to **67.8%**.

**[▶ Live demo](https://aminamehwishkhan.github.io/coact--1-/)** · the interactive gate, the
recorded episode, and the measured benchmark — no install.

---

## The problem

A language-grounding mistake in software returns a wrong answer. A language-grounding mistake in
robotics produces a wrong *physical action*.

Put two plates on a table and two arms on opposite sides of it:

> "Put the cup on the plate on the left."

Agent A's camera is west of the table; Agent B's is east. Both resolve "left" **correctly** in
their own image frame — and they resolve it to *different plates*. Neither is wrong. The
instruction has no viewpoint-independent referent.

![The same table from both agents' cameras](results/agent_views.png)

*The two agents' own camera frames, with detections drawn. Left: Agent A sees the large plate on
its left. Right: Agent B sees the small plate on its left. Same world, opposite answers — and this
is measured from pixels, not scripted.*

Almost every voice-to-robot demo picks one interpretation and moves.

## The solution

```
OBSERVE → INDEPENDENT GROUNDING → COMPARE → CONSENSUS GATE → CONFIRM → EXECUTE
```

and when the viewpoints disagree:

```
OBSERVE → DISAGREE → BLOCK EXECUTION → HOVER CONFIRMATION → HUMAN CORRECTION
       → RE-GROUND → RE-CHECK CONSENSUS → EXECUTE
```

Each agent renders its own camera, detects objects in that image, and grounds the instruction
egocentrically. The consensus engine then asks one question: did both agents land on the same point
on the table? Agreement is decided geometrically — each agent back-projects its chosen target onto
the table plane through its own known camera pose, and they agree when the two estimates fall
within 5 cm of each other. On this rig back-projection error measures about 1 cm and the candidate
objects sit about 18 cm apart, so the tolerance clears the noise and the signal by more than an
order of magnitude on each side.

While the gate is shut the arm may still **approach** the candidate — hover confirmation, jaw open —
so the human can see what it is about to do and say no. It may not descend, close, or place.

### Why consensus, and not just a confidence threshold

A confidence threshold tells you when a model is *unsure*. It cannot tell you when a model is
*confidently wrong*, and confidently wrong is the dangerous case. Two situations on this rig
produce it, both of them ordinary:

- **Occlusion.** A tall object the detector has no class for parks between one camera and one
  plate. That camera now sees a single candidate, wins by a wide margin, and reports *high*
  confidence. The agent is not uncertain; it is uninformed.
- **Depth skew.** A small plate close to a camera projects larger than a big plate far from it. The
  agent is confidently sure which one is "the large plate", and confidently wrong.

Disagreement between embodied viewpoints detects both. The benchmark measures exactly this.

---

## Results

90 randomised trials, seed 7, three conditions in equal proportion, half the instructions
attribute-based ("the large plate") and half viewpoint-dependent ("the plate on the left"):

- **clean** — two plates, both visible to both cameras.
- **depth_skew** — the physically small plate sits close to one camera and the large one far from
  it, so apparent size contradicts real size for that agent.
- **occluded** — a tall opaque object the detector has no class for stands on the line between one
  camera and one plate, so that camera cannot see it at all.

Reproduce with:

```bash
python -m coact.benchmark --trials 90 --sizing both --out results/benchmark.json
```

Every trial runs the full pipeline: render two cameras → detect → back-project → ground → compare.
Ground truth is used only for scoring; the agents never see it.

| System | Correct commit | **Unsafe commit** | Blocked |
|---|---|---|---|
| Single agent, no gate | 56.7% | **30.0%** | 13.3% |
| Confidence gate (τ=0.961, matched to CoAct's block rate) | 38.9% | **5.6%** | 55.6% |
| CoAct consensus gate | 35.6% | **5.6%** | 58.9% |
| **CoAct + one spoken correction** | **67.8%** | **5.6%** | 26.7% |

An *unsafe commit* is the system physically placing the cup on an object the speaker did not mean.
A *block* is safe but unhelpful — and, as the last row shows, often recoverable by asking. The
single agent blocks 13.3% of the time because it too refuses when nothing in its view matches the
instruction; scoring those as commits would have inflated the baseline in CoAct's favour.

Unsafe commits by condition:

| Condition | Single agent | CoAct |
|---|---|---|
| clean | 30.0% | **0.0%** |
| depth_skew | 33.3% | **0.0%** |
| occluded | 66.7% | 16.7% |

**Where both agents can see the referent, the gate lets nothing wrong through.** Every one of
CoAct's five remaining failures is an occluded trial where one camera cannot see the intended plate
and both agents settle on the same visible alternative. Two viewpoints detect a *conflict*; they
cannot conjure information neither of them has. That is the honest boundary of the method.

CoAct also never blocked a clean unambiguous instruction: ambiguity-detection precision 1.00,
recall 0.82, F1 0.90.

### Does a confidence threshold do the same job?

Not quite, and the difference is instructive.

- **It has to be tuned on labelled data.** The threshold's unsafe rate falls smoothly from 30% to
  0% as τ goes from 0.806 to 0.982; τ=0.961 is only identifiable because we already know the right
  answers. CoAct's gate has no such knob — agreement is geometric.
- **It reaches 0% only by refusing more.** τ=0.982 gets to zero unsafe commits at a 63.3% block
  rate and 36.7% task completion, worse on both axes than CoAct plus a correction.
- **It cannot say what is wrong.** A threshold reports "unsure". CoAct reports *why*: perspective,
  attribute, object, or no-target. That diagnosis is what makes the spoken correction targeted —
  78.4% of perspective blocks are repaired by one utterance.

### Ablation: can better perception replace the gate?

Partly, and the boundary is the interesting part. Agents can judge size from pixel area
(viewpoint-dependent) or by back-projecting the object's silhouette onto the table to get a radius
in metres (viewpoint-independent, accurate to ~1 mm here).

| | Apparent-size sizing | Metric sizing |
|---|---|---|
| CoAct block rate | 72.2% | **58.9%** |
| Perspective blocks repaired by one correction | 43.2% | **78.4%** |
| CoAct unsafe commits | 5.6% | 5.6% |

Better perception buys back a lot of availability and makes corrections land. It does not reduce
unsafe commits, and it does not touch the *perspective* disagreements at all — 37 of them either
way. It cannot: "left" is not a property of the world. That residue is irreducible by sensing. It
can only be caught by a second viewpoint noticing the conflict, and resolved by a human. That is
the claim this project exists to support.

### Watch it happen

`results/coact_demo.mp4` — the full arc with the gate state burned into the frame: disagreement,
blocked execution, hover confirmation, spoken correction, re-grounding, consensus restored, commit.

---

## Architecture

```
  cam_A ──► detect ──► back-project ──► ground(image frame A) ─┐
                                                               ├─► consensus gate ──► state machine ──► motion
  cam_B ──► detect ──► back-project ──► ground(image frame B) ─┘        │                   ▲
                                                                        │                   │
                                                        diagnosis ──────┘    Speechmatics correction
```

| Module | Responsibility |
|---|---|
| `coact/world.py` | Generates the MJCF dinner-table scene; randomisable for the benchmark |
| `coact/mj_runtime.py` | MuJoCo physics, kinematic IK, `hover` vs `commit`, camera rendering |
| `coact/perception.py` | Per-camera detection, back-projection, metric sizing |
| `coact/agent.py` | One camera + one arm + one opinion; egocentric grounding |
| `coact/ov_backend.py` | Compiles the scoring kernel as an OpenVINO model and runs it |
| `coact/consensus.py` | Compares two interpretations; diagnoses the disagreement |
| `coact/state_machine.py` | Explicit safety states and the execution invariant |
| `coact/pipeline.py` | Session orchestration and the event timeline |
| `coact/benchmark.py` | Randomised trials, baselines, ablation |
| `coact/speech.py` | Speechmatics RT token minting; labelled demo fallback |
| `coact/server.py` | FastAPI backend, live camera frames, dashboard |

### The safety invariant

`EXECUTING` is not in `DISAGREEMENT`'s transition set — it is structurally unreachable, not merely
guarded. Every transition into `EXECUTING` additionally requires:

```
consensus == True AND (confirmation_required == False OR confirmation_completed == True)
```

Violations raise `SafetyViolation` and the transition does not happen. Eight tests cover this
directly, including forcing the consensus flag by hand while in `DISAGREEMENT`.

### Simulation

Real MuJoCo physics with two **SO-ARM100** arms, vendored from
[MuJoCo Menagerie](https://github.com/google-deepmind/mujoco_menagerie) (`trs_so_arm100`,
Apache-2.0, see `assets/so_arm100/LICENSE`). Targets are reached by damped-least-squares IK solved
kinematically on a scratch state and then tracked by the position controllers; final gripper error
on a place is about 2 mm.

Two implementation notes, both honest rather than cosmetic: the arm links are recoloured graphite
at load time because the stock white plastic is the same colour as the plates and merges with them
under colour segmentation — the alternative is a detector that works only because it was told where
the robot is. And MuJoCo's gravity compensation is enabled on the arm links, which models a servo
holding its own weight rather than inflating torque limits past what the hardware can do.

### OpenVINO

Grounding reduces to scoring candidates against a query vector — a matmul. CoAct builds that matmul
with `openvino.opset13`, compiles it through `ov.Core()`, and runs every grounding call through the
OpenVINO runtime. `/api/health` reports the OpenVINO version, the device `AUTO` actually resolved
to, and a latency measured with `perf_counter` around a real inference call.

**Measured on an x86 cloud CPU**: OpenVINO 2026.4, `AUTO → CPU`, 0.1–1.3 ms per grounding call. The
architecture targets Intel Core Ultra and will report `GPU`/`NPU` if OpenVINO resolves to them, but
**no Core Ultra or NPU benchmark has been run and none is claimed**. Without OpenVINO the identical
maths runs in NumPy and the UI reads `NumPy (CPU fallback)`.

### Speechmatics

- **LIVE SPEECHMATICS** — with `SPEECHMATICS_API_KEY` set, `POST /api/speechmatics/token` exchanges
  the long-lived key for a short-lived real-time JWT server-side and returns only that to the
  browser, which opens a WebSocket to the Speechmatics RT endpoint. The long-lived key never
  reaches the client and is not in the repository.
- **DEMO REPLAY** — no key, or no microphone. A fixed correction utterance is pushed through **the
  same `Session.correct()` pipeline** as live speech, and the badge says `DEMO REPLAY`. Simulated
  audio is never presented as live API output.

---

## Demo scenarios

| # | Instruction | What happens |
|---|---|---|
| 1 | *Place the red cup on the large plate.* | Both agents localise the same plate to within 0.5 cm → ✓ CONSENSUS → execute |
| 2 | *Put the cup on the plate on the left.* | A → u=−0.24, B → u=−0.23, targets 18 cm apart → ⚠ DISAGREEMENT (perspective) → gate locked → hover |
| 3 | *No, the large plate.* | Correction interrupts the hover, retires the spatial constraint, both re-ground → ✓ CONSENSUS RESTORED → execute |

---

## Installation

```bash
python -m venv .venv
source .venv/bin/activate            # Windows: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
cp .env.example .env                 # optional; runs fine without it
pytest -q
uvicorn coact.server:app --port 8000
```

Open <http://localhost:8000>. Headless Linux needs `MUJOCO_GL=egl`, which the package sets for
itself on import.

Reproduce the figures and numbers:

```bash
python -m coact.benchmark --trials 90 --sizing both --out results/benchmark.json
python scripts/record_demo.py --out results
```

## Environment variables

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `SPEECHMATICS_API_KEY` | no | *(unset)* | Enables LIVE SPEECHMATICS; otherwise DEMO REPLAY |
| `SPEECHMATICS_RT_URL` | no | `wss://eu2.rt.speechmatics.com/v2` | Speechmatics RT endpoint |
| `COACT_OV_DEVICE` | no | `AUTO` | OpenVINO device hint (`AUTO`/`CPU`/`GPU`/`NPU`) |
| `MUJOCO_GL` | no | `egl` | GL backend; `egl` for headless |
| `COACT_FORCE_NULL_RUNTIME` | no | *(unset)* | `1` disables physics, for testing the degraded path |
| `PORT` | no | `8000` | Server port |

No secrets are committed; `.env` is gitignored.

## Tests

```bash
pytest -q        # 39 tests
```

Covering the safety invariant (8), back-projection and metric sizing against ground truth, the
mirrored-viewpoint property, the consensus engine's four verdicts, full episodes on real physics,
reset/repeat hygiene, a short benchmark run as a regression guard, and every fallback path.

The benchmark regression test asserts that CoAct makes *fewer* unsafe commits than a single agent
and *zero* when nothing is occluded — not that it makes zero overall, which the 90-trial run shows
is not true.

## Deployment

There are two things worth hosting, and they have different requirements.

**The dashboard, as a static page.** `docs/` holds a self-contained copy — the page, the
two-camera figure and the recorded episode. GitHub Pages serves it from there with no build step
and no backend: the gate logic runs in the browser against a geometric model of the same table,
and the page says so. This is what the live demo link above points at.

**The full system, with live cameras.** This needs MuJoCo rendering through EGL, so it has to be a
container — a plain Python buildpack has no way to install the GL libraries. The `Dockerfile`
handles it, defaults to port 7860 for Hugging Face Spaces, and honours `$PORT` for Render, Fly or
Cloud Run. It also renders one frame at build time and fails the build if EGL comes back blank,
rather than shipping an image that quietly serves the no-physics fallback.
`deploy/README-huggingface.md` is the Space front matter.

`render.yaml` and `Procfile` remain for a non-Docker deploy; that path runs without physics and the
dashboard reports it. Health check is `GET /api/health`, which states plainly which services are
actually connected.

---

## Limitations

Stated plainly, because a reviewer will find them anyway.

- **Grounding is a deterministic spatial grounder, not a VLM.** Deliberate: it makes the
  disagreement reproducible on stage and testable in CI, and it keeps the contribution on the gate.
  Swapping in a per-agent VLM means replacing `Agent.ground()` and nothing else — the gate does not
  care where an interpretation came from.
- **Detection is classical CV**, not a learned detector. It finds plates and cups reliably on this
  rig and would not transfer to a cluttered real kitchen.
- **Cups are frequently occluded** by the agent's own arm, so the demo's manipulable object is
  chosen by colour from the instruction rather than re-detected every frame.
- **No Intel Core Ultra or NPU benchmark has been run.** CPU numbers only, as measured.
- **Live Speechmatics is implemented but has not been exercised against a real key.** The
  token-minting path returns a readable reason on failure and the UI falls back to DEMO REPLAY.
- **Two agents, not N.** With two viewpoints a disagreement can be detected but not adjudicated,
  which is why the human is in the loop.
- **Consensus cannot recover information no camera has.** When a plate is hidden from one camera
  and both agents settle on the same visible alternative, the gate opens on the wrong object. This
  is 5 of 90 trials, all in the occluded condition, and naming the plate in a correction does not
  help — the agent still cannot see it. A third viewpoint or a camera that can move is the fix.
- **Benchmark layouts are reachable for perception but not always for manipulation** under extreme
  depth skew; the benchmark scores grounding and gating, not reach.

## Future work

- Per-agent VLM grounding with the gate unchanged, to test whether the same disagreement structure
  survives learned perception
- A third viewpoint, so perspective disagreements can be adjudicated by majority instead of always
  escalating to the human
- Viewpoint-anchored corrections ("the one nearer you"), and an agent that can say "I cannot see
  what you mean" out loud — which is what the residual blocked and occluded episodes actually need
- Re-evaluating the gate *during* motion rather than only before it
- Learning which phrasings historically produce disagreement, and asking before moving

## Where this matters

Collaborative manufacturing, warehouse picking, healthcare and assistive robotics, home robotics —
anywhere a human gives an ambiguous spoken instruction to a machine that can exert force. The
measured result transfers even if the rig does not: a second viewpoint catches a class of
confidently-wrong grounding that no single-agent confidence threshold can.

## Credits

SO-ARM100 model from [MuJoCo Menagerie](https://github.com/google-deepmind/mujoco_menagerie)
(`trs_so_arm100`), derived from [The Robot Studio](https://github.com/TheRobotStudio/SO-ARM100)'s
open-source arm. Apache-2.0; licence retained at `assets/so_arm100/LICENSE`.
