# Structure

Contents of this folder is used for building docker image/container needed for compiling Anarchy ISO.

# Building image

Docker image contains `add-aur.sh` and `setup.sh` files.
`docker-compile.sh` would be executed from inside container but it is not embedded into image/container.

To build a new image from `project root` run:

```bash
$ docker build -t anarchy:latest .
```

To remove image:

```bash
$ docker rmi anarchy:latest
```

# Publishing image (optional)

If you will, you can push created image to docker hub. Anarchy doesn't maintain an official docker image.

```bash
$ docker tag anarchy:latest <username>/anarchy:latest
$ docker tag <username>/anarchy:latest <username>/anarchy:"$(date +%F)"
```

Publish image:

```bash
$ docker login
# Enter username/password
$ docker push <username>/anarchy:"$(date +%F)"
$ docker push <username>/anarchy:latest
```

Replace `<username>` with your own `username` on docker hub.

# Compiling ISO

It is recommended to run the `compile.sh` script from `project root` with `-d` flag. If `anarchy:latest` docker image doesn't exist, it would be created:

```bash
$ ./compile.sh -d
```

To build an `ISO` image using [Docker](https://www.docker.com) you need to map project root folder to `/anarchy` inside docker container to do so run the following command from `project root`:

```bash
$ docker run --rm --privileged \
    --device-cgroup-rule='b 7:* rmw' \
    -v "${PWD}":/project \
    -e anarchy_iso_label=ANARCHY10 \
    -e anarchy_iso_release=1.0.10 \
    anarchy:latest
```

When compilation is completed you can find Anarchy `ISO` image under `[project root]/out`.

You can start a fresh container and walk trough the process with:

```bash
$ docker run --rm --privileged \
    --device-cgroup-rule='b 7:* rmw' \
    -v "${PWD}":/project \
    -e anarchy_iso_label=ANARCHY10 \
    -e anarchy_iso_release=1.0.10 \
    -it anarchy:latest
```

# Testing ISO

Use a virtualization software to test Anarchy bootable `ISO`.

For example using [QEMU](https://www.qemu.org) without a hard-disk on `Arch Linux` the command is like:

```bash
$ qemu-system-x86_64 -m 2048M -cdrom ./out/anarchy-1.0.10-x86_64.iso
```

Replace `anarchy-1.0.10-x86_64.iso` with desired Anarchy ISO in above command.

# Known issues

- [WARNING:](https://unix.stackexchange.com/questions/460043/how-can-i-successfully-build-an-archiso-image-airootfs-is-not-a-mountpoint) work/x86_64/airootfs is not a mountpoint. This may have undesirable side effects.
