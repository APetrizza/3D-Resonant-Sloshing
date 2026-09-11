import math
import os

# =============================================================================
# HARMONIC 6-DOF ACCELERATION TABLE GENERATOR FOR OPENFOAM (v2412)
# =============================================================================

# Physical and excitation parameters
t_end = 40.0       # Total simulation time (s)
dt = 0.001         # Time resolution step (s)
g = 9.81           # Gravity acceleration (m/s^2)
f11 = 1.7393       # Theoretical natural frequency (Hz)

# Main forcing parameters (X-axis)
a0 = 0.015 * g                      # Acceleration amplitude = 0.015 * g (m/s^2)
omega = 1.04 * (2 * math.pi * f11)  # Forcing frequency = 1.04 * sigma_11 (rad/s)

# Y-axis trigger parameters (to break numerical symmetry)
a_trigger = 0.01 * a0               # Trigger amplitude is 1% of a0
t_trigger_end = 2.0                 # Trigger smoothly fades out at 2.0 s

steps = int(t_end / dt) + 1

# Ensure constant/ directory exists
os.makedirs('constant', exist_ok=True)
output_path = os.path.join('constant', 'acceleration.dat')

# Format per entry: (time ((ax ay az) (wx wy wz) (dwx dwy dwz)))
with open(output_path, 'w') as f:
    f.write('(\n')
    for i in range(steps):
        t = i * dt
        
        # X-axis: Main harmonic forcing
        ax = a0 * math.sin(omega * t)
        
        # Y-axis: Initial trigger to induce swirling
        ay = 0.0
        if t <= t_trigger_end:
            # Smooth envelope (cosine ramp-down from 1 to 0)
            envelope = 0.5 * (1.0 + math.cos(math.pi * t / t_trigger_end))
            # Cosine phase for natural 90-degree swirling offset
            ay = a_trigger * math.cos(omega * t) * envelope
            
        f.write(f'  ({t:.4f} (({ax:.8f} {ay:.8f} 0) (0 0 0) (0 0 0)))\n')
    f.write(')\n')

print(f"[OK] CASE 3: File '{output_path}' generated successfully ({steps} time steps).")
print(f"     -> a0 (X) = {a0:.4f} m/s^2")
print(f"     -> omega  = {omega:.4f} rad/s")
print(f"     -> Y-axis trigger active for the first {t_trigger_end} s.")