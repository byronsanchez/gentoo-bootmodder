#!/bin/sh
#
# Packages modified iso extracts into bootable media.

source ./helpers/common.lib.sh;

WORKDIR="`pwd`"
PROVISIONS="$WORKDIR/profiles"

# Initialize our own variables:
list=0
name=""
usb=0
pxe=0
quiet=0

############################
# Argument Parsing Functions

function show_help ()
{
cat <<-EOM

$0 [OPTION]

options:

    -l --list        list available provision profiles
    -n --name=NAME   name of provision profile for which to build a bootable device
    -u --usb         create a bootable usb device
    -p --pxe         create a bootable pxe device
    -q --quiet       do not log messages to STDOUT
    -h --help        display this message

EOM
    exit 1
}

function get_options () {
    argv=()
    while [ $# -gt 0 ]
    do
        opt=$1
        shift
        case ${opt} in
            -n|--name)
                name=$1
                shift
                ;;
            --name=*)
                name=$(echo ${opt} | cut -d'=' -f 2);
                ;;
            -l|--list)
                list=1
                ;;
            -u|--usb)
                usb=1
                ;;
            -p|--pxe)
                pxe=1
                ;;
            -q|--quiet)
                quiet=1
                ;;
            -h|--help)
                show_help
                ;;
            *)
                if [ "${opt:0:1}" = "-" ]; then
                    fail "${opt}: unknown option."
                fi
                argv+=(${opt});;
        esac
    done 
}

###########################
# DEVICE CREATION FUNCTIONS

# TODO (for each device):
# - Implement the bootable installation portion (?) (this is the bootloader
# version of "packaging")

function archive_ramdisk () {
  workdir="$1";
  cpiodir="$workdir/extracts/initramfs/ramdisk";

  info "archiving ramdisk to $workdir/extracts/initramfs/gentoo.igz";

  if [ -f "$workdir/extracts/initramfs/gentoo.igz" ];
  then
    rm -rf "$workdir/extracts/initramfs/gentoo.igz";
  fi

  cd $workdir/extracts/initramfs/ramdisk;
  find . -print | cpio -H newc -o | xz --check=crc32 > ../gentoo.igz;

  success "ramdisk archived to $workdir/extracts/initramfs/gentoo.igz";
}

function archive_squashfs () {
  workdir="$1";
  squashfsdir="$workdir/extracts/squashfs/squashfs-root";

  info "archiving squashfs to $workdir/extracts/squashfs/image.squashfs";

  if [ -f "$workdir/extracts/squashfs/image.squashfs" ];
  then
    rm -rf "$workdir/extracts/squashfs/image.squashfs";
  fi

  cd $workdir/extracts/squashfs;
  mksquashfs $squashfsdir image.squashfs -noappend -always-use-fragments;

  success "squashfs archived to $workdir/extracts/squashfs/image.squashfs";
}

