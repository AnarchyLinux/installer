# Installation instructions


## Verifying the checksum

It's recommended that you verify the checksum before using Anarchy.

On Linux, this is a very simple thing to do.
Run the following command in a terminal:

`sha256sum -c anarchy-(version)-(architecture).iso.sha256sum`

If the image (ISO file) was fully and correctly downloaded you should see
something like this:

`anarchy-1.0.10-x86_64.iso: OK`

On Windows you have to get some external tools.
An example is `sha256sum.exe`, which you can run in `cmd` like so:

`sha256sum.exe anarchy-(version)-(architecture).iso`

Note that unlike its Linux counterpart, it will only display the sha256
checksum of the image, not compare it with the generated checksums as well.
So make sure to open the .sha256sum file in a text editor and compare the
hashes yourself.


## Flashing to a USB

### Linux

The fastest method, although not the easiest for most beginners,
is to use `dd`.

Replace `x` with your USB device's letter (use `lsblk` to check which letter
it was assigned, usually it's 'b'):

`sudo dd if=<anarchy-image.iso> of=/dev/sdx status=progress conv=fsync`

You can also use GUI based software such as
[Etcher](https://www.balena.io/etcher/).

### Windows

The best tool to flash Anarchy Linux to a USB is
[Win32DiskImager](https://sourceforge.net/projects/win32diskimager/).
Download it, choose the Anarchy image (ISO), select the wanted USB and
press write.


## Booting up

Once you boot up the installer, you'll be shown a simple TUI menu, listing
all the available installer options.

If you don't intend to do any advanced configuration, we recommend you
connect to wifi using `wifi-menu` (or skip this if you're connected over
ethernet) and then update Anarchy with `anarchy -u`.

Once the update is completed you can start the installer with `anarchy` or by
typing `1` into the terminal.

You can type `start` at any time to show the main menu again.

