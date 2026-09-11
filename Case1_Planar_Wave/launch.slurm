#!/bin/bash
#SBATCH --job-name=Case1_Planar
#SBATCH --output=output.out
#SBATCH --error=error.err
#SBATCH --ntasks=32
#SBATCH --exclusive
#SBATCH -x antani,tarapia
#SBATCH --threads-per-core=1

echo "========================================="
echo " CASE START:  CYlindric 3D Sloshing"
echo " Solver    :  interIsoFoam (v2412)"
echo " Cores     :  32"
echo "========================================="

# 0. ALet's make sure Allrun is executable
chmod +x Allrun #Allclean

# 1. Launch mesh generation, initialization and execution
./Allrun

# 2. When Allrun finishes, we run integrity checks
echo "--- Simulation completion check ---"

ENDTIME_EXPECTED="40"

# We extract the last time actually written to processor0 (excluding the "0" folder)
LATEST_TIME=$(ls -d processor0/[0-9]* 2>/dev/null | sed 's#processor0/##' | grep -v '^0$' | sort -n | tail -n 1)

echo "   -> Expected end time (ENDTIME): $ENDTIME_EXPECTED"
echo "   -> Last time written to disk: $LATEST_TIME"

# Check if the last time matches the expected ENDTIME (tolerance < 0.001)
TIME_CHECK=$(awk -v t1="$LATEST_TIME" -v t2="$ENDTIME_EXPECTED" 'BEGIN { if (t1 != "" && (t2 - t1) < 0.001 && (t1 - t2) < 0.001) print "yes"; else print "no" }')

# Let's check if the log ends properly with "End"
LOG_END=$(tail -n 50 interIsoFoam.log 2>/dev/null | grep -q "End" && echo "yes" || echo "no")

if [ "$LOG_END" = "yes" ] && [ "$TIME_CHECK" = "yes" ]; then

    echo ">>> Simulation completed successfully at time $ENDTIME_EXPECTED s! Starting post-processing..."

    echo "   1. Mesh Reconstruction (if AMR is active)..."
    openfoam-docker / reconstructParMesh -constant > reconstructParMesh.log 2>&1

    echo "   2. Reconstruction of the fields (reconstructPar -latestTime)..."
    openfoam-docker / reconstructPar > reconstructPar.log 2>&1

    echo "   3. Extracting Force, Moment and Probe logs..."
    rm -rf FORCES
    mkdir -p FORCES

    # CONCATENATING RESTART FILES FOR MATLAB

    echo "   -> Merging restart files into continuous datasets..."
    
    cat $(ls -v postProcessing/wallForces/*/force*.dat 2>/dev/null) > FORCES/force.dat
    cat $(ls -v postProcessing/wallForces/*/moment*.dat 2>/dev/null) > FORCES/moment.dat
    cat $(ls -v postProcessing/waveProbes/*/alpha.water* 2>/dev/null) > FORCES/alpha.water
    cat $(ls -v postProcessing/waveProbes/*/p_rgh* 2>/dev/null) > FORCES/p_rgh

    echo "   4. Creating files for ParaView..."
    touch results.foam

    echo "   5. Cleaning processors directories..."
    rm -rf processor*

    echo "========================================="
    echo ">>> 3D SLOSHING CASE SUCCESSFULLY COMPLETED."
    echo "========================================="

else
    echo "========================================================================="
    echo "!!! FATAL ERROR: The simulation did NOT reach the time $ENDTIME_EXPECTED"
    echo "    or did not terminate properly. The raw data 'processor*' is"
    echo "    been kept intact to allow for debugging."
    echo "========================================================================="
    exit 1
fi