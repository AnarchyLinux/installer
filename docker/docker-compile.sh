#!/usr/bin/env bash

######## DON'T RENAME THIS FILE ########
# Don't run this script directly. Run 'compile.sh' from
# project root. It will set requiredenvironment variables.

# This script would be executed from inside docker container and
# copies scripts and other stuff from project to docker container.
# From inside docker container, [project root] is accessible at '/project' path.
# This script would be executed as 'root' inside container. Non root user is 'builder'.

# Viriables

project_dir="/project"
custom_iso="${project_dir}"/customiso
squashfs="${custom_iso}"/arch/x86_64/squashfs-root
out_dir="${project_dir}"/out # Directory for generated ISO

# Label must be up to 11 chars long (incremental numbers)
# anarchy_iso_label="ANARCHY10" # from ENV
# anarchy_iso_release="1.0.10"  # from ENV
anarchy_iso_name="anarchy-${anarchy_iso_release}-x86_64.iso"

init() {
    # Check for existing Arch iso
    if (ls "${project_dir}"/archlinux-*-x86_64.iso &>/dev/null); then
        # Outputs Arch iso filename prev: iso
        local_arch_iso="$(ls "${project_dir}"/archlinux-*-x86_64.iso | tail -n1 | sed 's!.*/!!')"
    fi

    if [ ! -d "${out_dir}" ]; then
        mkdir "${out_dir}"
    fi

    # Remove existing Anarchy iso with same name
    if [ -e "${out_dir}"/"${anarchy_iso_name}" ]; then
        rm "${out_dir}"/"${anarchy_iso_name}"
    fi
}

extract_arch_iso() {
    cd "${project_dir}" || exit

    if [ -d "${custom_iso}" ]; then
        rm -rf "${custom_iso}"
    fi

    echo -e "\nExtracting Arch Linux image ...\n"

    if [ -f "${local_arch_iso}" ]; then
        # Extract Arch iso to mount directory and continue with build
        7z x "${local_arch_iso}" -o"${custom_iso}"
        echo -e "Done extracting image\n"
    else
        echo -e "Error: \"${local_arch_iso}\" is missing\!\n"
        exit 2
    fi
}

