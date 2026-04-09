#!/bin/bash

# Test parameters
CORPUS="calgary"
SERVICE="comp"
LEVEL=9
BLOCKSIZE=${1:-65536}
HUFFMAN="dynamic"

rm -rf result*

# export LD_PRELOAD="/root/vkarpenk/isa-l-2.32.0/build/igzip/shim/isal-shim.so"

# NUM_PROCESS=2
# NUM_THREADS=32
# NUM_CORES=64
# numactl -C 0-31 ./qatzip-test -m 4 -l 100 -t $NUM_THREADS -B 1 -D $SERVICE -L $LEVEL -i calgary_corpus -T $HUFFMAN -C $BLOCKSIZE -O gzip  -g none > result_raw_0 2> result_stderr_0 &
# numactl -C 32-63 ./qatzip-test -m 4 -l 100 -t $NUM_THREADS -B 1 -D $SERVICE -L $LEVEL -i calgary_corpus -T $HUFFMAN -C $BLOCKSIZE -O gzip  -g none > result_raw_1 2> result_stderr_1 &



NUM_PROCESS=1
NUM_THREADS=1
NUM_CORES=1
numactl -C 4 ./../qatzip-test -m 4 -l 100 -t $NUM_THREADS -B 1 -D $SERVICE -L $LEVEL -i ../calgary_corpus -T $HUFFMAN -C $BLOCKSIZE -g none > result_raw_0 2> result_stderr_0 &
echo "numactl -C 4 ./../qatzip-test -m 4 -l 100 -t $NUM_THREADS -B 1 -D $SERVICE -L $LEVEL -i ../calgary_corpus -T $HUFFMAN -C $BLOCKSIZE -g none > result_raw_0 2> result_stderr_0 &"

# unset LD_PRELOAD

# Wait for all processes to complete
wait

# Combine results from all processes
cat result_raw_* > result_raw 2>/dev/null
# done

# Wait for completion
wait

RESULT_TABLE="performance_table_amd-zlib-nt-gnrd.tsv"

# Parse results and calculate average throughput
if [ -f result_raw ]; then
    # Extract throughput values (in Gbps) and calculate average
    THROUGHPUT=$(grep "srv=COMP" result_raw | awk '{print $8}' | awk '{sum+=$1; count++} END {printf "%.4f", sum/count}')
    
    # Gbps to MB/s: Gbps * 1000 / 8 = MB/s
    # THROUGHPUT=$(grep "srv=COMP" result_raw | awk '{print $8}' | awk '{sum+=$1} END {printf "%.2f", sum}')
    # THROUGHPUT=$(grep "srv=DECOMP" result_raw | awk '{sum+=$8} END {printf "%.2f", sum}')

    # Create table header if doesn't exist
    if [ ! -f $RESULT_TABLE ]; then
        echo -e "CaseID\tCorpus\tService\tLevel\tBlocksize(Byte)\tHuffman Type\tNumTestProcess\tSW Throughput w/ ${NUM_CORES} Cores\tNumThread\tComp Ratio\tBlock size" > $RESULT_TABLE
    fi

    RATIO=$(grep "srv=COMP" result_raw | awk -F'ratio=' '{print $2}' | awk -F'%' '{sum+=$1; count++} END {printf "%.2f%%", sum/count}')
    echo "Average Compression Ratio: ${RATIO}"

    # Append results
    CASE_ID=$(wc -l < $RESULT_TABLE)
    CASE_ID=$((CASE_ID - 1))
    echo -e "${CASE_ID}\t${CORPUS}\t${SERVICE}\t${LEVEL}\t${BLOCKSIZE}\t${HUFFMAN}\t${NUM_PROCESS}\t${THROUGHPUT}\t${NUM_THREADS}\t${RATIO}\t${BLOCKSIZE}" >> $RESULT_TABLE
    
    echo "Results added to $RESULT_TABLE"
    tail -1 $RESULT_TABLE
fi
