import math
import os

# =============================================================================
# HARMONIC 6-DOF ACCELERATION TABLE GENERATOR FOR OPENFOAM (v2412)
# Case7_Free_Decay_OffResonance -- control case for Case6_Free_Decay
#
# Case6 (omega = 0.95*sigma_11) turned out to show persistent amplitude
# modulation ("beating") throughout the free-decay segment, at a period
# matching |sigma_11 - 0.95*sigma_11| ~ 11.5 s -- i.e. close to a full beat
# cycle longer than the forcing window itself (9.5 s of full-amplitude
# excitation), so the transient at sigma_11 excited by the forcing onset
# never gets the chance to average out before shutoff. This corrupts the
# single-mode log-decrement fit used to extract the damping ratio.
#
# Fix #1 (this file): move omega further from resonance (0.80*sigma_11
# instead of 0.95*sigma_11). The beat period scales as 1/|sigma_11-omega|,
# so at 0.80 the beat period drops to ~2.9 s -- more than 3 full beat
# cycles occur during the 9.5 s forcing window, letting the phase average
# out before shutoff instead of freezing mid-cycle like in Case6.
#
# Fix #2 (this file): add a symmetric ramp-UP at t=0 (Case6 only had a
# ramp-down at shutoff). An abrupt onset at t=0 is exactly what excites the
# free sigma_11 transient in the first place (a step input to a lightly
# damped near-resonant oscillator always excites a companion transient at
# its own natural frequency, on top of the steady forced response). Ramping
# in smoothly reduces the size of that companion transient at the source
# instead of just hoping it decays away by t_shutoff.
# =============================================================================

# Physical and excitation parameters
t_end = 40.0            # Total simulation time (s)
dt = 0.001               # Time resolution step (s)
a0 = 0.005 * 9.81        # Acceleration amplitude = 0.005 * g (m/s^2)
sigma_11 = 10.38189 / 0.95   # = 10.92831 rad/s (natural frequency, same tank as Case6)
omega = 0.80 * sigma_11      # = 8.74264 rad/s -- Forcing frequency = 0.80 * sigma_11

t_shutoff = 10.0    # s, forcing envelope reaches zero at this time
t_taper = 0.5       # s, duration of the cosine taper at BOTH the ramp-up
                     # (t=0 to t=t_taper) and the ramp-down (t_shutoff-t_taper
                     # to t_shutoff) -- avoids any discontinuous "hard" step
                     # in the acceleration signal, at start or at shutoff,
                     # each of which can inject its own broadband/transient
                     # content. The taper is C1-continuous (smooth in both
                     # value and slope) at every junction.

steps = int(t_end / dt) + 1

# Ensure constant/ directory exists
os.makedirs('constant', exist_ok=True)
output_path = os.path.join('constant', 'acceleration.dat')


def envelope(t):
    """Amplitude envelope: smooth cosine ramp-UP from 0 to 1 over the first
    t_taper seconds, full amplitude (1.0) in between, smooth cosine
    ramp-DOWN to 0.0 over t_taper seconds before t_shutoff, then 0.0
    thereafter."""
    t_taper_start = t_shutoff - t_taper
    if t <= t_taper:
        # Half-cosine ramp-up: envelope(0) = 0, envelope(t_taper) = 1,
        # with zero slope at both ends.
        return 0.5 * (1.0 - math.cos(math.pi * t / t_taper))
    elif t <= t_taper_start:
        return 1.0
    elif t <= t_shutoff:
        # Half-cosine ramp-down: envelope(t_taper_start) = 1, envelope(t_shutoff) = 0,
        # with zero slope at both ends.
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

beat_period_case6 = 1.0 / abs((sigma_11 - 0.95 * sigma_11) / (2 * math.pi))
beat_period_here = 1.0 / abs((sigma_11 - omega) / (2 * math.pi))

print(f"[OK] File '{output_path}' generated successfully ({steps} time steps).")
print(f"     -> a0 = {a0:.5f} m/s^2 (0.005 g), omega = {omega:.5f} rad/s (0.80 sigma_11)")
print(f"     -> sigma_11 = {sigma_11:.5f} rad/s ({sigma_11/(2*math.pi):.4f} Hz)")
print(f"     -> Smooth cosine ramp-UP from t = 0.00 s to t = {t_taper:.2f} s")
print(f"     -> Full amplitude from t = {t_taper:.2f} s to t = {t_shutoff - t_taper:.2f} s")
print(f"     -> Smooth cosine ramp-DOWN from t = {t_shutoff - t_taper:.2f} s to t = {t_shutoff:.2f} s")
print(f"     -> Zero forcing (free decay) for t > {t_shutoff:.2f} s")
print(f"     -> Beat period at this detuning : {beat_period_here:.2f} s "
      f"(~{9.5/beat_period_here:.1f} beat cycles within the forcing window)")
print(f"     -> For comparison, Case6 (0.95 sigma_11) beat period was "
      f"{beat_period_case6:.2f} s (<1 beat cycle within its forcing window)")
