#!/bin/bash

# 1. Install qatzip and ISA-L
# 2. Set correct paths for SHIM_PATH and QATZIP_TEST_PATH below
# 3. Run run.sh to execute all tests and generate results in CSV format

export QATZIP_TEST_PATH="./qatzip-test"
export SHIM_PATH="/home/vkarpenk/isal/qatzip/QATzip/test/gnr/isa-l/build/igzip/shim/isal-shim.so"

for size in 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288; do ./script.sh $size 1 comp zlib; done
for size in 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288; do ./script.sh $size 9 comp zlib; done
for size in 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288; do ./script.sh $size 1 decomp zlib; done
for size in 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288; do ./script.sh $size 9 decomp zlib; done

for size in 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288; do ./script.sh $size 1 comp shim; done
for size in 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288; do ./script.sh $size 9 comp shim; done
for size in 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288; do ./script.sh $size 1 decomp shim; done
for size in 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288; do ./script.sh $size 9 decomp shim; done

for f in *.tsv; do sed 's/\t/,/g' "$f" > "${f%.tsv}.csv"; done

# download results performance_table_zlib.csv and performance_table_shim.csv