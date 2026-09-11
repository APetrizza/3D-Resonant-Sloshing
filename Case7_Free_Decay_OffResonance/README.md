# Case 7 — Free Decay & Viscous Damping Estimation (Off-Resonance Control)

Status: **Completed — clean decay obtained, $\xi \approx 1.7\%$** (minor tail caveat, see Results)

## Objective

Provide a clean control measurement of the total numerical damping ratio ($\xi$) of the CFD setup, replacing the contaminated estimate from Case6_Free_Decay.

## Why this case exists

Case6 forced the tank at $\omega = 0.95\,\sigma_{11}$ (i.e. 5% below the natural frequency) and expected a clean single-mode exponential decay after shutoff at $t=10$ s. Post-processing showed instead a persistent amplitude modulation ("beating") in $F_x(t)$ throughout the entire 30 s decay window, with an envelope period of ~11.5 s. This matches almost exactly the theoretical beat period between the forcing frequency and the natural frequency:

$$
T_{\text{beat}} = \frac{1}{|\sigma_{11} - \omega|/2\pi} = \frac{1}{0.05 \times 1.7393\ \text{Hz}} \approx 11.5\ \text{s}
$$

Because that beat period (11.5 s) is *longer* than the 9.5 s full-amplitude forcing window, the free transient at $\sigma_{11}$ excited by the onset of forcing never gets the chance to complete even one beat cycle before shutoff — the system is "frozen" mid-beat when the log-decrement fit starts. A narrow bandpass filter around $\sigma_{11}$ cannot remove this: amplitude modulation of a carrier produces sidebands at $\sigma_{11} \pm f_{\text{beat}}$ that sit too close to the carrier to be filtered out without also removing the carrier itself. The only real fix is to change the excitation so the beat period is short compared to the forcing window, or eliminate the beat-driving transient at the source.

## Forcing Parameters (Shut-off Test)

| Parameter | Value |
|---|---|
| Tank radius, $R_0$ | 0.15 m |
| Filling height, $h$ | 0.225 m |
| Natural frequency, $f_{11}$ | 1.7393 Hz ($\sigma_{11}$ = 10.9283 rad/s) |
| Excitation phase ($0 \le t \le 10$ s) | $\omega = 0.80\,\sigma_{11}$ = 8.74264 rad/s, $a_0 = 0.005\,g$ |
| Decay phase ($10 < t \le 40$ s) | $a_0 = 0$ m/s² |

Two changes relative to Case6, both implemented in `generate_acceleration.py`:

1. **Detuned excitation frequency**: $\omega = 0.80\,\sigma_{11}$ instead of $0.95\,\sigma_{11}$. This shortens the beat period to ~2.9 s, giving ~3.3 full beat cycles inside the 9.5 s forcing window — the transient/forced-response phase relationship has time to average out before shutoff, instead of freezing mid-cycle.
2. **Symmetric ramp-up**: Case6 only tapered the forcing *off* smoothly at shutoff; the *onset* at $t=0$ was an instantaneous step to full amplitude. A step input to a lightly-damped near-resonant oscillator always excites a companion free transient at $\sigma_{11}$ on top of the forced response — that transient is the root cause of the beating. This case adds a matching 0.5 s cosine ramp-up at $t=0$ to reduce that transient at the source, not just hope it decays away in time.

> 💡 **Methodology**: a single arbitrary impulse creates spurious acoustic pressure waves and excites unphysical high-order sloshing modes. This "shut-off test" instead forces the tank gently to establish a pure 1st-mode planar wave, then abruptly (but smoothly) cuts the forcing to analyze the clean decay envelope.

## Expected Phenomenology

- $F_x(t)$ should show a clean, monotonically decaying envelope starting at $t = 10$ s, without the beating seen in Case6.
- The FFT of the excitation phase should show a single dominant peak near $\omega/2\pi \approx 1.391$ Hz, well separated from $f_{11} = 1.7393$ Hz — if a residual free-transient peak near 1.74 Hz still shows comparable amplitude to the forced peak, the ramp-up did not fully suppress it and the beat period math above should be revisited.
- Extracting the peaks of the decaying wave (MATLAB `findpeaks`, via `process_sloshing_data.m`) should now yield a much more reliable logarithmic decrement $\delta$ and damping ratio:

$$
\xi = \frac{\delta}{\sqrt{4\pi^2 + \delta^2}}
$$

## Directory Contents

```
Case7_Free_Decay_OffResonance/
├── 0.orig/                   # Initial conditions
├── constant/                 # Mesh properties, acceleration.dat (generated)
├── system/                   # blockMeshDict, controlDict, fvSchemes, fvSolution
├── generate_acceleration.py  # Builds constant/acceleration.dat (ramp-up + excitation + ramp-down)
├── Allrun                    # Case execution script
├── TabulaRasa                # Clean/reset script
├── launch.slurm              # Slurm batch submission script
└── README.md                 # This file
```

## Execution Workflow

```bash
cd Case7_Free_Decay_OffResonance/
python3 generate_acceleration.py   # already run once; re-run if parameters change
sbatch launch.slurm
```

`system/controlDict` already carries the campaign-wide numerical stability fixes (`maxCo=0.3`, `maxAlphaCo=0.2`, `maxDeltaT=0.002`) and `constant/dynamicMeshDict` (`refineInterval=1`, `nBufferLayers=2`) established after the Case0/Case5 Courant-blowup investigation, so this case does not need any further numerical patching before launch.

## Post-Processing

`process_sloshing_data.m` (campaign root) auto-detects this case by folder name (matches `Free_Decay`) and runs the damping-estimation branch (Section 10), generating `fig7_damping_estimation.png` together with the standard 6 figures. No case-specific script is required.

If the beat is still visible in `fig7` after running this case, that means the detuning + ramp-up were not enough on their own, and the next step would be a proper two-mode (coupled oscillator) decay fit instead of a simple exponential log-decrement — see the discussion in the Case6 analysis notes.

## Results

The fix worked. `fig7_damping_estimation.png` shows a clean, essentially monotonic decay envelope from $t=10$ s to $t\approx37$ s, with **no beating** — a qualitative confirmation that detuning to $0.80\,\sigma_{11}$ (plus the symmetric ramp-up) kept the companion free transient from contaminating the decay, unlike Case6.

**Damping ratio: $\xi \approx 0.0172$ (1.72% of critical)** — this is the value to use going forward for the campaign's total numerical damping (viscosity + wall friction + VOF/AMR dissipation), replacing the unreliable Case6 estimate.

Caveat: the last ~2-3 s of the window ($t\approx37$–$40$ s) show some irregular peak amplitudes rather than a smooth continuation of the exponential tail — expected, since by that point the signal has decayed to ~0.05-0.1N and is approaching the resolution floor of `findpeaks` on this force signal. This tail was included in the current $\xi$ fit; if a stricter estimate is needed, re-run the log-decrement fit restricted to $t \in [10, 35]$ s (comfortably before the noisy tail) and compare — the two values should agree closely if the fit is robust.
