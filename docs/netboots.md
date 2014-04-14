Gentoo Netboots Without NFS
===========================
source: http://forums.gentoo.org/viewtopic-p-7420452.html

Basically, if you wanna PXE boot gentoo without having to use NFS, you have to 
patch the minimal live cd's initramfs so that the kernel can find the squash
filesystem.

The patch gets updated at the forums whenever the minimal install introduces a 
change to the init script that breaks the previous patch.

The basic steps needed to patch the initramfs (AKA the ramdisk):

  1. Unpack the cpio ramdisk file included in the minimal livecd
  2. Edit the init file to work with the squashfs file system included
  3. Add the squashfs image to the unpacked ramdisk image.
  4. Re-cpio gzip the ramdisk image
  5. Add image entry to pxe server. 

While you're at it, get a copy of the kernel out. Once the patch is applied and 
the ramdisk is re-cpioed, place the kernel and the patched ramdisk on a tftp 
server.

As for PXE booting, that has to be supported by the target system. If it is, 
change the BIOS setting to do network booting, and ensure your DHCP server is 
passing options to notify nodes of the location of the tftp server and the 
bootloader file.  That's pretty much it.

