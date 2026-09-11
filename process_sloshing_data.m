%% ========================================================================
%  3D CYLINDRICAL SLOSHING POST-PROCESSING & ADVANCED DSP ENGINE
%  OpenFOAM-v2412 interIsoFoam Results Processing (Definitive Version)
%  Features: Uniform Resampling, Flat-Top FFT, IIR/FIR Comparison
% ========================================================================
clear; clc; close all;
%% 0. PALETTE COLOR DEFINITIONS (SUNNY BEACH DAY)
C_DARK    = [0.149, 0.275, 0.325]; % #264653 - Dark Slate
C_TEAL    = [0.165, 0.616, 0.561]; % #2A9D8F - Teal
C_GOLD    = [0.914, 0.769, 0.416]; % #E9C46A - Gold
C_SAND    = [0.957, 0.635, 0.380]; % #F4A261 - Sandy Orange
C_CORAL   = [0.906, 0.435, 0.318]; % #E76F51 - Coral

set(0, 'DefaultAxesFontName', 'Helvetica');
set(0, 'DefaultAxesFontSize', 12);
set(0, 'DefaultLineLineWidth', 1.8);

fprintf('========================================================\n');
fprintf(' 3D SLOSHING POST-PROCESSING ENGINE - Definitive Version\n');
fprintf('========================================================\n');

%% 1. AUTOMATIC FILE SEARCH & ROBUST CHECK
currentFolder = pwd;
search_dirs = { 'FORCES'};

force_file = ''; force_names = {'force.dat', 'forces.dat'};
for d = 1:length(search_dirs)
    for f = 1:length(force_names)
        m = dir(fullfile(search_dirs{d}, '**', force_names{f}));
        if ~isempty(m), force_file = fullfile(m(1).folder, m(1).name); break; end
    end
    if ~isempty(force_file), break; end
end

moment_file = ''; moment_names = {'moment.dat', 'moments.dat'};
for d = 1:length(search_dirs)
    for f = 1:length(moment_names)
        m = dir(fullfile(search_dirs{d}, '**', moment_names{f}));
        if ~isempty(m), moment_file = fullfile(m(1).folder, m(1).name); break; end
    end
    if ~isempty(moment_file), break; end
end

alpha_file = '';
for d = 1:length(search_dirs)
    m = dir(fullfile(search_dirs{d}, '**', 'alpha.water'));
    if ~isempty(m), alpha_file = fullfile(m(1).folder, m(1).name); break; end
end

if isempty(force_file) || isempty(moment_file) || isempty(alpha_file)
    error('Fatal Error: Could not locate required OpenFOAM .dat files.');
end


DampingEstimator=false;
FrequencyResponse=false;

% Matched on folder-name content rather than a hardcoded case number, so any
% new free-decay control case (e.g. Case7_Free_Decay_OffResonance) is picked
% up automatically without editing this script.
if contains(currentFolder, 'Free_Decay', 'IgnoreCase', true)
    DampingEstimator = true;
elseif contains(currentFolder, 'Chirp', 'IgnoreCase', true)
    FrequencyResponse = true;
end
%% 2. PARSING & UNIFORM RESAMPLING (THE MATHEMATICAL CORE)
fprintf('[*] Loading and resampling CFD data uniformly...\n');

% FORCES
force_data = readmatrix(force_file, 'FileType', 'text', 'CommentStyle', '#');
[time_raw_f, unique_idx_f] = unique(force_data(:, 1));
Fx_raw = force_data(unique_idx_f, 2);
Fy_raw = force_data(unique_idx_f, 3);
Fz_raw = force_data(unique_idx_f, 4);

% MOMENTS
moment_data = readmatrix(moment_file, 'FileType', 'text', 'CommentStyle', '#');
[~, unique_idx_m] = unique(moment_data(:, 1));
Mx_raw = moment_data(unique_idx_m, 2);
My_raw = moment_data(unique_idx_m, 3);
Mz_raw = moment_data(unique_idx_m, 4);

% ALPHA PROBES
alpha_data = readmatrix(alpha_file, 'FileType', 'text', 'CommentStyle', '#');
[time_raw_p, unique_idx_p] = unique(alpha_data(:, 1));
alpha_X_raw = alpha_data(unique_idx_p, 2);
alpha_Y_raw = alpha_data(unique_idx_p, 3);