copy_config_files() {
    # Change directory into the iso, where the filesystem is stored.
    # Unsquash root filesystem 'airootfs.sfs', this creates a directory 'squashfs-root' containing the entire system
    echo "Unsquashing Arch image ..."
    cd "${custom_iso}"/arch/x86_64 || exit
    unsquashfs airootfs.sfs
    echo "Done unsquashing airootfs.sfs"
    echo ""

    echo "Adding console and locale config files to iso ..."
    # Copy over vconsole.conf (sets font at boot), locale.gen (enables locale(s) for font) & uvesafb.conf
    cp "${project_dir}"/etc/vconsole.conf "${project_dir}"/etc/locale.gen "${squashfs}"/etc/
    arch-chroot "${squashfs}" /bin/bash locale-gen

    # Copy over main Anarchy config and installer script, make them executable
    echo "Adding anarchy config and installer scripts to iso ..."
    cp "${project_dir}"/etc/anarchy.conf "${project_dir}"/etc/pacman.conf "${squashfs}"/etc/
    cp "${project_dir}"/anarchy-installer.sh "${squashfs}"/usr/bin/anarchy
    cp "${project_dir}"/extra/sysinfo "${project_dir}"/extra/iptest "${squashfs}"/usr/bin/
    chmod +x "${squashfs}"/usr/bin/anarchy "${squashfs}"/usr/bin/sysinfo "${squashfs}"/usr/bin/iptest

    # Create Anarchy and lang directories, copy over all lang files
    echo "Adding language files to iso ..."
    mkdir -p "${squashfs}"/usr/share/anarchy/lang "${squashfs}"/usr/share/anarchy/extra "${squashfs}"/usr/share/anarchy/boot "${squashfs}"/usr/share/anarchy/etc
    cp "${project_dir}"/lang/* "${squashfs}"/usr/share/anarchy/lang/

    # Create shell function library, copy /lib to squashfs-root
    echo "Adding anarchy scripts to iso ..."
    mkdir "${squashfs}"/usr/lib/anarchy
    cp "${project_dir}"/lib/* "${squashfs}"/usr/lib/anarchy/

    # Copy over extra files (dot files, desktop configurations, help file, issue file, hostname file)
    echo -e "Adding dot files and desktop configurations to iso ..."
    rm "${squashfs}"/root/install.txt
    cp "${project_dir}"/extra/shellrc/.zshrc "${squashfs}"/root/
    cp "${project_dir}"/extra/.help "${project_dir}"/extra/.dialogrc "${squashfs}"/root/
    cp "${project_dir}"/extra/shellrc/.zshrc "${squashfs}"/etc/zsh/zshrc
    cp -r "${project_dir}"/extra/shellrc/. "${squashfs}"/usr/share/anarchy/extra/
    cp -r "${project_dir}"/extra/desktop "${project_dir}"/extra/fonts "${project_dir}"/extra/anarchy-icon.png "${squashfs}"/usr/share/anarchy/extra/
    cat "${project_dir}"/extra/.helprc | tee -a "${squashfs}"/root/.zshrc >/dev/null
    cp "${project_dir}"/etc/hostname "${project_dir}"/etc/issue_cli "${squashfs}"/etc/
    cp -r "${project_dir}"/boot/splash.png "${project_dir}"/boot/loader/ "${squashfs}"/usr/share/anarchy/boot/
    cp "${project_dir}"/etc/nvidia340.xx "${squashfs}"/usr/share/anarchy/etc/

    if [ -d branding ]; then
        cp "${project_dir}"/branding/wallpapers/* "${squashfs}"/usr/share/anarchy/extra/wallpapers/
    else
        echo "Missing branding directory, skipping ..."
    fi

    # Copy over built packages and create repository
    echo "Adding built AUR packages to iso ..."
    mkdir "${custom_iso}"/arch/x86_64/squashfs-root/usr/share/anarchy/pkg

    for pkg in $(echo "${local_aur_packages[@]}"); do
        cp /tmp/"${pkg}"/*.pkg.tar.xz "${squashfs}"/usr/share/anarchy/pkg/
    done

    cd "${squashfs}"/usr/share/anarchy/pkg || exit
    repo-add anarchy-local.db.tar.gz *.pkg.tar.xz
    cd "${project_dir}" || exit

    echo "Done adding files to iso"
    echo ""
}

build_system() {
    echo "Installing packages to new system ..."
    # Install fonts, fbterm, fetchmirrors etc.
    # TODO: Make packages offline if possible
    pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg --noconfirm -Sy terminus-font acpi zsh-syntax-highlighting pacman-contrib
    pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > "${custom_iso}"/arch/pkglist.x86_64.txt
    pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg --noconfirm -Scc
    rm -f "${squashfs}"/var/cache/pacman/pkg/*
    echo "Done installing packages to new system"
    echo ""

    # cd back into root system directory, remove old system
    cd "${custom_iso}"/arch/x86_64 || exit
    rm airootfs.sfs

    # Recreate the iso using compression, remove unsquashed system, generate checksums
    echo "Recreating Anarchy image ..."
    mksquashfs squashfs-root airootfs.sfs -b 1024k -comp xz
    rm -r squashfs-root
    md5sum airootfs.sfs > airootfs.md5
    echo "Done recreating Anarchy image"
    echo ""
}

configure_boot() {
    echo "Configuring boot ..."
    arch_iso_label="$(<"${custom_iso}"/loader/entries/archiso-x86_64.conf awk 'NR==6{print $NF}' | sed 's/.*=//')"
    arch_iso_hex="$(<<<"${arch_iso_label}" xxd -p)"
    anarchy_iso_hex="$(<<<"${anarchy_iso_label}" xxd -p)"
    cp "${project_dir}"/boot/splash.png "${custom_iso}"/arch/boot/syslinux/
    cp "${project_dir}"/boot/iso/archiso_head.cfg "${custom_iso}"/arch/boot/syslinux/
    sed -i "s/${arch_iso_label}/${anarchy_iso_label}/;s/Arch Linux archiso/Anarchy Linux/" "${custom_iso}"/loader/entries/archiso-x86_64.conf
    sed -i "s/${arch_iso_label}/${anarchy_iso_label}/;s/Arch Linux/Anarchy Linux/" "${custom_iso}"/arch/boot/syslinux/archiso_sys.cfg
    sed -i "s/${arch_iso_label}/${anarchy_iso_label}/;s/Arch Linux/Anarchy Linux/" "${custom_iso}"/arch/boot/syslinux/archiso_pxe.cfg
    cd "${custom_iso}"/EFI/archiso/ || exit
    echo -e "Replacing label hex in efiboot.img...\n${arch_iso_label} ${arch_iso_hex} > ${anarchy_iso_label} ${anarchy_iso_hex}"
    xxd -c 256 -p efiboot.img | sed "s/${arch_iso_hex}/${anarchy_iso_hex}/" | xxd -r -p > efiboot1.img
    if ! (xxd -c 256 -p efiboot1.img | grep "${anarchy_iso_hex}" &>/dev/null); then
        echo -e "\nError: failed to replace label hex in efiboot.img"
        echo -e "Press any key to continue."
        read input
    fi
    mv efiboot1.img efiboot.img
    echo "Done configuring boot"
    echo ""
}

create_iso() {
    echo "Creating new Anarchy image ..."
    cd "${project_dir}" || exit
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "${anarchy_iso_label}" \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -isohybrid-mbr customiso/isolinux/isohdpfx.bin \
        -eltorito-alt-boot \
        -e EFI/archiso/efiboot.img \
        -no-emul-boot -isohybrid-gpt-basdat \
        -output "${out_dir}"/"${anarchy_iso_name}" \
        "${custom_iso}"

    if [ "$?" -eq 0 ]; then
        rm -rf "${custom_iso}"
        generate_checksums
        chmod -R a+rwX "${out_dir}"
        # chown -R :users "${out_dir}"
    else
        echo "Error: Image creation failed, exiting."
        exit 4
    fi
}

generate_checksums() {
    echo "Generating image checksum ..."
    cd "${out_dir}"
    echo -e "$(sha256sum "${anarchy_iso_name}")" > "${anarchy_iso_name}".sha256sum
    echo "Done generating image checksum"
    echo ""
}


init
extract_arch_iso
copy_config_files
build_system
configure_boot
create_iso

echo -e "\"${anarchy_iso_name}\" image generated successfully. Check 'out' directory.\n"
exit 0
