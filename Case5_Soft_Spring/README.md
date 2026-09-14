# Case 5 — Shallow Water / Soft-Spring Regime

Status: **Pending** (not yet run)

## Objective

Demonstrate the shift in non-linear sloshing physics when the filling ratio drops below $h/R_0 < 1.05$. The system transitions from a Hard-Spring to a Soft-Spring behavior: the resonance curve bends towards lower frequencies, and the wave nature shifts from harmonic standing waves to traveling bores.

## Forcing Parameters

| Parameter | Value |
|---|---|
| Tank radius, $R_0$ | 0.15 m |
| Filling height, $h$ | 0.05 m ($h/R_0 \approx 0.333$) |
| Natural frequency, $f_{11}$ | 1.291 Hz (recalculated for shallow depth) |
| Frequency ratio, $\omega / \sigma_{11}$ | 0.98 (resonance shifted left) |
| Forcing amplitude, $a_0/g$ | 0.020 |
| Forcing amplitude, $a_0$ | 0.1962 m/s² |

> ⚠️ **Note**: This case uses a different filling height than Cases 1–4 and 6. Confirm the mesh / `blockMeshDict` in `constant/` reflects $h = 0.05$ m before running, and that `generate_acceleration.py` is configured with $f_{11} = 1.291$ Hz.

## Expected Phenomenology

- The fluid no longer behaves as a smooth sinusoidal wave. Hydraulic jumps and traveling bores sweep across the shallow bottom.
- The force history becomes highly skewed and impulsive rather than harmonic.

## Directory Contents

```
Case5_Shallow/
├── 0/                        # Initial conditions
├── constant/                 # Mesh (shallow depth), transport properties, acceleration.dat
├── system/                   # blockMeshDict, controlDict, fvSchemes, fvSolution
├── generate_acceleration.py  # Builds constant/acceleration.dat (soft-spring f11)
├── Allrun                    # Case execution script
├── (launch.slurm)             # Slurm script used on our cluster — site-specific, not tracked in git
└── README.md                 # This file
```

## Execution Workflow

```bash
cd Case5_Shallow/
python3 generate_acceleration.py
./Allrun   # or wrap in your own Slurm/PBS submission script — see root README's Execution Workflow
```

## Post-Processing

Run `process_sloshing_data.m` from this directory once the job finishes. Before use, update the theoretical reference line in the script:

```matlab
f_theory = 1.291;  % Case 5 uses the soft-spring natural frequency, not 1.7393 Hz
```

Key diagnostics for this case:

- **Fig. 1 / Fig. 2 (left)**: expect a visibly skewed, non-sinusoidal $F_x(t)$ trace with steep fronts, consistent with traveling bores/hydraulic jumps rather than a smooth harmonic wave.
- **Fig. 4 (FFT)**: the spectral peak should sit near 1.291 Hz rather than 1.7393 Hz; expect a broader harmonic content than the hard-spring cases due to the bore's impulsive character.
- **Fig. 5 (STFT)**: look for irregular, impulsive energy bursts rather than a smooth continuous band.

## Results

_To be filled in once the simulation and post-processing have been completed._
