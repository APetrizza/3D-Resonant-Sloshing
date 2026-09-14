# 3D Resonant Sloshing in an Upright Cylindrical Tank

![OpenFOAM](https://img.shields.io/badge/OpenFOAM-v2412-blue.svg)
![Python](https://img.shields.io/badge/Python-3.x-yellow.svg)
![MATLAB](https://img.shields.io/badge/MATLAB-DSP_Engine-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

This repository contains a high-fidelity 3D Computational Fluid Dynamics (CFD) parametric campaign investigating non-linear liquid sloshing in an upright cylindrical tank.

The project is designed as a comprehensive benchmark based on analytical potential flow theory (*Raynovskyy & Timokha, 2021; Faltinsen & Timokha, 2009*). It explores the full stability diagram of the fluid system, covering broadband modal identification, planar waves, amplitude modulation (beating), steady rotary swirling, wave breaking, shallow-water soft-spring regimes, and free-decay damping estimation.

---

## Table of Contents

- [Theoretical Background](#theoretical-background)
- [Numerical Methodology](#numerical-methodology)
- [Prerequisites](#prerequisites)
- [Installation & Compilation](#installation--compilation)
- [Campaign Overview (The 8 Cases)](#campaign-overview-the-8-cases)
- [Execution Workflow](#execution-workflow)
- [Repository Structure & .gitignore](#repository-structure--gitignore)
- [Case Details](#case-details)
- [Known Issues & Fixes](#known-issues--fixes)
- [Contributing](#contributing)
- [License](#license)

---

## Theoretical Background

Liquid sloshing in partially filled satellite propellant tanks and transport vessels represents a classic hybrid mechanical system. When a cylindrical container undergoes horizontal oscillation near its fundamental natural frequency $\sigma_{11}$, the free surface dynamics exhibit strongly non-linear behavior driven by energy transfer between orthogonal Fourier harmonics.

Depending on the forcing frequency $\omega$, the excitation amplitude $a_0$, and the filling ratio $h/R_0$, the system can manifest:

- **Planar Standing Waves**: Linear response parallel to the excitation axis.
- **Amplitude Modulation (Beating)**: Planar instability where energy bounces periodically between the longitudinal and transverse axes.
- **Steady Rotary Swirling**: Stable, continuous wave rotation around the vertical axis.
- **Wave Breaking**: Highly dissipative, chaotic response at full resonance.
- **Shallow-Water Soft-Spring Bores**: Traveling hydraulic jumps replacing smooth harmonic waves at low filling ratios.

---

## Numerical Methodology

The simulation utilizes state-of-the-art CFD techniques to prevent numerical dissipation, which is the primary cause of failure in sloshing simulations.

- **Solver**: `interIsoFoam` (OpenFOAM-v2412) featuring the **isoAdvector** geometric VOF method for ultra-sharp interface capturing.
- **Mesh Topology**: A pure hexahedral **O-Grid** generated via `blockMesh` to guarantee extreme orthogonality and eliminate central-axis singularities.
- **Adaptive Mesh Refinement (AMR)**: Dynamic refinement (`dynamicRefineFvMesh`) focused solely on the free surface ($0.01 < \alpha < 0.99$).
- **Forcing Strategy**: The harmonic (or swept/chirp) tank motion is implemented in a non-inertial reference frame via the C++ `tabulatedAccelerationSource` module, injecting a fictitious time-dependent gravity field.

---

## Prerequisites

To execute the pipeline and the post-processing engine, the following stack is required:

- OpenFOAM v2412 (natively installed, **or** via the Docker-based workflow described below)
- Python 3.6+ with `numpy` (for acceleration table generation)
- MATLAB R2021a+ or GNU Octave (for Advanced DSP post-processing)
- A batch scheduler (Slurm, PBS, etc.) if running on a shared HPC cluster — **not required otherwise**. This repository does not ship scheduler submission scripts (see [Execution Workflow](#execution-workflow)); if you're on a cluster, wrap `./Allrun` in whatever your site uses.

---

## Installation & Compilation

Clone the repository and assign execution permissions to the core automation scripts:

```bash
git clone https://github.com/APetrizza/3D-Resonant-Sloshing.git
cd 3D-Resonant-Sloshing
chmod +x */Allrun */TabulaRasa
```

Each subcase contains its own execution scripts (`Allrun`, `TabulaRasa`, `generate_acceleration.py`). Batch-scheduler submission scripts (`launch.slurm`, `Errata.slurm`) are **not** included — see [Execution Workflow](#execution-workflow).

---

## Campaign Overview (The 8 Cases)

This repository is divided into 8 distinct physical regimes / diagnostics. The base geometry is $R_0 = 0.15\text{ m}$. For Cases 0–4, 6 and 7, the liquid depth is $h = 0.225\text{ m}$ (Hard-Spring regime, $f_{11} = 1.7393\text{ Hz}$). Case 5 explores the Soft-Spring regime with $h = 0.05\text{ m}$ ($f_{11} \approx 1.29\text{ Hz}$).

| Case Directory | Physical Regime | $\omega / \sigma_{11}$ | $a_0 / g$ | Key Feature |
| :--- | :--- | :---: | :---: | :--- |
| `Case0_Chirp/` | Broadband Modal ID | 0.5–3.5 Hz sweep | 0.001 | Linear chirp, FRF & coherence identification of $f_{11}$. |
| `Case1_Planar_Wave/` | Stable Planar Wave | 0.95 | 0.002 | Linear boundary. Flat $F_y$ force. |
| `Case2_Amplitude_Modulation/` | Beating / Instability | 1.02 | 0.010 | Butterfly hodograph. Energy transfer. |
| `Case3_Steady_Swirling/` | Rotary Swirling | 1.04 | 0.015 | Circular orbit. Y-axis numerical trigger. |
| `Case4_Violent_Sloshing/` | Wave Breaking | 1.00 | 0.050 | High dissipation. Broadband STFT. |
| `Case5_Soft_Spring/` | Shallow Water (🔄 rerun in progress) | 0.98 | 0.020 | Traveling waves. Bores/hydraulic jumps. Numerics still being tuned — see Known Issues. |
| `Case6_Free_Decay/` | Damping Estimation (⚠️ superseded) | 0.95 | 0.005 | Shut-off test at $t=10$ s — contaminated by near-resonance beating, kept for the record. |
| `Case7_Free_Decay_OffResonance/` | Damping Estimation (✅ reference) | 0.80 | 0.005 | Detuned shut-off test + ramp-up. Clean decay, $\xi\approx1.7\%$. |

---

## Execution Workflow

Every case follows the same three-step pattern (generate forcing → run → post-process), but **how** you run step 2 depends on where you're working. Read the section that matches your setup.

### A) HPC cluster with Slurm (the primary workflow used for this campaign)

**Note:** this repository does not track scheduler submission scripts (`launch.slurm`, `Errata.slurm`) — they're site-specific (queue names, node exclusions, account strings) and not portable to your cluster. Write your own wrapper around `./Allrun`; the campaign's own `launch.slurm` used here, as a reference, was a Slurm batch script (`#SBATCH --ntasks=32 --exclusive`, plus node exclusions specific to this cluster) that called `./Allrun`, waited for it to finish, checked the log for a clean `End` at the expected `endTime`, then reconstructed the mesh/fields and extracted `FORCES/` (see the extraction commands under [Post-Processing](#post-processing-all-cases) below). If the check failed, `processor*/` was deliberately **not** deleted, so the raw parallel run could still be inspected.

```bash
cd Case3_Steady_Swirling/
python3 generate_acceleration.py
sbatch your_submission_script.slurm   # your own wrapper around ./Allrun
```

### B) Local workstation (no Slurm)

If you have OpenFOAM v2412 available directly (no batch scheduler), skip `launch.slurm` and just run the case scripts yourself:

```bash
cd Case3_Steady_Swirling/
python3 generate_acceleration.py
./TabulaRasa   # clean any previous run first — see the note below
./Allrun
```

### The `openfoam-docker` wrapper — why it's there and what it changes

Every OpenFOAM command inside `Allrun` is prefixed with `openfoam-docker`, e.g. `openfoam-docker / blockMesh`, `openfoam-docker / mpirun -np 32 interIsoFoam -parallel`. This is a thin wrapper (available on the HPC node this campaign runs on) that executes the given command **inside a Docker container**, mounting the current working directory into the container at `/home/openfoam` — this is why OpenFOAM's own log header shows `Case : /home/openfoam` rather than the real host path.

This matters for two reasons:

1. **If you don't have `openfoam-docker` available** (e.g. a plain workstation with OpenFOAM compiled natively), either provide your own no-op script named `openfoam-docker` on your `PATH` that just execs its arguments directly, or strip the `openfoam-docker /` prefix from `Allrun` before running it locally.
2. **Every command runs in a fresh, isolated container invocation.** This is relevant when interpreting logs (each `postProcess`/`interIsoFoam` call gets its own `Host`/`PID` in the log header — that's normal, not evidence of anything going wrong) and when debugging: a container only sees whatever is mounted (the case directory), so paths like `/home/openfoam` in error messages refer to your case root, not a broken mount.

### `TabulaRasa` — always run it before rerunning a case

`TabulaRasa` resets a case directory to its pristine pre-run state (removes `0/`, `processor*`, the regenerated part of `constant/polyMesh`, reconstructed time directories, logs, `FORCES/`, and `constant/acceleration.dat`). **It also removes `postProcessing/`** — this was a real bug found and fixed during this campaign (see [Known Issues & Fixes](#known-issues--fixes)): without it, `Allrun`'s `cat postProcessing/wallForces/*/force*.dat` silently re-concatenates stale data from a much earlier run alongside genuinely new data, even after every dictionary has been corrected.

Because `controlDict` uses `startFrom latestTime`, relaunching **without** `TabulaRasa` on a case that already reached its `endTime` is a no-op — OpenFOAM sees it's already done and recomputes nothing. Only skip `TabulaRasa` deliberately if you are extending `endTime` to continue a run that didn't finish yet.

### How `FORCES/` is built, and re-extracting it without rerunning the solver

`FORCES/` is never OpenFOAM's raw output — it's a merged, flattened copy of the per-timestep function-object data under `postProcessing/`, built with these four commands (this is what `Allrun` runs at the end of every normal solve, and it's also all you need if only the extraction needs redoing):

```bash
rm -rf postProcessing
openfoam-docker / postProcess -func wallForces -time '0:80'   # use the case's actual end time
openfoam-docker / postProcess -func waveProbes -time '0:80'

rm -rf FORCES
mkdir -p FORCES
cat $(ls -v postProcessing/wallForces/*/force*.dat 2>/dev/null) > FORCES/force.dat
cat $(ls -v postProcessing/wallForces/*/moment*.dat 2>/dev/null) > FORCES/moment.dat
cat $(ls -v postProcessing/waveProbes/*/alpha.water* 2>/dev/null) > FORCES/alpha.water
cat $(ls -v postProcessing/waveProbes/*/p_rgh* 2>/dev/null) > FORCES/p_rgh
```

Re-run just these four `cat`s (without rerunning the solver) any time only the post-processing extraction needs redoing — for example after fixing the `TabulaRasa`/`postProcessing` bug above, on a case whose solver run is already correct. On our cluster this was wrapped in a small `Errata.slurm` helper per case (not tracked in this repo — site-specific, same reasoning as `launch.slurm` above); reproduce it locally or in your own scheduler script as needed. **Important**: `postProcess -time ':'` (bare colon, meaning "all times") is silently rejected by this OpenFOAM build (`Bad scalar-range parsing`) and falls back to processing nothing — always give an explicit bounded range like `'0:80'` or `'0:40'`.

### Post-Processing (all cases)

Once a job finishes, run the DSP engine from **inside the case directory**:

```matlab
process_sloshing_data
```

`process_sloshing_data.m` (at the repository root) auto-detects which case it's running in by folder name and switches on the relevant extra analysis: `Chirp` → frequency-response/coherence estimation (`fig8`); `Free_Decay` → logarithmic-decrement damping estimation (`fig7`); anything else → the standard 6 figures (wave probes, force/moment orbits, FFT, spectrogram, filter comparison).

---

## Repository Structure & .gitignore

Figures (`*.png`) and the merged `FORCES/` data are tracked in version control — they're small, and they're the actual validated results this campaign is built to produce. What's excluded is everything large/regenerable:

```gitignore
# OpenFOAM generated directories (regenerated by Allrun/blockMesh)
[0-9]*
!0.orig
!0.orig/**
processor*
postProcessing/
dynamicCode/

# OpenFOAM generated files
log.*
*.foam
*.eMesh
*.obj
*.log

# Regenerated by generate_acceleration.py — don't version, just rerun the script
constant/acceleration.dat
constant/chirp_f_inst.csv

# Site-specific batch-scheduler scripts (Slurm/PBS/etc.) — not portable across
# clusters, kept locally only. Adapt Allrun to your own scheduler.
*.slurm

# System files
.DS_Store
Thumbs.db
```

---

## Case Details

### Case 0: Broadband Chirp Modal Identification

**Objective**

Identify the tank's fundamental sloshing natural frequency $f_{11}$ and the shape of its frequency-response function $H(f)=F_x(f)/a(f)$ directly from CFD, using one broadband linear frequency sweep instead of many separate constant-frequency runs.

**Forcing Parameters**

- Linear chirp, 0.5 Hz → 3.5 Hz over 80 s (0.0375 Hz/s), Tukey-tapered 5% at each end
- Forcing Amplitude ($a_0$): $0.001\cdot g$ — kept small to stay linear across the whole sweep, including at resonance

**Results**

Resonance identified at $f\approx1.6$–1.7 Hz ($|H|_{\max}\approx39\ \text{N/(m/s}^2)$), in good agreement with the analytical $f_{11}=1.7393$ Hz. Coherence drops below the 0.9 reliability threshold right at the peak (≈1.4–2.1 Hz) — the sweep rate is fast relative to the resonance's settling time ($\tau\approx5.4$ s from Case7's damping estimate), a known limitation of swept-sine FRF testing, not a data-quality bug. See `Case0_Chirp/README.md` for the full writeup, including the debugging history (this case is where the campaign-wide Courant/AMR and `postProcessing` bugs were first found — see [Known Issues & Fixes](#known-issues--fixes)).

### Case 1: Stable Planar Standing Wave

**Objective**

The objective of this subcase is to validate the linear boundary of the theoretical stability diagram. By operating safely away from the primary resonance peak, the fluid is expected to behave linearly without triggering transverse instabilities.

**Forcing Parameters**

- Frequency Ratio ($\omega / \sigma_{11}$): 0.95
- Base Frequency ($f_{11}$): $1.7393\text{ Hz}$
- Forcing Amplitude ($a_0$): $0.002 \cdot g$ ($0.01962\text{ m/s}^2$)

**Expected Phenomenology**

The liquid responds with a clean standing wave oscillating strictly parallel to the X-axis (the axis of excitation).

- The transverse force ($F_y$) remains flat at zero.
- The hodograph ($F_y$ vs $F_x$) is a straight horizontal line.
- The FFT spectrum shows two close peaks (forcing frequency + residual natural-frequency transient) producing a slow linear beat (~11 s period), rather than a single sharp line — see `Case1_Planar_Wave/README.md`.

### Case 2: Amplitude Modulation (Beating / Planar Instability)

**Objective**

This case captures one of the most challenging phenomena in fluid dynamics: the quasi-periodic energy transfer between orthogonal modes. It demonstrates the transition zone where the planar wave is fundamentally unstable, but the steady swirling lacks the energy to self-sustain.

**Forcing Parameters**

- Frequency Ratio ($\omega / \sigma_{11}$): 1.02
- Base Frequency ($f_{11}$): $1.7393\text{ Hz}$
- Forcing Amplitude ($a_0$): $0.010 \cdot g$ ($0.0981\text{ m/s}^2$)

**Expected Phenomenology**

The liquid attempts to rotate, moving energy into the transverse Y-axis. However, the orbit collapses, and the energy returns to the X-axis in a continuous cycle.

- **Wave Probes**: The signals display classic beating (amplitude modulation envelopes).
- **Hodograph**: The phase-space trajectory forms a chaotic "butterfly" or complex Lissajous figure, never settling into a limit cycle.
- **STFT Spectrogram**: The time-frequency analysis reveals periodic "pulsations" of kinetic energy, proving the temporal energy shift between axes.

### Case 3: Steady Rotary Swirling

**Objective**

To simulate the perfect non-linear limit cycle where the liquid detaches from the excitation axis and continuously rotates along the cylindrical walls. This case is crucial for spacecraft engineering, as steady swirling generates severe centrifugal forces and constant angular momentum.

**Forcing Parameters**

- Frequency Ratio ($\omega / \sigma_{11}$): 1.04
- Base Frequency ($f_{11}$): $1.7393\text{ Hz}$
- Forcing Amplitude ($a_0$): $0.015 \cdot g$ ($0.14715\text{ m/s}^2$)

> ⚠️ **CFD Note (The Y-Trigger):** OpenFOAM matrices are perfectly symmetric. Relying on CPU round-off errors to break symmetry and initiate swirling can take excessive simulated time. To accelerate convergence to the physical state, `generate_acceleration.py` injects a small, fading transverse acceleration on the Y-axis (1% of $a_0$) during the first $2\text{ s}$ of the simulation.

**Expected Phenomenology**

- **Phase Shift**: The X and Y wave probes lock into a perfect $90°$ phase shift.
- **Hodograph**: The $F_y$ vs $F_x$ plot transitions from an initial chaotic tangle into a clean, stable circle/ellipse.
- **Moments**: A constant, non-zero rolling and pitching moment is established due to the rotating mass of the fluid.

### Case 4: Violent Chaotic Sloshing & Wave Breaking

**Objective**

To push the `interIsoFoam` solver to its limits by operating at exact resonance with a large amplitude. This case studies the highly dissipative nature of wave breaking, air entrapment, and free-surface fragmentation.

**Forcing Parameters**

- Frequency Ratio ($\omega / \sigma_{11}$): 1.00
- Base Frequency ($f_{11}$): $1.7393\text{ Hz}$
- Forcing Amplitude ($a_0$): $0.050 \cdot g$ ($0.4905\text{ m/s}^2$)

**Expected Phenomenology**

- **Non-Linear Damping**: Due to wave breaking, the maximum force peaks may paradoxically be lower or highly erratic compared to Case 3, showcasing severe non-linear energy dissipation.
- **Harmonics**: The FFT spectrum will show distinct secondary and tertiary peaks at $2\omega$ and $3\omega$, caused by the steepening of the wave crests and flattening of the troughs.
- **Interface**: Visual post-processing in ParaView will reveal bubbles and droplets separating from the main fluid bulk.

### Case 5: Shallow Water / Soft-Spring Regime

**Objective**

To demonstrate the shift in non-linear physics when the tank geometry is altered. For $h/R_0 < 1.05$, the system shifts from a Hard-Spring to a Soft-Spring behavior. The resonance curve bends towards lower frequencies, and the wave nature shifts from harmonic standing waves to traveling bores.

**Forcing Parameters**

- Tank Radius ($R_0$): $0.15\text{ m}$
- Liquid Filling Height ($h$): $0.05\text{ m}$ ($h/R_0 \approx 0.333$)
- Base Frequency ($f_{11}$): $1.291\text{ Hz}$ (recalculated for shallow depth)
- Frequency Ratio ($\omega / \sigma_{11}$): 0.98 (resonance shifted left)
- Forcing Amplitude ($a_0$): $0.020 \cdot g$ ($0.1962\text{ m/s}^2$)

**Expected Phenomenology**

- The fluid no longer behaves as a smooth sinusoidal wave. Hydraulic jumps and traveling bores sweep across the shallow bottom.
- The force history becomes highly skewed and impulsive, rather than harmonic.

**🔄 Status: rerun in progress.** This is the most numerically demanding case in the campaign — see [Known Issues & Fixes](#known-issues--fixes) for the AMR-thrashing issue found here. Currently relaunched with `maxRefinement 1→2` and `refineInterval 5→3` (`nBufferLayers=3`, `maxCo=0.2` unchanged); figures and results below will be updated once it completes and is validated.

### Case 6: Free Decay & Viscous Damping Estimation ⚠️ superseded by Case 7

**Objective**

To calculate the total numerical damping ratio ($\xi$) of the CFD setup. This damping is a combination of fluid viscosity, wall friction, and the artificial dissipation introduced by the VOF interface and the AMR mapping.

**Forcing Parameters (Shut-off Test)**

- Excitation Phase ($0 \le t \le 10\text{ s}$): $\omega = 0.95\,\sigma_{11}$, $a_0 = 0.005 \cdot g$
- Decay Phase ($10 < t \le 40\text{ s}$): $a_0 = 0\text{ m/s}^2$

> 💡 **Methodology:** Giving a single arbitrary impulse creates spurious acoustic pressure waves and excites high-order, unphysical sloshing modes. The "shut-off test" instead forces the tank gently to establish a pure 1st-mode planar wave, then turns off the forcing to analyze the clean decay envelope.

**Result: do not use this case's $\xi$.** The naive log-decrement fit gave $\xi=0.08\%$, implausibly low. $F_x(t)$ shows persistent amplitude beating through the entire decay window instead of a clean exponential — traced to the forcing frequency being close enough to resonance ($0.95\,\sigma_{11}$) that the abrupt onset at $t=0$ excites a free transient at $\sigma_{11}$ which beats against the forced response with an ~11.5 s period, longer than the 9.5 s forcing window itself. A narrow bandpass filter around $f_{11}$ does **not** fix this (amplitude-modulation sidebands sit too close to the carrier to separate). See `Case7_Free_Decay_OffResonance/` for the corrected measurement.

### Case 7: Free Decay & Viscous Damping Estimation — Off-Resonance Control ✅ reference

**Objective**

Provide a clean, trustworthy damping-ratio measurement, replacing Case 6.

**What's different from Case 6**

1. **Detuned excitation**: $\omega = 0.80\,\sigma_{11}$ instead of $0.95\,\sigma_{11}$ — shortens the beat period to ~2.9 s, giving >3 full beat cycles inside the forcing window instead of less than one.
2. **Symmetric ramp-up**: a 0.5 s cosine ramp-up at $t=0$ (matching the existing ramp-down at shutoff) reduces the free transient at the source instead of relying on it decaying away in time.

**Result**: clean, essentially monotonic decay from $t=10$ s to $t\approx37$ s, **$\xi\approx1.72\%$** — this is the damping ratio to use for the campaign going forward.

$$
\xi = \frac{\delta}{\sqrt{4\pi^2 + \delta^2}}, \qquad \delta = \frac{1}{N}\ln\!\left(\frac{A_1}{A_{N+1}}\right)
$$

---

## Known Issues & Fixes

Kept here as a record — several of these are structural issues in the shared case template (`TabulaRasa`, `Allrun`) and could resurface in any case, not just the ones where they were first found.

1. **Courant/AMR blowup at mesh-refinement events.** First found in `Case0_Chirp` at $t\approx7.32$ s: `Courant Number max` jumped from 0.52 to 1247 in a single step, coincident with a refine/unrefine event and `min(alpha)` briefly going negative — a transient VOF/AMR instability, not a real hydrodynamic load. **Fix (campaign-wide)**: tightened `controlDict` (`maxCo 0.5→0.3`, `maxAlphaCo 0.5→0.2`, `maxDeltaT 0.005→0.002`), `dynamicMeshDict` (`refineInterval 5→1`, `nBufferLayers 1→2`), `fvSolution` (`nAlphaBounds 3→5`).

2. **`TabulaRasa` never cleaned `postProcessing/`.** Even after every dictionary was corrected and a case was relaunched, `Allrun`'s `cat postProcessing/wallForces/*/force*.dat` kept re-concatenating the *original* contaminated segment (byte-identical to the decimal) alongside genuinely new data, because the old `postProcessing/` subdirectories from the very first run were never removed. This was confirmed by comparing the exact spike values across three separate "fresh" relaunches. **Fix**: added `postProcessing` to every case's `TabulaRasa` cleanup list.

3. **`postProcess -time ':'` silently does nothing.** The bare `':'` range is rejected (`Bad scalar-range parsing`) and OpenFOAM falls back to only the `constant` pseudo-time — no hard error, it just processes nothing, so a script using it can appear to succeed while producing an empty result. **Fix**: always use an explicit bounded range, e.g. `-time '0:80'`. See the `FORCES/` extraction pattern in [Execution Workflow](#execution-workflow).

4. **Case 5 (shallow/soft-spring) needed case-specific tuning beyond the campaign-wide fix.** Even under the tightened settings above, violent bore/hydraulic-jump events caused sustained AMR "thrashing" — hundreds of refine/unrefine flips within a fraction of a second (e.g. 348 topology changes across 3604 timesteps in a single 0.03 s window), reaching force spikes over an order of magnitude larger than Case0's original blowup. Counter-intuitively, tightening `maxCo` further and increasing `nBufferLayers` made it *worse*, not better — ruling out "insufficient Courant margin" as the cause. Current hypothesis: `maxRefinement=1` is too shallow to stably resolve this case's steep bore fronts. **In progress**: `maxRefinement 1→2`, `refineInterval 5→3`, keeping `nBufferLayers=3`.

5. **Case 6's near-resonance free decay is uncorrectable by filtering.** See the Case 6 writeup above — solved by adding Case 7 rather than trying to post-process Case 6's data into something usable.

6. **Local-vs-cluster file sync is not automatic.** This working copy (synced via OneDrive) is *not* the machine the solver runs on. Edits made here have, more than once, been assumed to be present on the HPC cluster when they weren't (`refineInterval` was found stuck at an old value on the cluster while this local copy already showed the corrected one). **Always** run `cat <file>` directly on the cluster immediately before relaunching a case to confirm ground truth, rather than trusting that a local edit propagated.

7. **Misplaced/stale documentation.** `Case0_Chirp/README.md` was found to contain `Case1_Planar_Wave`'s description (wrong case entirely) and has been rewritten; a stray single-case draft (`README(Bho).md`, pre-dating the multi-case campaign structure) was removed from the repository root.

---

## Contributing

Contributions to improve the mesh topology, extend the post-processing engine to handle Python (`scipy.signal`), or implement different tank geometries are welcome.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AdvancedAMR`)
3. Commit your Changes (`git commit -m 'Add Advanced AMR'`)
4. Push to the Branch (`git push origin feature/AdvancedAMR`)
5. Open a Pull Request

---

## License

Distributed under the MIT License, configured directly on the GitHub repository.
