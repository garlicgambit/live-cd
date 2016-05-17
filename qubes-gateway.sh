#!/bin/sh

# Script for Qubes with tails-workstation/tails-gateway setup

#################
### Variables ###
#################

iso_file=/run/initramfs/live/custom/image.iso
iso_mountpoint=/mnt
tails_gateway_vm=tails-gateway
tails_workstation_vm=tails-workstation
tails_gateway_vm_ram=1024
tails_workstation_vm_ram=1024
boot_timeout=40

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

#####################
### Tails-gateway ###
#####################

# Create Tails-gateway
qvm-create "${tails_gateway_vm}" --hvm --label red --mem "${tails_gateway_vm_ram}" --quiet

# Start Tails-gateway
qvm-start "${tails_gateway_vm}" --cdrom="${loop_device}" --quiet

# Wait for Tails-gateway to boot
sleep "${boot_timeout}"

#########################
### Tails-workstation ###
#########################

# Create Tails-workstation
qvm-create "${tails_workstation_vm}" --hvm --label green --mem "${tails_workstation_vm_ram}" --quiet

# Remove default net-firewall connection
qvm-prefs "${tails_workstation_vm}" --set netvm none

# Start Tails-workstation
qvm-start "${tails_workstation_vm}" --cdrom="${loop_device}" --quiet

# Wait for Tails-workstation to boot
sleep "${boot_timeout}"

######################
### Create network ###
######################

# Create network between Tails-gateway and Tails-workstation
# Note: this might give an error, but should work
xl network-attach "${tails_workstation_vm}" script=/xen/scripts/vif-route-qubes backend="${tails_gateway_vm}"

# Check for error code on xl command.
# Notify user that the network interfaces should be available.
if [ "$?" -ne 0 ]; then
  echo
  echo "Despite the previous error, the network interfaces should be available."
  echo
fi