% --- UNIFORM RESAMPLING (Crucial to fix phase/frequency artifacts) ---
Fs = 200; % Hz
dt = 1 / Fs;
t_start = max(time_raw_f(1), time_raw_p(1));
t_end   = min(time_raw_f(end), time_raw_p(end));
time_f  = (t_start : dt : t_end)';


% Fx_total = interp1(time_raw_f, Fx_raw, time_f, 'spline');
% Fy_total = interp1(time_raw_f, Fy_raw, time_f, 'spline');
% Fz_total = interp1(time_raw_f, Fz_raw, time_f, 'spline');
% Mx_total = interp1(time_raw_f, Mx_raw, time_f, 'spline');
% My_total = interp1(time_raw_f, My_raw, time_f, 'spline');
% Mz_total = interp1(time_raw_f, Mz_raw, time_f, 'spline');

Fx_total = interp1(time_raw_f, Fx_raw, time_f, 'pchip');   % was 'spline'
Fy_total = interp1(time_raw_f, Fy_raw, time_f, 'pchip');
Fz_total = interp1(time_raw_f, Fz_raw, time_f, 'pchip');
Mx_total = interp1(time_raw_f, Mx_raw, time_f, 'pchip');
My_total = interp1(time_raw_f, My_raw, time_f, 'pchip');
Mz_total = interp1(time_raw_f, Mz_raw, time_f, 'pchip');

% Linear interpolation for phases to avoid physical overshoots
alpha_X  = interp1(time_raw_p, alpha_X_raw, time_f, 'linear');
alpha_Y  = interp1(time_raw_p, alpha_Y_raw, time_f, 'linear');

%% 3. FILTER DESIGN FOR CLEAN ORBITS (Chebyshev II SOS Form)
[n_cheby, Wn_cheby] = cheb2ord(3.5/(Fs/2), 5.0/(Fs/2), 0.1, 40);
[z_c, p_c, k_c] = cheby2(n_cheby, 40, Wn_cheby);
[sos_cheby, g_cheby] = zp2sos(z_c, p_c, k_c);

% Zero-phase robust filtering
Fx_clean = filtfilt(sos_cheby, g_cheby, Fx_total);
Fy_clean = filtfilt(sos_cheby, g_cheby, Fy_total);
Mx_clean = filtfilt(sos_cheby, g_cheby, Mx_total);
My_clean = filtfilt(sos_cheby, g_cheby, My_total);

%% 4. FIGURE 1: WAVE PROBES HISTORY (No Filters, Pure Physics)
fig1 = figure('Name', 'Wave Surface Elevation', 'Position', [100, 100, 900, 500], 'Color', 'w');
subplot(2, 1, 1);
plot(time_f, alpha_X, 'Color', C_CORAL, 'LineWidth', 1.8, 'DisplayName', 'X-Probe (Drive Direction)');
grid on; grid minor; ylabel('\alpha_{water} [-]', 'Color', C_DARK);
title('Phase Fraction Elevation \alpha_{water} at Tank Boundary', 'Color', C_DARK);
legend('Location', 'northeast'); set(gca, 'XColor', C_DARK, 'YColor', C_DARK); ylim([-0.05 1.05]);

subplot(2, 1, 2);
plot(time_f, alpha_Y, 'Color', C_TEAL, 'LineWidth', 1.8, 'DisplayName', 'Y-Probe (Swirling Onset)');
grid on; grid minor; xlabel('Time [s]', 'Color', C_DARK); ylabel('\alpha_{water} [-]', 'Color', C_DARK);
legend('Location', 'northeast'); set(gca, 'XColor', C_DARK, 'YColor', C_DARK); ylim([-0.05 1.05]);
saveas(fig1, 'fig1_wave_probes_history.png');

%% 5. FIGURE 2: HYDRODYNAMIC FORCES & SMOOTH ORBIT
fig2 = figure('Name', 'Hydrodynamic Forces', 'Position', [150, 150, 1000, 450], 'Color', 'w');
subplot(1, 2, 1);
plot(time_f, Fx_total, 'Color', C_CORAL, 'DisplayName', 'F_x (Longitudinal)'); hold on;
plot(time_f, Fy_total, 'Color', C_TEAL, 'LineStyle', '--', 'DisplayName', 'F_y (Transverse)');
grid on; grid minor; xlabel('Time [s]', 'Color', C_DARK); ylabel('Force [N]', 'Color', C_DARK);
title('Resampled Hydrodynamic Force Histories', 'Color', C_DARK); legend('Location', 'northeast');
set(gca, 'XColor', C_DARK, 'YColor', C_DARK);

