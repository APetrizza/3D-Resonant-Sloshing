import math
import os

# =============================================================================
# HARMONIC 6-DOF ACCELERATION TABLE GENERATOR FOR OPENFOAM (v2412)
# =============================================================================

# Physical and excitation parameters
t_end = 40.0       # Total simulation time (s)
dt = 0.001         # Time resolution step (s)
a0 = 0.0981        # Acceleration amplitude = 0.01 * g (m/s^2)
omega = 11.1469    # Forcing frequency = 1.02 * sigma_11 (rad/s)

steps = int(t_end / dt) + 1

# Ensure constant/ directory exists
os.makedirs('constant', exist_ok=True)
output_path = os.path.join('constant', 'acceleration.dat')

# Format per entry: (time ((ax ay az) (wx wy wz) (dwx dwy dwz)))
with open(output_path, 'w') as f:
    f.write('(\n')
    for i in range(steps):
        t = i * dt
        ax = a0 * math.sin(omega * t)
        f.write(f'  ({t:.4f} (({ax:.8f} 0 0) (0 0 0) (0 0 0)))\n')
    f.write(')\n')

print(f"[OK] File '{output_path}' generated successfully ({steps} time steps).")