#!/bin/sh
#
# Imports a minimal install iso image to be modified.

source ./helpers/common.lib.sh;

WORKDIR="`pwd`";

# Initialize our own variables:
name="";
image="";
clean=0;
quiet=0;

############################
# Argument Parsing Functions

function show_help ()
{
cat <<-EOM

$0 [OPTION]

options:

    -n --name=NAME    name to give the provision profile
    -i --image=NAME   url or path of the iso image to import
    -c --clean        removes the provision profile; if mods exist, they are preserved
    -q --quiet        do not log messages to STDOUT
    -h --help         display this message

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
            -i|--image)
                image=$1
                shift
                ;;
            --image=*)
                image=$(echo ${opt} | cut -d'=' -f 2);
                ;;
            -c|--clean)
                clean=1
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
                argv+=(${opt})
                ;;
        esac
    done 
}

##################
# IMPORT FUNCTIONS

function safe_profile_clean () {
  profilepath="${WORKDIR}/profiles/$1";
  preservepath="mods";

  for filename in $profilepath/*;
  do
    if [ "${filename##*/}" != "$preservepath" ];
    then
      rm -rf "$filename";
    fi
  done
}

function import_image () {

  # Determine image location based on protocol if any
  isFileRemote=$(printf "${image}" | sed -nE '/((https?|ftps?):\/\/)/p');

  if [ -n "$isFileRemote" ];
  then
    # Download the iso file to target dir
    info "fetching gentoo image from ${image}... ";
    wget ${image} -O ${extractdir}/original.iso;
    success " - ${image} downloaded to ${extractdir}/original.iso";
  else
    # Copy the file to target dir
    info "copying gentoo image from ${image}... ";
    cp ${image} ${extractdir}/original.iso;
    success "${image} copied to ${extractdir}/original.iso";
  fi
}

# TODO: Test performing a clean

function extract_iso () {

  iso="$1/images/original.iso";
  dest="$1/extracts";

  info "extracting contents from iso $iso";

  # Make all necessary directories.

  if [ ! -d "tmp" ];
  then
    mkdir tmp;
  fi

  if [ ! -d "$dest/iso" ];
  then
    mkdir -p $dest/iso;
  fi

  if [ ! -d "$dest/initramfs" ];
  then
    mkdir -p $dest/initramfs;
  fi

  if [ ! -d "$dest/squashfs" ];
  then
    mkdir -p $dest/squashfs;
  fi

  # Grab the LiveCD's filesystem, ramfilesystem and kernel
  mount -o loop $iso tmp;
  cp -r tmp/* $dest/iso;
  cp -r tmp/image.squashfs $dest/squashfs;
  cp -r tmp/isolinux/gentoo.igz $dest/initramfs;
  cp -r tmp/isolinux/gentoo $dest/initramfs;

  # Done with image. Clean up
  umount tmp;
  rmdir tmp;

  success "extracted iso contents to $dest";
}

function extract_ramdisk () {
  workdir="$1";
  cpiofilepath="$workdir/extracts/initramfs/gentoo.igz";

  info "extracting contents from ramdisk";

  if [ -d "$workdir/extracts/initramfs/ramdisk" ];
  then
    rm -rf $workdir/extracts/initramfs/ramdisk;
  fi

  mkdir $workdir/extracts/initramfs/ramdisk;
  cd $workdir/extracts/initramfs/ramdisk;
  xzcat "$cpiofilepath" | cpio -ivmd;

  success "extracted ramdisk contents to $workdir/extracts/initramfs/ramdisk";
}

function extract_squashfs () {
  workdir="$1";
  squashfilepath="$workdir/extracts/squashfs/image.squashfs";

  info "extracting contents from squashfs";

  if [ -d "$workdir/extracts/squashfs/squashfs-root" ];
  then
    rm -rf $workdir/extracts/squashfs/squashfs-root;
  fi

  cd $workdir/extracts/squashfs;
  unsquashfs $squashfilepath;

  success "extracted squashfs contents to $workdir/extracts/squashfs/squashfs-root";
}

#############
# MAIN SCRIPT

# Parse options if they were passed
get_options $*

if [ "$clean" == 1 ] && [ -n "$name" ];
then
  safe_profile_clean $name;
  exit 0;
elif [ "$clean" == 1 ] && [ ! -n "$name" ];
then
  fail "please provide a name of an existing provision profile to clean";
  exit 1;
fi

if [ ! -n "$image" ];
then
  fail "Please provide the url to a Gentoo minimal installation iso file"
fi

if [ ! -n "$name" ];
then
  name="${image##*/}";
  name="${name%.iso}";
  printf "No name provided for provision profile. Defaulting to filename 
  \"$name\"\n"
fi

provisiondir="${WORKDIR}/profiles/${name}"
extractdir="${provisiondir}/images"

# Check  for a previous existing profile
if [ -d "$provisiondir" ];
then
  # only preserve the existing provision profile if a mods directory exists
  # and it is not empty. otherwise, delete the currently existing profile and
  # rebuild everything since this data is derived from the iso image.
  if [ -d "$provisiondir/mods" ];
  then
    warn "file previously extracted and mods exist in profile! performing safe import";
    safe_profile_clean "${name}";
  else
    # If there are no mods, just remove everything from the provision profile
    rm -rf "$provisiondir"
  fi
fi

if [ ! -d "$extractdir" ];
then
  mkdir -p "$extractdir";
fi

import_image ${provisiondir};

extract_iso ${provisiondir};

extract_ramdisk ${provisiondir};

extract_squashfs ${provisiondir};

