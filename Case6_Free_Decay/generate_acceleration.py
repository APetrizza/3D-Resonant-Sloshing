import math
import os

# =============================================================================
# HARMONIC 6-DOF ACCELERATION TABLE GENERATOR FOR OPENFOAM (v2412)
# =============================================================================

# Physical and excitation parameters
t_end = 40.0       # Total simulation time (s)
dt = 0.001         # Time resolution step (s)
a0 = 0.005 * 9.81       # Acceleration amplitude = 0.005 * g (m/s^2)
omega = 10.38189   # Forcing frequency = 0.95 * sigma_11 (rad/s)
 
t_shutoff = 10.0   # s, forcing envelope reaches zero at this time
t_taper = 0.5      # s, duration of the cosine taper immediately before
                   # t_shutoff -- avoids the discontinuous "hard cutoff"
                   # (a step from a nonzero value straight to 0 in a single
                   # timestep) that was present in the previous version and
                   # likely injected broadband noise into the free-decay
                   # segment. The taper is smooth in both value AND slope
                   # at both ends (t_shutoff - t_taper and t_shutoff), so it
                   # introduces no new discontinuity.
 
steps = int(t_end / dt) + 1
 
# Ensure constant/ directory exists
os.makedirs('constant', exist_ok=True)
output_path = os.path.join('constant', 'acceleration.dat')
 
 
def envelope(t):
    """Amplitude envelope: 1.0 until the taper starts, smooth cosine
    ramp-down to 0.0 over t_taper seconds, then 0.0 thereafter."""
    t_taper_start = t_shutoff - t_taper
    if t <= t_taper_start:
        return 1.0
    elif t <= t_shutoff:
        # Half-cosine ramp: envelope(t_taper_start) = 1, envelope(t_shutoff) = 0,
        # with zero slope at both ends (C1-continuous taper).
        return 0.5 * (1.0 + math.cos(math.pi * (t - t_taper_start) / t_taper))
    else:
        return 0.0
 
 
# Format per entry: (time ((ax ay az) (wx wy wz) (dwx dwy dwz)))
with open(output_path, 'w') as f:
    f.write('(\n')
    for i in range(steps):
        t = i * dt
        ax = a0 * envelope(t) * math.sin(omega * t)
        f.write(f'  ({t:.4f} (({ax:.8f} 0 0) (0 0 0) (0 0 0)))\n')
    f.write(')\n')
 
print(f"[OK] File '{output_path}' generated successfully ({steps} time steps).")
print(f"     -> a0 = {a0:.5f} m/s^2 (0.005 g), omega = {omega:.5f} rad/s (0.95 sigma_11)")
print(f"     -> Excitation full amplitude until t = {t_shutoff - t_taper:.2f} s")
print(f"     -> Smooth cosine taper from t = {t_shutoff - t_taper:.2f} s to t = {t_shutoff:.2f} s")
print(f"     -> Zero forcing (free decay) for t > {t_shutoff:.2f} s")
 