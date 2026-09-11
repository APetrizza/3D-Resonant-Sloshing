import math
import os

# =============================================================================
# HARMONIC 6-DOF ACCELERATION TABLE GENERATOR FOR OPENFOAM (v2412)
# =============================================================================

# Physical and excitation parameters
t_end = 40.0        # Total simulation time (s)
dt = 0.001           # Time resolution step (s)
 
# Tank / fluid geometry (shallow-water case)
R0 = 0.15            # Tank radius (m)
h = 0.05             # Liquid filling height (m) -- h/R0 = 0.333
g = 9.81             # Gravity (m/s^2)
k11 = 1.84118        # First root of J1'(k) = 0
 
# Recalculate sigma_11 for THIS case's actual filling depth (do not reuse
# the deep-water value from Case1/2/4/6)
sigma11 = math.sqrt((g * k11 / R0) * math.tanh(k11 * h / R0))
f11 = sigma11 / (2 * math.pi)
 
# Forcing parameters
a0 = 0.02 * g                 # Acceleration amplitude = 0.02 * g (m/s^2)
freq_ratio = 0.98              # omega / sigma_11, resonance shifted left
omega = freq_ratio * sigma11   # rad/s
 
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
print(f"     -> h = {h} m (h/R0 = {h/R0:.4f}), recalculated sigma_11 = {sigma11:.5f} rad/s "
      f"(f11 = {f11:.5f} Hz)")
print(f"     -> a0 = {a0:.5f} m/s^2 (0.02 g)")
print(f"     -> omega = {omega:.5f} rad/s ({freq_ratio} * sigma_11, f = {omega/(2*math.pi):.5f} Hz)")
print("")
print("     REMINDER: also verify the alpha.water probe z-location in "
      "system/controlDict is set for THIS case's shallow depth (h = 0.05 m), "
      "not inherited from the deep-water (h = 0.225 m) cases -- the previous "
      "run showed flat/zero probes, consistent with a probe sitting above "
      "the free surface.")