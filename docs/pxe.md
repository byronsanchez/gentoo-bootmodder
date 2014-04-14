PXE Notes

(This doc is not finished, so it's not exactly linear...these are basically 
random notes that I want to have as a resource)

EL and Debian based systems have a nice set of tools, collectively known as
Cobbler. Cobbler allows administrators to perform unattended installations and
configurations of those installs. By automating this process, you get to have a 
much higher level of confidence that each of the nodes on a network are 
provisioned in the way you want it. Plus, automation simplifies and reduces 
work.

I wanted to do this for gentoo, so I hacked together my own system for
unattended installation using several already-existing tools.

Here's a rundown of how the booting processes may work.

You determine your boot device. A boot device can be a cd, a usb or even a
network! I believe network is best when you have your initial "provisioning"
node online. To setup the initial provisioning node, I use a usb stick. Once the
provisioner is setup, I use PXE for network booting and provisioning of all the
other servers.

1. First system provisioned via usb stick
2. All other systems via network

TODO: Mention how to learn about bootloaders

To set PXE booting up, you'll need several components:

TFTP server
DHCP server
Network-booting capable BIOS (seabios, used by qemu/kvm, has this)

The way PXE works is

1. DHCP request is made by the BIOS of the node being booted
2. DHCP server responds to  the DHCP request. The response contains extra
information about where the bootloader and kernel are (the host that contains
them and the path)
3. The BIOS makes a tftp request to the host that the DHCP server said has the
files. If the request is succesful, BIOS downloads the files and boots the OS.
Otherwise, a timeout occurs and the next boot device is tried.

Once booted, you can install gentoo linux.

You can only have one DHCP server on a network. For me, my DHCP server is on my
router. If this is the case for you, make sure your router allows you to add
DHCP options. I use dd-wrt, and dd-wrt allows you to set DHCP options.
I use dnsmasq for my DHCP server, so the options are placed in the dnsmasq 
section NOT the dhcp section. This is unintuitive, but it makes sense if you 
think about it.

also, for ddwrt, I had to put:

dhcp-no-override
dhcp-boot=/pxelinux.0,[hostname (optional)],[tftpserver-ip]

The no override part was required. Without it, pxe booting did not work.

Autoinstallation scripts are invoked by the init scripts using the local.d
directory.

