#
# Copyright 2016, Intel Corporation
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in
#       the documentation and/or other materials provided with the
#       distribution.
#
#     * Neither the name of the copyright holder nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
# pmempool_sync/TEST6 -- test for checking pmempool sync;
#                        with device dax
#
[CmdletBinding(PositionalBinding=$false)]
Param(
    [alias("d")]
    $DIR = ""
    )
$Env:UNITTEST_NAME = "pmempool_sync\TEST6"
$Env:UNITTEST_NUM = "6"

. ..\unittest\unittest.ps1

require_test_type medium
require_dax_devices 1
require_fs_type any

setup

dax_device_zero

$LOG = "out${Env:UNITTEST_NUM}.log"
$LOG_TEMP = "out${Env:UNITTEST_NUM}_part.log"
rm $LOG -Force -ea si
touch $LOG
rm $LOG_TEMP -Force -ea si
touch $LOG_TEMP

$LAYOUT = "OBJ_LAYOUT"
$POOLSET = "$DIR/pool1.set"
$HDR_LEN = "4096"

# Create poolset file
create_poolset $POOLSET `
	20M:$DIR/part00:x `
	r `
	AUTO:${Env:DEVICE_DAX_PATH[0]}:x

# CLI script for writing some data hitting all the parts
$WRITE_SCRIPT = "$DIR/write_data"
echo @"
pr 1M
srcp 0 TestOK111
"@ | out-file -encoding ASCII $WRITE_SCRIPT

# CLI script for reading 9 characters from all the parts
$READ_SCRIPT = "$DIR/read_data"
echo @"
srpr 0 9
"@ | out-file -encoding ASCII $READ_SCRIPT

# Create poolset1
expect_normal_exit $PMEMPOOL create --layout=$LAYOUT obj $POOLSET >> $LOG_TEMP

# Write some data into the pool, hitting all part files
expect_normal_exit $PMEMOBJCLI -s $WRITE_SCRIPT $POOLSET >> $LOG_TEMP

# Check if correctly written
expect_normal_exit $PMEMOBJCLI -s $READ_SCRIPT $POOLSET >> $LOG_TEMP

# Clear part header on the dax device
expect_normal_exit $DDMAP -o ${Env:DEVICE_DAX_PATH[0]} -l $HDR_LEN

# Synchronize replicas
expect_normal_exit $PMEMPOOL sync $POOLSET >> $LOG_TEMP

# Check if correctly written
expect_normal_exit $PMEMOBJCLI -s $READ_SCRIPT $POOLSET >> $LOG_TEMP

# Check metadata by pmempool info
dump_pool_info $POOLSET >> $LOG_TEMP
dump_pool_info $DIR/part00 >> $LOG_TEMP
dump_pool_info ${Env:DEVICE_DAX_PATH[0]} >> $LOG_TEMP

mv -Force $LOG_TEMP $LOG
check

pass
