# Structure

Contents of this folder is used for building docker image/container needed for compiling Anarchy ISO.

# Building image

Docker image contains `add-aur.sh` and `setup.sh` files.
`docker-compile.sh` would be executed from inside container but it is not embedded into image/container.

To build a new image from `project root` run:

```bash
$ docker build -t remisa/anarchy:latest .
```

# Tagging and publishing image

Tag generated image:

```bash
$ docker tag remisa/anarchy:latest remisa/anarchy:"$(date +%F)"
```

Publish image:

```bash
$ docker login
# Enter username/password
$ docker push remisa/anarchy:"$(date +%F)"
$ docker push remisa/anarchy:latest
```

# Compiling ISO

It is recommended to run the `compile.sh` script from `project root` with `-d` flag:

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
    remisa/anarchy:latest
```

When compilation is completed you can find Anarchy `ISO` image under `[project root]/out`.

You can start a fresh container and walk trough the process with:

```bash
$ docker run --rm --privileged \
    --device-cgroup-rule='b 7:* rmw' \
    -v "${PWD}":/project \
    -e anarchy_iso_label=ANARCHY10 \
    -e anarchy_iso_release=1.0.10 \
    -it remisa/anarchy:latest
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
