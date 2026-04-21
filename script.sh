#!/bin/bash

# ./script.sh 
# 1 = BLOCK SIZE 
# 2 = COMPRESSION LEVEL 
# 3 = COMP OR DECOMP 
# 4 = SHIM OR ZLIB

# Test parameters
BLOCKSIZE=${1:-65536}
LEVEL=${2:-1}
SERVICE=${3:-comp}
TYPE=${4:-zlib}
HUFFMAN="dynamic"

rm -rf result*

if [ -z "$QATZIP_TEST_PATH" ]; then
    echo "ERROR: QATZIP_TEST_PATH environment variable is not set"
    exit 1
fi

if [ ! -f "$QATZIP_TEST_PATH" ]; then
    echo "ERROR: QATZIP_TEST_PATH does not exist: $QATZIP_TEST_PATH"
    exit 1
fi

if [ "$TYPE" == "shim" ]; then
    if [ -z "$SHIM_PATH" ]; then
        echo "ERROR: SHIM_PATH environment variable is not set"
        exit 1
    fi
    if [ ! -f "$SHIM_PATH" ]; then
        echo "ERROR: LD_PRELOAD path does not exist: $SHIM_PATH"
        exit 1
    fi
    export LD_PRELOAD="$SHIM_PATH"
else 
    unset LD_PRELOAD
fi

CORPUS_PATH="calgary_corpus"
CORPUS="calgary" # name for results table

if [ ! -f "$CORPUS_PATH" ]; then
    echo "$CORPUS_PATH directory does not exist, creating it using the following commands"
    echo "  wget http://corpus.canterbury.ac.nz/resources/calgary.tar.gz"
    echo "  tar -xzf calgary.tar.gz"
    echo "  cat bib book1 book2 geo news obj1 obj2 paper1 paper2 pic progc progl progp trans > $CORPUS_PATH"
    wget http://corpus.canterbury.ac.nz/resources/calgary.tar.gz 
    tar -xzf calgary.tar.gz
    cat bib book1 book2 geo news obj1 obj2 paper1 paper2 pic progc progl progp trans > $CORPUS_PATH
fi

NUM_PROCESS=1
NUM_THREADS=1
NUM_CORES=1

if [ "$SERVICE" == "comp" ]; then
    numactl -C 4 $QATZIP_TEST_PATH -m 4 -l 100 -t $NUM_THREADS -B 1 -D $SERVICE -L $LEVEL -i $CORPUS_PATH -T $HUFFMAN -C $BLOCKSIZE -g none > result_raw_0 2> result_stderr_0 &
    echo "numactl -C 4 $QATZIP_TEST_PATH -m 4 -l 100 -t $NUM_THREADS -B 1 -D $SERVICE -L $LEVEL -i $CORPUS_PATH -T $HUFFMAN -C $BLOCKSIZE -g none > result_raw_0 2> result_stderr_0 &"
else 
    numactl -C 4 $QATZIP_TEST_PATH -m 4 -l 100 -t $NUM_THREADS -B 1 -D $SERVICE -L $LEVEL -i $CORPUS_PATH -T $HUFFMAN -C $BLOCKSIZE  -O gzip -g none > result_raw_0 2> result_stderr_0 &
    echo "numactl -C 4 $QATZIP_TEST_PATH -m 4 -l 100 -t $NUM_THREADS -B 1 -D $SERVICE -L $LEVEL -i $CORPUS_PATH -T $HUFFMAN -C $BLOCKSIZE -O gzip  -g none > result_raw_0 2> result_stderr_0 &"
fi

if [ "$TYPE" == "shim" ]; then
    unset LD_PRELOAD
fi

# Wait for all processes to complete
wait

# Combine results from all processes
cat result_raw_* > result_raw 2>/dev/null
# done

# Wait for completion
wait

RESULT_TABLE="performance_table_$TYPE.tsv"

# Parse results and calculate average throughput
if [ -f result_raw ]; then
    # Extract throughput values (in Gbps) and calculate average
    if [ "$SERVICE" == "comp" ]; then
        THROUGHPUT=$(grep "srv=COMP" result_raw | awk '{print $8}' | awk '{sum+=$1; count++} END {printf "%.4f", sum/count}')
    else 
        THROUGHPUT=$(grep "srv=DECOMP" result_raw | awk '{sum+=$8} END {printf "%.2f", sum}')
    fi
    # Create table header if doesn't exist
    if [ ! -f $RESULT_TABLE ]; then
        echo -e "CaseID\tCorpus\tService\tLevel\tBlocksize(Byte)\tHuffman Type\tNumTestProcess\tSW Throughput w/ ${NUM_CORES} Cores\tNumThread\tComp Ratio\tTYPE" > $RESULT_TABLE
    fi

    if [ "$SERVICE" == "comp" ]; then
        RATIO=$(grep "srv=COMP" result_raw | awk -F'ratio=' '{print $2}' | awk -F'%' '{sum+=$1; count++} END {printf "%.2f%%", sum/count}')
    else
        RATIO="-"
    fi

    # Append results
    CASE_ID=$(wc -l < $RESULT_TABLE)
    CASE_ID=$((CASE_ID - 1))
    echo -e "${CASE_ID}\t${CORPUS}\t${SERVICE}\t${LEVEL}\t${BLOCKSIZE}\t${HUFFMAN}\t${NUM_PROCESS}\t${THROUGHPUT}\t${NUM_THREADS}\t${RATIO}\t${TYPE}" >> $RESULT_TABLE
    
    echo "Results added to $RESULT_TABLE"
    tail -1 $RESULT_TABLE
fi
