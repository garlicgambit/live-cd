#!/bin/sh

# Script for Qubes with normal tails system

#################
### Variables ###
#################

iso_file=/run/initramfs/live/custom/image.iso
iso_mountpoint=/mnt
tails_vm=tails
tails_vm_ram=1024

#####################
### System checks ###
#####################

# Check if iso is available
if [ ! -e "${iso_file}" ]; then
  echo "Error: The ISO file is not available."
  exit 0
fi

# Check if mountpoint is available
if mountpoint -q "${iso_mountpoint}"; then
  echo "Error: The ${iso_mountpoint} is already mounted."
  exit 0
fi

#################
### Mount ISO ###
#################

# Mount iso file at loop device
sudo mount "${iso_file}" "${iso_mountpoint}" -o loop
loop_device="$(losetup --associated ${iso_file} --list --raw --output NAME --noheadings)"

################
### Tails VM ###
################

# Create Tails VM
qvm-create "${tails_vm}" --hvm --label green --mem "${tails_vm_ram}" --quiet

# Start Tails VM
qvm-start "${tails_vm}" --cdrom="${loop_device}" --quiet
