import math
import os

# =============================================================================
# LINEAR CHIRP (SWEPT-SINE) 6-DOF ACCELERATION TABLE GENERATOR - Case0_Chirp
# Broadband modal identification sweep, band-limited and Tukey-tapered to
# avoid start/stop discontinuities (which would inject broadband numerical
# noise, same issue as an impulsive/impact test).
# =============================================================================

# Sweep parameters
t_end = 80.0                 # Total sweep duration (s)
dt = 0.001                   # Time resolution step (s)
a0 = 0.001 * 9.81            # Forcing amplitude = 0.001 * g (m/s^2), kept
                              # small to stay linear across the whole sweep
f_start = 0.5                # Sweep start frequency (Hz)
f_end = 3.5                  # Sweep end frequency (Hz)
k_rate = (f_end - f_start) / t_end   # Hz/s, linear sweep rate

tukey_alpha = 0.05           # Taper fraction at each end (5%)

steps = int(t_end / dt) + 1

# Ensure constant/ directory exists
os.makedirs('constant', exist_ok=True)
output_path = os.path.join('constant', 'acceleration.dat')


def tukey_weight(t, t_end, alpha):
    """Tukey (tapered cosine) window value at time t."""
    if alpha <= 0.0:
        return 1.0
    edge = alpha * t_end / 2.0
    if t < edge:
        return 0.5 * (1 + math.cos(math.pi * (t / edge - 1)))
    elif t > t_end - edge:
        return 0.5 * (1 + math.cos(math.pi * ((t - (t_end - edge)) / edge)))
    else:
        return 1.0


# Format per entry: (time ((ax ay az) (wx wy wz) (dwx dwy dwz)))
with open(output_path, 'w') as f:
    f.write('(\n')
    for i in range(steps):
        t = i * dt
        phase = 2.0 * math.pi * (f_start * t + 0.5 * k_rate * t * t)
        w = tukey_weight(t, t_end, tukey_alpha)
        ax = a0 * w * math.sin(phase)
        f.write(f'  ({t:.4f} (({ax:.8f} 0 0) (0 0 0) (0 0 0)))\n')
    f.write(')\n')

# Instantaneous frequency map, for later cross-checking against the STFT
# ridge / transfer-function estimate in post-processing.
freq_path = os.path.join('constant', 'chirp_f_inst.csv')
with open(freq_path, 'w') as f:
    f.write('time,f_inst_Hz\n')
    for i in range(0, steps, 10):   # coarser sampling is enough for this map
        t = i * dt
        f_inst = f_start + k_rate * t
        f.write(f'{t:.4f},{f_inst:.6f}\n')

print(f"[OK] File '{output_path}' generated successfully ({steps} time steps).")
print(f"Sweep: {f_start} Hz -> {f_end} Hz over {t_end} s "
      f"(rate {k_rate:.4f} Hz/s), amplitude a0={a0:.5f} m/s^2 "
      f"({a0/9.81:.4f} g), Tukey alpha={tukey_alpha}")
print(f"FFT frequency resolution for post-processing: ~{1.0/t_end:.4f} Hz")