# Case 6 — Free Decay & Viscous Damping Estimation

Status: **Completed, but contaminated — superseded by [Case7_Free_Decay_OffResonance](../Case7_Free_Decay_OffResonance/README.md)**

## Objective

Calculate the total numerical damping ratio ($\xi$) of the CFD setup — combining fluid viscosity, wall friction, and the artificial dissipation introduced by the VOF interface and AMR mapping.

## Forcing Parameters (Shut-off Test)

| Parameter | Value |
|---|---|
| Tank radius, $R_0$ | 0.15 m |
| Filling height, $h$ | 0.225 m |
| Natural frequency, $f_{11}$ | 1.7393 Hz |
| Excitation phase ($0 \le t \le 10$ s) | $\omega = 0.95\,\sigma_{11}$, $a_0 = 0.005\,g$ |
| Decay phase ($10 < t \le 30$ s) | $a_0 = 0$ m/s² |

> 💡 **Methodology**: a single arbitrary impulse creates spurious acoustic pressure waves and excites unphysical high-order sloshing modes. This "shut-off test" instead forces the tank gently to establish a pure 1st-mode planar wave, then abruptly cuts the forcing to analyze the clean decay envelope.

## Expected Phenomenology

- $F_x(t)$ shows a clean, exponential decay starting exactly at $t = 10$ s.
- Extracting the peaks of the decaying wave (MATLAB `findpeaks`) yields the logarithmic decrement $\delta$, from which the damping ratio is estimated:

$$
\xi = \frac{\delta}{\sqrt{4\pi^2 + \delta^2}}
$$

## Directory Contents

```
Case6_FreeDecay/
├── 0/                        # Initial conditions
├── constant/                 # Mesh, transport properties, acceleration.dat (generated)
├── system/                   # blockMeshDict, controlDict, fvSchemes, fvSolution
├── generate_acceleration.py  # Builds constant/acceleration.dat (excitation + shut-off)
├── Allrun                    # Case execution script
├── (launch.slurm)             # Slurm script used on our cluster — site-specific, not tracked in git
└── README.md                 # This file
```

## Execution Workflow

```bash
cd Case6_FreeDecay/
python3 generate_acceleration.py
./Allrun   # or wrap in your own Slurm/PBS submission script — see root README's Execution Workflow
```

Ensure the simulation end time in `system/controlDict` covers the full 30 s (10 s excitation + 20 s free decay).

## Post-Processing

`process_sloshing_data.m` covers the general FFT/hodograph/STFT diagnostics, but this case additionally requires a dedicated damping estimation step **not currently included in the script**:

1. Isolate $F_x(t)$ for $t > 10$ s from the resampled/filtered signal (`Fx_clean` in the script).
2. Run `findpeaks` on the decay segment to extract successive peak amplitudes $A_n$.
3. Compute the logarithmic decrement over $N$ cycles: $\delta = \frac{1}{N}\ln\left(\frac{A_1}{A_{N+1}}\right)$.
4. Convert to the damping ratio: $\xi = \dfrac{\delta}{\sqrt{4\pi^2 + \delta^2}}$.

Consider adding this as a `%% 10. DAMPING ESTIMATION` section to a case-local copy of `process_sloshing_data.m`.

The damping-estimation section described above is now implemented directly in the campaign-root `process_sloshing_data.m` (Section 10, auto-triggered for any folder matching `Free_Decay`), so it no longer needs to be copied case-by-case.

## Results

**Do not use the $\xi$ from this case.** $F_x(t)$ does **not** show the expected clean exponential decay: the naive log-decrement fit gave $\xi = 0.0008$ (0.08%), implausibly low for a VOF/AMR setup.

Root cause, confirmed by direct inspection of `interIsoFoam.log` / `FORCES/force.dat` and FFT analysis of the decay segment:

- The forcing frequency $\omega = 0.95\,\sigma_{11}$ is close enough to resonance that the abrupt onset at $t=0$ (no ramp-up, only Case6's shutoff had a taper) excites a companion free transient at $\sigma_{11}$ alongside the forced response. The two beat against each other with period $T_{\text{beat}} = 1/(0.05\times f_{11}) \approx 11.5$ s.
- Because that beat period exceeds the 9.5 s full-amplitude forcing window, the system is still mid-beat at shutoff ($t=10$ s) — the "clean 1st-mode planar wave" precondition for the shut-off methodology is not actually met.
- The resulting $F_x(t)$ shows deep (near-total) amplitude modulation persisting through the whole decay window (envelope minima around $t\approx14$s, $24$s, $35$s), confirmed present in the **raw, unfiltered** CFD force data — not a post-processing artifact.
- A narrow bandpass filter around $f_{11}$ was tried and does **not** fix it: AM sidebands sit too close to the carrier to be separated from it without also removing the carrier itself (attempted fix, still logged in `process_sloshing_data.m`'s Section 10 comments as a cautionary note — the current script no longer relies on it for this case since Case7 replaces the measurement).
- `Fy` (transverse force) stays at or near the numerical noise floor throughout (rms ~0.0006N during forcing vs. ~2.9N for `Fx`), ruling out swirl/y-mode coupling as the cause.

This case's `FORCES/` data predates the campaign-wide Courant-stability patch (`maxCo`/`refineInterval`, applied 2026-08-11) and has not been rerun since — there is no numerical-stability reason to rerun it, since the beating is a real physical/methodological artifact of forcing too close to resonance, not a numerics bug. See [Case7_Free_Decay_OffResonance](../Case7_Free_Decay_OffResonance/README.md) for the corrected measurement ($\xi \approx 1.7\%$, clean decay).