subplot(1, 2, 2);
plot(Fx_clean, Fy_clean, 'Color', C_DARK, 'LineWidth', 1.2, 'DisplayName', 'Filtered Trajectory'); hold on;
idx_late = time_f >= 5.0;
if any(idx_late)
    plot(Fx_clean(idx_late), Fy_clean(idx_late), 'Color', C_SAND, 'LineWidth', 2.2, 'DisplayName', 'Orbit (t \geq 5s)');
end
grid on; grid minor; xlabel('F_x [N]', 'Color', C_DARK); ylabel('F_y [N]', 'Color', C_DARK);
title('Clean Force Hodograph Orbit (F_y vs F_x)', 'Color', C_DARK);
legend('Location', 'northeast'); set(gca, 'XColor', C_DARK, 'YColor', C_DARK);
saveas(fig2, 'fig2_force_orbit.png');

%% 6. FIGURE 3: OVERTURNING MOMENTS & SMOOTH ORBIT
fig3 = figure('Name', 'Hydrodynamic Moments', 'Position', [200, 200, 1000, 450], 'Color', 'w');
subplot(1, 2, 1);
plot(time_f, My_total, 'Color', C_TEAL, 'LineStyle', '--', 'DisplayName', 'M_y (Pitching)'); hold on;
plot(time_f, Mx_total, 'Color', C_CORAL, 'DisplayName', 'M_x (Rolling)');
grid on; grid minor; xlabel('Time [s]', 'Color', C_DARK); ylabel('Moment [N\cdotm]', 'Color', C_DARK);
title('Resampled Overturning Moment Histories', 'Color', C_DARK); legend('Location', 'northeast');
set(gca, 'XColor', C_DARK, 'YColor', C_DARK);

subplot(1, 2, 2);
plot(Mx_clean, My_clean, 'Color', C_CORAL, 'LineWidth', 1.5, 'DisplayName', 'Moment Trajectory');
grid on; grid minor; xlabel('M_x [N\cdotm]', 'Color', C_DARK); ylabel('M_y [N\cdotm]', 'Color', C_DARK);
title('Clean Moment Hodograph Orbit (M_y vs M_x)', 'Color', C_DARK);
legend('Location', 'northeast'); set(gca, 'XColor', C_DARK, 'YColor', C_DARK);
saveas(fig3, 'fig3_moments_orbit.png');

%% 7. FIGURE 4: ADVANCED DSP FFT SPECTRUM
idx_steady = time_f >= 3.0;
Fx_steady = Fx_total(idx_steady) - mean(Fx_total(idx_steady));
N_samples = length(Fx_steady);
N_fft = 8 * 2^nextpow2(N_samples); % High zero-padding for smooth curves

