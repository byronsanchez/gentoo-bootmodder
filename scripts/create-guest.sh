#!/usr/bin/env sh
#
# Creates a KVM guest for gentoo

name=$1

# Create the guest image
qemu-img create -f qcow2 -o preallocation=metadata "$name.img" 50G

# Launch installation inside screen
screen -d -m virt-install --connect qemu:///system --name "$name.img" \
--cpuset=1 --ram 4048 \
--vcpus=2 --network bridge=br0 --disk \
path="$name.img,format=qcow2,bus=virtio" \
--pxe --accelerate --hvm --vnc --noautoconsole --os-type=linux \
--os-variant=virtio26 --keymap=en_us

