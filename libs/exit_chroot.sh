#!/usr/bin/env bash
# A library for cleaning up after exiting chroot

ctrl_c() {
    echo
    echo "${color_red} Exiting chroot and cleaning up..."
    sleep 0.5
    unset input
    rm /tmp/chroot_dir.var &> /dev/null
    clear
    # TODO: Fix possible errors with run not being sourced yet
    run reboot-menu
}