% Window design & Coherent Gain definitions
w_rect = ones(N_samples, 1); cg_rect = mean(w_rect);
w_hann = 0.5 * (1 - cos(2*pi*(0:N_samples-1)'/(N_samples-1))); cg_hann = mean(w_hann);

n_vec = (0:N_samples-1)';
% SRS Flat-Top Window (Perfect Amplitude recovery)
w_flat = 0.21557895 - 0.41663158*cos(2*pi*n_vec/(N_samples-1)) + ...
         0.277263158*cos(4*pi*n_vec/(N_samples-1)) - ...
         0.083578947*cos(6*pi*n_vec/(N_samples-1)) + ...
         0.006947368*cos(8*pi*n_vec/(N_samples-1));
cg_flat = mean(w_flat);

% FFT Calculations
fft_rect = abs(fft(Fx_steady .* w_rect, N_fft)) / (N_samples * cg_rect);
fft_hann = abs(fft(Fx_steady .* w_hann, N_fft)) / (N_samples * cg_hann);
fft_flat = abs(fft(Fx_steady .* w_flat, N_fft)) / (N_samples * cg_flat);

P1_rect = 2 * fft_rect(1:N_fft/2+1);
P1_hann = 2 * fft_hann(1:N_fft/2+1);
P1_flat = 2 * fft_flat(1:N_fft/2+1);
f_axis = Fs * (0:(N_fft/2)) / N_fft;




if strcmpi(erase(currentFolder, fileparts(currentFolder)), 'Case5_Soft_Spring')
    f_theory = 1.291; 
elseif contains(currentFolder, 'Case5', 'IgnoreCase', true)
    f_theory = 1.291;
else
    f_theory = 1.7393;  
end

fig4 = figure('Name', 'Advanced DSP FFT Spectrum Comparison', 'Position', [250, 250, 900, 480], 'Color', 'w');
plot(f_axis, P1_rect, 'Color', C_SAND, 'LineStyle', ':', 'LineWidth', 1.5, 'DisplayName', 'Rectangular Window'); hold on;
plot(f_axis, P1_hann, 'Color', C_CORAL, 'LineStyle', '-', 'LineWidth', 2.0, 'DisplayName', 'Hann Window (Compensated)');
plot(f_axis, P1_flat, 'Color', C_TEAL, 'LineStyle', '-.', 'LineWidth', 1.8, 'DisplayName', 'SRS Flat-Top Window (Exact Amplitude)');
xline(f_theory, 'Color', C_DARK, 'LineStyle', '--', 'LineWidth', 1.8, 'DisplayName', sprintf('Theoretical f_{11} = %.4f Hz', f_theory));
xlim([0, 4]); grid on; grid minor;
xlabel('Frequency [Hz]', 'Color', C_DARK); ylabel('Corrected Force Amplitude [N]', 'Color', C_DARK);
title('FFT Spectrum Comparison with Coherent Gain Compensation (F_x, t \geq 3s)', 'Color', C_DARK);
legend('Location', 'northeast'); set(gca, 'XColor', C_DARK, 'YColor', C_DARK);
saveas(fig4, 'fig4_fft_spectrum.png');

%% 8. FIGURE 5: STFT SPECTROGRAM (CUSTOM COLORMAP & AUTO-SCALING)
fig5 = figure('Name', 'STFT Spectrogram Analysis', 'Position', [300, 300, 900, 500], 'Color', 'w');
window_length = floor(Fs * 4);          % 2-second windows
overlap = floor(window_length * 0.90);  % 90% overlap for maximum fluidity
nfft_stft = 2048;

% Spectrogram Computing
[S, F_stft, T_stft] = spectrogram(Fx_total - mean(Fx_total), window_length, overlap, nfft_stft, Fs);

% Conversion on Decibel
S_dB = 20*log10(abs(S) + 1e-12);

% --- COLOR AUTO-SCALING  ---
max_dB = max(S_dB(:));      % Find the maximum real value
min_dB = max_dB - 40;       % Drops 40 dB from peak (cleans up background noise)

% --- CUSTOM COLORMAP CREATION "SUNNY BEACH DAY" ---
% Logical order: From coldest/darkest (noise) to warmest (energy peaks)
base_colors = [C_DARK; C_TEAL; C_GOLD; C_SAND; C_CORAL]; 
x_base = linspace(0, 1, 5);          % 5 cardinal points
x_query = linspace(0, 1, 256)';      % Smooth gradient
sunny_beach_cmap = interp1(x_base, base_colors, x_query, 'linear'); % Linear interpolation

% Image plot
imagesc(time_f(1) + T_stft, F_stft, S_dB);
axis xy; ylim([0, 3.5]); 
colormap(sunny_beach_cmap); % Apply colormap!
colorbar; 
clim([min_dB, max_dB + 2]); % Perfect dynamic range

title('Time-Frequency Spectrogram of Longitudinal Force F_x(t) [dB]', 'Color', C_DARK);
xlabel('Time [s]', 'Color', C_DARK); ylabel('Frequency [Hz]', 'Color', C_DARK);
set(gca, 'XColor', C_DARK, 'YColor', C_DARK);
saveas(fig5, 'fig5_spectrogram_stft.png');
%% 9. FIGURE 6: CORRECTED STABLE FILTER COMPARISON (FIR vs IIR)
% High-order FIR to prevent amplitude clipping at low frequencies
order_fir = 400; % Increased order for sharp transition at low freq
f_edges = [0, 3.0, 4.5, Fs/2] / (Fs/2);
a_edges = [1, 1, 0, 0];
b_fir = firpm(order_fir, f_edges, a_edges);

Fx_fir = filter(b_fir, 1, Fx_total);
tau_samples = order_fir / 2; % Linear phase delay correction
time_fir = time_f - (tau_samples / Fs);

fig6 = figure('Name', 'Advanced Filter Comparison', 'Position', [350, 350, 950, 500], 'Color', 'w');
plot(time_f, Fx_total, 'Color', C_SAND, 'LineWidth', 1.0, 'DisplayName', 'Raw CFD Force F_x'); hold on;
plot(time_f, Fx_clean, 'Color', C_CORAL, 'LineWidth', 2.0, 'DisplayName', 'IIR Chebyshev II (Zero-Phase SOS)');
plot(time_fir, Fx_fir, 'Color', C_TEAL, 'LineWidth', 1.8, 'LineStyle', '--', 'DisplayName', 'High-Order FIR (Delay Corrected)');
grid on; grid minor; xlim([10.0, 40.00]); % Zoom on established wave
xlabel('Time [s]', 'Color', C_DARK); ylabel('Force F_x [N]', 'Color', C_DARK);
title('Comparison of Digital Filtering Techniques on Resampled Force F_x', 'Color', C_DARK);
legend('Location', 'northeast'); set(gca, 'XColor', C_DARK, 'YColor', C_DARK);
saveas(fig6, 'fig6_filter_comparison.png');

n_figs_base = 6;   % fig1-fig6, always generated

%% 10. DAMPING ESTIMATION (Case6_FreeDecay) -- logarithmic decrement
if DampingEstimator
    t_shutoff = 10.0;                 % s, forcing set to zero after this time
                                       % (must match generate_acceleration.py)
    min_cycles_for_fit = 5;           % refuse to report xi with fewer peaks than this
    envelope_monotonic_tol = 0.05;    % allow 5% non-monotonic "wobble" before flagging

    %% --- Narrow bandpass isolation around the natural frequency ---
    % The FFT restricted to t>10s shows a single clean peak at ~1.73 Hz with
    % no resolvable second frequency, but Fx_clean is only a broadband
    % anti-noise filter (Chebyshev II) -- it does not reject the residual
    % near 0.95*f_theory left over from the forcing phase, nor higher-harmonic
    % content, both of which findpeaks can pick up as spurious peaks and
    % corrupt the log-decrement fit.
    %
    % Filtering BEFORE segmenting (not after) keeps the filter's edge
    % transient at t=0/t=40, away from t_shutoff where the first and
    % largest peaks live.
    f_bp_center    = f_theory;   % 1.7393 Hz; swap for 1.7333 if you prefer the
                                  % frequency actually measured in the decay-only
                                  % FFT instead of the theoretical one
    f_bp_halfwidth = 0.25;       % Hz -- rejects the 0.95*f_theory forced residual
                                  % (~0.14 Hz away) and 2nd-harmonic content while
                                  % keeping the full f_theory lobe
    bp_order       = 4;

    f_lo = max(f_bp_center - f_bp_halfwidth, 0.05);
    f_hi = f_bp_center + f_bp_halfwidth;
    [b_bp, a_bp] = butter(bp_order, [f_lo f_hi] / (Fs/2), 'bandpass');

    Fx_bp = filtfilt(b_bp, a_bp, Fx_clean);   % zero-phase, no lag/lead

    %% Isolate the free-decay segment (on the bandpassed signal)
    decay_mask = time_f > t_shutoff;
    t_decay    = time_f(decay_mask);
    Fx_decay   = Fx_bp(decay_mask);

    %% Find successive peaks (positive envelope)
    [pk_vals, pk_locs] = findpeaks(Fx_decay, t_decay, ...
        'MinPeakDistance', 0.3);   % > half the forcing period, avoids double-counting

    n_peaks = numel(pk_vals);
    fprintf('\n[*] Damping estimation: found %d peaks after shutoff (t > %.1f s).\n', ...
        n_peaks, t_shutoff);

    %% --- Data-quality guard: is this actually decaying? ---
    if n_peaks < min_cycles_for_fit
        warning(['Only %d peaks found after shutoff -- too few to fit a ' ...
            'reliable decay. Do not trust any xi computed below.'], n_peaks);
    end

    % A clean free decay should have pk_vals(i+1) <= pk_vals(i) for
    % (almost) all i. Flag if too many peak-to-peak steps increase instead.
    diffs = diff(pk_vals);
    frac_increasing = sum(diffs > 0) / max(numel(diffs), 1);

    if frac_increasing > envelope_monotonic_tol
        warning(['%.0f%% of successive peak-to-peak steps INCREASE in amplitude ' ...
            '-- this does not look like a clean free decay (possible restart ' ...
            'artifact, discontinuous forcing shut-off, or sustained numerical ' ...
            'noise). Run detect_restart_artifacts.py on FORCES/force.dat and check ' ...
            'constant/acceleration.dat for a smooth taper before trusting xi.'], ...
            100 * frac_increasing);
    end

    %% Logarithmic decrement over the available cycles
    N = n_peaks - 1;
    if N < 1
        error('Not enough peaks to compute a logarithmic decrement.');
    end

    delta = (1/N) * log(pk_vals(1) / pk_vals(end));

    %% Convert to damping ratio
    xi = delta / sqrt(4*pi^2 + delta^2);

    fprintf('\n--- Damping estimation (Case6_FreeDecay) ---\n');
    fprintf('  Peaks used          : %d (N = %d cycles)\n', n_peaks, N);
    fprintf('  First peak amplitude: %.4f N at t = %.3f s\n', pk_vals(1), pk_locs(1));
    fprintf('  Last peak amplitude : %.4f N at t = %.3f s\n', pk_vals(end), pk_locs(end));
    fprintf('  Logarithmic decrement, delta = %.5f\n', delta);
    fprintf('  Damping ratio, xi    = %.5f  (%.3f%% of critical)\n', xi, 100*xi);

    if frac_increasing > envelope_monotonic_tol || n_peaks < min_cycles_for_fit
        fprintf(2, ['  ** WARNING: data-quality checks above failed -- treat this ' ...
            'xi as unreliable until the underlying data is verified. **\n']);
    end

    %% FIGURE 7: Logarithmic decrement fit
    fig7 = figure('Name', 'Case6 - Logarithmic Decrement Fit', ...
        'Position', [400, 400, 900, 480], 'Color', 'w');
    plot(t_decay, Fx_decay, 'Color', C_SAND, 'LineWidth', 1.0, ...
        'DisplayName', 'F_x (filtered, post-shutoff)'); hold on;
    plot(pk_locs, pk_vals, 'o', 'Color', C_CORAL, 'MarkerFaceColor', C_CORAL, ...
        'DisplayName', 'Detected peaks');

    omega_n = 2 * pi * f_theory;   % reuse the natural frequency already defined above
    A0 = pk_vals(1);
    t_fit = linspace(pk_locs(1), pk_locs(end), 200);
    env_fit = A0 * exp(-xi * omega_n * (t_fit - pk_locs(1)));
    plot(t_fit, env_fit, 'Color', C_DARK, 'LineStyle', '--', 'LineWidth', 1.8, ...
        'DisplayName', 'Fitted envelope');
    plot(t_fit, -env_fit, 'Color', C_DARK, 'LineStyle', '--', 'LineWidth', 1.8, ...
        'HandleVisibility', 'off');

    grid on; grid minor;
    xlabel('Time [s]', 'Color', C_DARK); ylabel('F_x [N]', 'Color', C_DARK);
    title(sprintf('Free Decay Fit: \\xi = %.4f (%.2f%% of critical)', xi, 100*xi), ...
        'Color', C_DARK);
    legend('Location', 'northeast'); set(gca, 'XColor', C_DARK, 'YColor', C_DARK);
    saveas(fig7, 'fig7_damping_estimation.png');

    fprintf('[SUCCESS] Damping estimation figure saved (fig7_damping_estimation.png).\n');
end

%% 11. FREQUENCY RESPONSE FUNCTION H(f) -- Case0_Chirp modal identification

if FrequencyResponse
    % Requires Signal Processing Toolbox (tfestimate, mscohere).

    %% Reconstruct the input signal a(t) on the same uniform time grid
    % constant/acceleration.dat has the same 6-DOF format used elsewhere in
    % the campaign: (t ((ax ay az) (wx wy wz) (dwx dwy dwz)))
    accel_file = fullfile('constant', 'acceleration.dat');
    if ~isfile(accel_file)
        error('Cannot find %s -- required to reconstruct the chirp input.', accel_file);
    end

    fid = fopen(accel_file, 'r');
    raw = fread(fid, '*char')';
    fclose(fid);

    % Extract all "(t ((ax ..." numeric triplets with a simple regexp: capture
    % time and ax (first component of the first vector group) per line.
    tokens = regexp(raw, '\(\s*([\d.eE+-]+)\s*\(\(\s*([\d.eE+-]+)', 'tokens');
    accel_raw = cellfun(@(c) [str2double(c{1}), str2double(c{2})], tokens, ...
        'UniformOutput', false);
    accel_raw = cell2mat(accel_raw');   % [time, ax]

    t_accel = accel_raw(:, 1);
    ax_accel = accel_raw(:, 2);

    % Resample the input onto the same uniform grid as the response (time_f)
    ax_input = interp1(t_accel, ax_accel, time_f, 'linear', 0);

    fprintf('[*] Reconstructed chirp input: %d samples, range [%.3f, %.3f] s\n', ...
        numel(ax_input), t_accel(1), t_accel(end));

    %% Welch-based transfer function estimate H(f) = Sxy(f) / Sxx(f)
    % x = input acceleration a(t), y = response force Fx(t)
    win_len = round(4 * Fs);          % 4 s windows -> ~0.25 Hz resolution
    noverlap = round(win_len * 0.75); % 75% overlap
    nfft_h = 4096;

    [H, f_h] = tfestimate(ax_input, Fx_total, hann(win_len), noverlap, nfft_h, Fs);
    [Cxy, f_c] = mscohere(ax_input, Fx_total, hann(win_len), noverlap, nfft_h, Fs);

    %% FIGURE 8: Frequency Response Function |H(f)| with coherence
    fig8 = figure('Name', 'Case0 - Frequency Response Function', ...
        'Position', [450, 450, 950, 600], 'Color', 'w');

    subplot(3, 1, 1);
    plot(f_h, abs(H), 'Color', C_CORAL, 'LineWidth', 1.8);
    grid on; grid minor; xlim([0, 4]);
    ylabel('|H(f)| [N/(m/s^2)]', 'Color', C_DARK);
    title('Frequency Response Function |F_x(f) / a(f)| -- Chirp Modal Identification', ...
        'Color', C_DARK);
    set(gca, 'XColor', C_DARK, 'YColor', C_DARK);

    subplot(3, 1, 2);
    plot(f_h, angle(H) * 180/pi, 'Color', C_TEAL, 'LineWidth', 1.8);
    grid on; grid minor; xlim([0, 4]); ylim([-180, 180]);
    ylabel('Phase [deg]', 'Color', C_DARK);
    set(gca, 'XColor', C_DARK, 'YColor', C_DARK);

    subplot(3, 1, 3);
    plot(f_c, Cxy, 'Color', C_DARK, 'LineWidth', 1.8); hold on;
    yline(0.9, 'Color', C_SAND, 'LineStyle', '--', 'DisplayName', 'Reliability threshold (0.9)');
    grid on; grid minor; xlim([0, 4]); ylim([0, 1.05]);
    xlabel('Frequency [Hz]', 'Color', C_DARK); ylabel('Coherence \gamma^2', 'Color', C_DARK);
    legend('Location', 'southeast');
    set(gca, 'XColor', C_DARK, 'YColor', C_DARK);

    saveas(fig8, 'fig8_frequency_response_function.png');

    %% Peak-picking: report candidate natural frequencies where coherence is high
    [pk_H, pk_f] = findpeaks(abs(H), f_h, 'MinPeakProminence', max(abs(H))*0.1);
    fprintf('\n--- Candidate resonances from H(f) (Case0_Chirp) ---\n');
    for i = 1:numel(pk_f)
        coh_at_peak = interp1(f_c, Cxy, pk_f(i));
        flag = '';
        if coh_at_peak < 0.9
            flag = '  <-- LOW COHERENCE: likely not a real structural/fluid mode';
        end
        fprintf('  f = %.4f Hz | |H| = %.4f | coherence = %.3f%s\n', ...
            pk_f(i), pk_H(i), coh_at_peak, flag);
    end

    fprintf(['\nOnly trust peaks in |H(f)| where coherence is close to 1 -- low ' ...
        'coherence at a given frequency means the output is not linearly ' ...
        'related to the (known) input there, i.e. it is likely numerical ' ...
        'noise or an unrelated disturbance rather than a genuine resonance.\n']);
end

%% 12. WRAP-UP
n_figs_total = n_figs_base + DampingEstimator + FrequencyResponse;
fprintf('\n[SUCCESS] Unified Engine finished! %d high-quality figure(s) generated.\n', ...
    n_figs_total);