#!/bin/bash
#SBATCH --job-name=Case0_Chirp
#SBATCH --output=output.out
#SBATCH --error=error.err
#SBATCH --ntasks=32
#SBATCH --exclusive
#SBATCH -x antani,tarapia
#SBATCH --threads-per-core=1

rm -rf postProcessing
openfoam-docker / postProcess -func wallForces -time '0:80'
openfoam-docker / postProcess -func waveProbes -time '0:80'

rm -rf FORCES
mkdir -p FORCES

cat $(ls -v postProcessing/wallForces/*/force*.dat 2>/dev/null) > FORCES/force.dat
cat $(ls -v postProcessing/wallForces/*/moment*.dat 2>/dev/null) > FORCES/moment.dat
cat $(ls -v postProcessing/waveProbes/*/alpha.water* 2>/dev/null) > FORCES/alpha.water
cat $(ls -v postProcessing/waveProbes/*/p_rgh* 2>/dev/null) > FORCES/p_rgh