function apply_mods () {
  moddir=$1;
  builddir=$2;
  devicedir=$3;
  buildramfsdir="$builddir/extracts/initramfs";
  buildsquashfsdir="$builddir/extracts/squashfs";
  modsramfsdir="$moddir/initramfs";
  modssquashfsdir="$moddir/squashfs";
  modsusbbootloaderdir="$moddir/bootloader-usb";
  modspxebootloaderdir="$moddir/bootloader-pxe";

  # Apply profile mods
  if [ -d "$modssquashfsdir" ];
  then
    cp -r $modssquashfsdir/* $buildsquashfsdir/squashfs-root;
  fi
  if [ -d "$modsramfsdir" ];
  then
    cp -r $modsramfsdir/* $buildramfsdir/ramdisk;
  fi
  if [ -d "$modsusbbootloaderdir" ];
  then
    cp -r $modsusbbootloaderdir/* $devicedir;
  fi
  if [ -d "$modspxebootloaderdir" ];
  then
    cp -r $modspxebootloaderdir/* $devicedir;
  fi
}

# Packages all extracted files into a bootable usb device
build_usb_device () {
  provisiondir="$PROVISIONS/$1";
  builddir="$provisiondir/.build";
  isodir="$provisiondir/extracts/iso";
  ramfsdir="$provisiondir/extracts/initramfs";
  squashfsdir="$provisiondir/extracts/squashfs";
  buildramfsdir="$builddir/extracts/initramfs";
  buildsquashfsdir="$builddir/extracts/squashfs";
  devicedir="$provisiondir/devices/usb";

  info "building bootable usb device";

  # Build the device tree
  if [ ! -d "$devicedir" ];
  then
    mkdir -p "$devicedir";
  fi
  cp -r $isodir/* $devicedir;
  # Modify the device tree so that it conforms to that of a usb boot device
  mv $devicedir/isolinux/* $devicedir;
  mv $devicedir/isolinux.cfg $devicedir/syslinux.cfg;
  rm -rf $devicedir/isolinux*;
  mv $devicedir/memtest86 $devicedir/memtest;
  # Allow the usb flash drive to settle upon detection
  sed -i -e "s:cdroot:cdroot slowusb:" -e "s:kernel memtest86:kernel memtest:" $devicedir/syslinux.cfg;

  # Create a build directory where we can copy and modify the source extracts.
  rm -rf $builddir;
  mkdir -p $builddir/extracts;

  # Original sources to build dir
  cp -r $squashfsdir $builddir/extracts;
  cp -r $ramfsdir $builddir/extracts;

  # apply global mods
  apply_mods $WORKDIR/mods $builddir $devicedir;
  # apply provision-specific mods
  apply_mods $provisiondir/mods $builddir $devicedir;

  # Squashify and cpioify
  archive_squashfs ${builddir};
  archive_ramdisk ${builddir};
  # Output to usb device
  cp $buildsquashfsdir/image.squashfs $devicedir;
  cp $buildramfsdir/gentoo.igz $devicedir;

  # Clean up build dir
  rm -rf $builddir;

  success "bootable usb device located at $devicedir";
}

# Packages all extracted iso files into a bootable pxe device.
build_pxe_device () {
  provisiondir="$PROVISIONS/$1";
  builddir="$provisiondir/.build";
  isodir="$provisiondir/extracts/iso";
  ramfsdir="$provisiondir/extracts/initramfs";
  squashfsdir="$provisiondir/extracts/squashfs";
  buildramfsdir="$builddir/extracts/initramfs";
  buildsquashfsdir="$builddir/extracts/squashfs";
  modsramfsdir="$provisiondir/mods/initramfs";
  modssquashfsdir="$provisiondir/mods/squashfs";
  modsbootloaderdir="$provisiondir/mods/bootloader";
  devicedir="$provisiondir/devices/pxe";

  info "building bootable pxe device";

  # Build the device tree
  if [ ! -d "$devicedir" ];
  then
    mkdir -p "$devicedir";
  fi
  cp /usr/share/syslinux/pxelinux.0 $devicedir;
  cp /usr/share/syslinux/ldlinux.c32 $devicedir;
  cp /usr/share/syslinux/menu.c32 $devicedir;
  cp /usr/share/syslinux/libutil.c32 $devicedir;
  cp $isodir/isolinux/gentoo $devicedir;
  mkdir $devicedir/pxelinux.cfg;
  cat > $devicedir/pxelinux.cfg/default << EOF
default menu.c32
prompt 0
timeout 100

label linux
  kernel gentoo
  append initrd=gentoo.igz root=/dev/ram0 init=/linuxrc loop=image.squashfs looptype=squashfs cdroot=1 real_root=/
EOF

  # Create a build directory where we can copy and modify the source extracts.
  rm -rf $builddir;
  mkdir -p $builddir/extracts;

  # Original sources to build dir
  cp -r $squashfsdir $builddir/extracts;
  cp -r $ramfsdir $builddir/extracts;

  # apply global mods
  apply_mods $WORKDIR/mods $builddir $devicedir;
  # apply provision-specific mods
  apply_mods $provisiondir/mods $builddir $devicedir;

  # Squashify
  archive_squashfs ${builddir};
  # PXE needs the squashfs INSIDE the cpio file
  cp ${buildsquashfsdir}/image.squashfs ${buildramfsdir}/ramdisk;
  # NOW, cpioify
  archive_ramdisk ${builddir};
  # Output to PXE device
  cp $buildramfsdir/gentoo.igz $devicedir;

  # Clean up build dir
  rm -rf $builddir;

  success "bootable pxe device located at $devicedir";
}

# TODO: Complete this function.
# This function is currently unfinished, but it is going to build a bootable
# live CD modded with any additions in the provision profile.
function build_iso_device () {

  workdir="`pwd`/$1"
  isodir="$workdir/iso"

  if [ -f "$workdir/output.iso" ];
  then
    rm -rf "$workdir/output.iso"
  fi

  rm -rf $isodir/isolinux/boot.cat

  cd $isodir
  mkisofs -no-emul-boot -boot-load-size 4 -boot-info-table -r -b isolinux/isolinux.bin -c isolinux/boot.cat -o /mnt/output.iso .

}

#############
# MAIN SCRIPT

# Parse options if they were passed
get_options $*

if [ "$list" == 1 ];
then
  filelist="";
  for filename in $PROVISIONS/*;
  do
    echo "FN: $filename"
    filelist="$filelist  - ${filename##*/}\n";
  done
  printf "Available provision profiles for which bootable devices may be built:\n";
  printf "\n";
  printf "${filelist}\n";
  exit 0;
fi

if [ ! -n "$name" ];
then
  fail "Please provide a provision profile name so that a bootable device can be built";
fi

if [ "$usb" == 1 ];
then
  build_usb_device $name;
fi

if [ "$pxe" == 1 ];
then
  build_pxe_device $name;
fi

