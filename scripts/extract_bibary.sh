#!/bin/sh

# Download from https://www.kakip.ai/software/
IMG=kakip-es2_ubuntu_base_v5.img 

SCRIPT_DIR=$(cd $(dirname $0);pwd)
OVERLAY_DIR=${SCRIPT_DIR}/../overlay/bootloader/opt/

dd if=${IMG} of=${OVERLAY_DIR}/header0.bin count=80 bs=1
dd if=${IMG} of=${OVERLAY_DIR}/header1.bin skip=1 count=1
dd if=${IMG} of=${OVERLAY_DIR}/bl2.bin skip=8 count=398
