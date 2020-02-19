# A library for cleaning up after exiting chroot
ctrl_c() {
    echo ""
    echo "Exiting chroot and cleaning up..."
    sleep 0.5
    unset input
    rm /tmp/chroot_dir.var &> /dev/null
    clear
    run reboot-menu
}
# TODO: Fix everything