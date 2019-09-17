#!/usr/bin/env bash

# Stop shellcheck from spamming to declare and assign separately (not important in our case)
# shellcheck disable=SC2155

###############################################################
### Anarchy Linux Install Script
### iso-generator.sh
###
### Copyright (C) 2018 Dylan Schacht
###
### By: Dylan Schacht (deadhead)
### Email: deadhead3492@gmail.com
### Webpage: https://anarchylinux.org
###
### Any questions, comments, or bug reports may be sent to above
### email address. Enjoy, and keep on using Anarchy.
###
### License: GPL v2.0
###############################################################

# Error codes:
# * Exit 1: Missing dependencies (check_dependencies)
# * Exit 2: Missing Arch iso (update_arch_iso)
# * Exit 3: Missing wget (update_arch_iso)
# * Exit 4: Failed to create iso (create_iso)

# Exit on error
set -o errexit

# Enable tracing of what gets executed
#set -o xtrace

# Set up proper logging
working_dir=$(pwd) # prev: aa
log_dir="${working_dir}"/log
log_file="${log_dir}/install-$(date +%d%m%y).log"

if [[ -d ${log_dir} ]]; then
    mkdir ${log_dir}
fi

# Clears the screen and adds a banner
prettify() {
    clear
    echo "-- Anarchy Linux --"
    echo ""
}

set_version() {
    # Label must be 11 characters long
    anarchy_iso_label="ANARCHYV105" # prev: iso_label
    anarchy_iso_release="1.0.5" # prev: iso_rel
    anarchy_iso_name="anarchy-${anarchy_iso_release}-${system_architecture}.iso" # prev: version
}

init() {
    # Location variables
    custom_iso="${working_dir}"/customiso # prev: customiso
    squashfs="${custom_iso}"/arch/"${system_architecture}"/squashfs-root # prev: sq

    # Check for existing Arch iso
    if (ls "${working_dir}"/archlinux-*-"${system_architecture}".iso &>/dev/null); then
        local_arch_iso=$(ls "${working_dir}"/archlinux-*-"${system_architecture}".iso | tail -n1 | sed 's!.*/!!') # Outputs Arch iso filename prev: iso
    fi

    # Link to AUR snapshots
    aur_snapshot_link="https://aur.archlinux.org/cgit/aur.git/snapshot/" # prev: aur

    # Packages to add to local repo
    local_aur_packages=( # prev: builds
        'fetchmirrors'
        'numix-icon-theme-git'
        'numix-circle-icon-theme-git'
        'oh-my-zsh-git'
        'opensnap'
        'perl-linux-desktopfiles'
        'obmenu-generator'
        'yay'
    )

    check_dependencies
    update_arch_iso
    local_repo_builds
}

check_dependencies() { # prev: check_depends
    echo "Checking dependencies ..." | tee ${log_file}
    if [[ ! -f /usr/bin/wget ]]; then dependencies="$dependencies wget "; fi
    if [[ ! -f /usr/bin/xorriso ]]; then dependencies+="libisoburn "; fi
    if [[ ! -f /usr/bin/mksquashfs ]]; then dependencies+="squashfs-tools "; fi
    if [[ ! -f /usr/bin/7z ]]; then dependencies+="p7zip " ; fi
    if [[ ! -f /usr/bin/arch-chroot ]]; then dependencies+="arch-install-scripts "; fi
    if [[ ! -f /usr/bin/xxd ]]; then dependencies+="xxd "; fi
    if [[ ! -f /usr/bin/gtk3-demo ]]; then dependencies+="gtk3 "; fi
    if [[ ! -f /usr/bin/rankmirrors ]]; then dependencies+="pacman-contrib "; fi
    if [[ ! -z "$dependencies" ]]; then
        echo "Missing dependencies: ${dependencies}" | tee ${log_file}
        echo "Install them now? [y/N]: " | tee ${log_file}
        read -r input | tee ${log_file}

        case ${input} in
            y|Y|yes|YES|Yes)
                for pkg in ${dependencies}; do
                    echo "Installing ${pkg}" | tee ${log_file}
                    sudo pacman -Sy ${pkg}
                    echo "${pkg} installed" | tee ${log_file}
                done
                ;;
            *)
            echo "Error: Missing dependencies, exiting." | tee ${log_file}
            exit 1
            ;;
        esac
    fi
    echo "Done"
    echo ""
}

update_arch_iso() { # prev: update_iso
    update=false

    # Check for latest Arch Linux iso
    if [[ "${system_architecture}" == "x86_64" ]]; then
        arch_iso_latest=$(curl -s https://www.archlinux.org/download/ | grep "Current Release" | awk '{print $3}' | sed -e 's/<.*//') # prev: archiso_latest
        arch_iso_link="https://mirrors.kernel.org/archlinux/iso/${arch_iso_latest}/archlinux-${arch_iso_latest}-x86_64.iso" # prev: archiso_link
    else
        arch_iso_latest=$(curl -s https://mirror.archlinux32.org/archisos/ | grep -o ">.*.iso<" | tail -1 | sed 's/>//;s/<//')
        arch_iso_link="https://mirror.archlinux32.org/archisos/${arch_iso_latest}"
    fi

    echo "Checking for updated Arch Linux image ..." | tee ${log_file}
    iso_date=$(<<<"${arch_iso_link}" sed 's!.*/!!')
    if [[ "${iso_date}" != "${local_arch_iso}" ]]; then
        if [[ -z "${local_arch_iso}" ]]; then
            echo "No Arch Linux image found under ${working_dir}" | tee ${log_file}
            echo "Download it? [y/N]: " | tee ${log_file}
            read -r input | tee ${log_file}

            case "${input}" in
                y|Y|yes|YES|Yes) update=true ;;
                *) echo "Error: anarchy-creator requires an Arch Linux image located in: ${working_dir}, exiting." | tee ${log_file}
                exit 2
                ;;
            esac
        else
            echo "Updated Arch Linux image available: ${arch_iso_latest}" | tee ${log_file}
            echo "Download it? [y/N]: " | tee ${log_file}
            read -r input | tee ${log_file}

            case "${input}" in
                y|Y|yes|YES|Yes) update=true ;;
                *) echo -e "Using old image: ${local_arch_iso}" | tee ${log_file}
                sleep 1
                ;;
            esac
        fi

        if "${update}" ; then
            cd "${working_dir}" || exit
            echo ""
            echo "Downloading Arch Linux image ..." | tee ${log_file}
            echo "(Don't resize the window or it will mess up the progress bar)"
            wget -c -q --show-progress "${arch_iso_link}"
            if [[ "$?" -gt "0" ]]; then
                echo "Error: You need 'wget' to download the image, exiting." | tee ${log_file}
                exit 3
            fi
            local_arch_iso=$(ls "${working_dir}"/archlinux-*-"${system_architecture}".iso | tail -n1 | sed 's!.*/!!')
        fi
    fi
    echo "Done" | tee ${log_file}
    echo ""
}

local_repo_builds() { # prev: aur_builds
    echo "Updating pacman databases ..." | tee ${log_file}
    sudo pacman -Sy
    echo "Done updating pacman databases" | tee ${log_file}

    echo "Building AUR packages for local repo ..." | tee ${log_file}

    # Begin build loop checking /tmp for existing builds, then build packages & install if required
    for pkg in $(echo "${local_aur_packages[@]}"); do
        if [[ ! -d "/tmp/${pkg}" ]]; then
            echo "Downloading ${pkg} ..." | tee ${log_file}
            wget -qO- "${aur_snapshot_link}/${pkg}.tar.gz" | tar xz -C /tmp
            cd /tmp/"${pkg}" || exit
            echo "Making ${pkg} ..." | tee ${log_file}
            case "${pkg}" in
                perl-*|numix-*) makepkg -si --needed --noconfirm ;;
                *) makepkg -s ;;
            esac
            echo "${pkg} added successfully" | tee ${log_file}
        fi
    done

    echo "Done making packages" | tee ${log_file}
    echo ""
}

extract_arch_iso() { # prev: extract_iso
    cd "${working_dir}" || exit | tee ${log_file}

    if [[ -d "${custom_iso}" ]]; then
        sudo rm -rf "${custom_iso}"
    fi

    echo "Extracting Arch Linux image ..." | tee ${log_file}

    # Extract Arch iso to mount directory and continue with build
    7z x "${local_arch_iso}" -o"${custom_iso}"

    echo "Done extracting image" | tee ${log_file}
    echo ""
}

copy_config_files() { # prev: build_conf
    # Change directory into the iso, where the filesystem is stored.
    # Unsquash root filesystem 'airootfs.sfs', this creates a directory 'squashfs-root' containing the entire system
    echo "Unsquashing ${system_architecture} image ..." | tee ${log_file}
    cd "${custom_iso}"/arch/"${system_architecture}" | tee ${log_file} || exit
    sudo unsquashfs airootfs.sfs
    echo "Done unsquashing airootfs.sfs" | tee ${log_file}
    echo ""

    echo "Copying Anarchy files ..." | tee ${log_file}
    # Copy over vconsole.conf (sets font at boot), locale.gen (enables locale(s) for font) & uvesafb.conf
    sudo cp "${working_dir}"/etc/vconsole.conf "${working_dir}"/etc/locale.gen "${squashfs}"/etc/ | tee ${log_file}
    sudo arch-chroot "${squashfs}" /bin/bash locale-gen | tee ${log_file}

    # Copy over main Anarchy config and installer script, make them executable
    sudo cp "${working_dir}"/etc/anarchy.conf "${squashfs}"/etc/ | tee ${log_file}
    sudo cp "${working_dir}"/anarchy-installer.sh "${squashfs}"/usr/bin/anarchy | tee ${log_file}
    sudo cp "${working_dir}"/extra/sysinfo "${working_dir}"/extra/iptest "${squashfs}"/usr/bin/ | tee ${log_file}
    sudo chmod +x "${squashfs}"/usr/bin/anarchy "${squashfs}"/usr/bin/sysinfo "${squashfs}"/usr/bin/iptest | tee ${log_file}

    # Create Anarchy and lang directories, copy over all lang files
    sudo mkdir -p "${squashfs}"/usr/share/anarchy/lang "${squashfs}"/usr/share/anarchy/extra "${squashfs}"/usr/share/anarchy/boot "${squashfs}"/usr/share/anarchy/etc | tee ${log_file}
    sudo cp "${working_dir}"/lang/* "${squashfs}"/usr/share/anarchy/lang/ | tee ${log_file}

    # Create shell function library, copy /lib to squashfs-root
    sudo mkdir "${squashfs}"/usr/lib/anarchy | tee ${log_file}
    sudo cp "${working_dir}"/lib/* "${squashfs}"/usr/lib/anarchy/ | tee ${log_file}

    # Copy over extra files (dotfiles, desktop configurations, help file, issue file, hostname file)
    sudo rm "${squashfs}"/root/install.txt | tee ${log_file}
    sudo cp "${working_dir}"/extra/shellrc/.zshrc "${squashfs}"/root/ | tee ${log_file}
    sudo cp "${working_dir}"/extra/.help "${working_dir}"/extra/.dialogrc "${squashfs}"/root/ | tee ${log_file}
    sudo cp "${working_dir}"/extra/shellrc/.zshrc "${squashfs}"/etc/zsh/zshrc | tee ${log_file}
    sudo cp -r "${working_dir}"/extra/shellrc/. "${squashfs}"/usr/share/anarchy/extra/ | tee ${log_file}
    sudo cp -r "${working_dir}"/extra/desktop "${working_dir}"/extra/wallpapers "${working_dir}"/extra/fonts "${working_dir}"/extra/anarchy-icon.png "${squashfs}"/usr/share/anarchy/extra/ | tee ${log_file}
    cat "${working_dir}"/extra/.helprc | sudo tee -a "${squashfs}"/root/.zshrc >/dev/null
    sudo cp "${working_dir}"/etc/hostname "${working_dir}"/etc/issue_cli "${working_dir}"/etc/lsb-release "${working_dir}"/etc/os-release "${squashfs}"/etc/ | tee ${log_file}
    sudo cp -r "${working_dir}"/boot/splash.png "${working_dir}"/boot/loader/ "${squashfs}"/usr/share/anarchy/boot/ | tee ${log_file}
    sudo cp "${working_dir}"/etc/nvidia340.xx "${squashfs}"/usr/share/anarchy/etc/ | tee ${log_file}

    # Copy over built packages and create repository
    sudo mkdir "${custom_iso}"/arch/"${system_architecture}"/squashfs-root/usr/share/anarchy/pkg | tee ${log_file}

    for pkg in $(echo "${local_aur_packages[@]}"); do
        sudo cp /tmp/"${pkg}"/*.pkg.tar.xz "${squashfs}"/usr/share/anarchy/pkg/ | tee ${log_file}
    done

    cd "${squashfs}"/usr/share/anarchy/pkg || exit
    sudo repo-add anarchy-local.db.tar.gz *.pkg.tar.xz
    echo -e "\n[anarchy-local]\nServer = file:///usr/share/anarchy/pkg\nSigLevel = Never" | sudo tee -a "${squashfs}"/etc/pacman.conf >/dev/null
    cd "${working_dir}" || exit

    if [[ "${system_architecture}" == "i686" ]]; then
        sudo rm -r "${squashfs}"/root/.gnupg | tee ${log_file}
        sudo rm -r "${squashfs}"/etc/pacman.d/gnupg | tee ${log_file}
        sudo linux32 arch-chroot "${squashfs}" dirmngr </dev/null
        sudo linux32 arch-chroot "${squashfs}" pacman-key --init
        sudo linux32 arch-chroot "${squashfs}" pacman-key --populate archlinux32
        sudo linux32 arch-chroot "${squashfs}" pacman-key --refresh-keys
    fi
    echo "Done" | tee ${log_file}
    echo ""
}

build_system() { # prev: build_sys
    echo "Installing packages to new system ..." | tee ${log_file}
    # Install fonts, fbterm, fetchmirrors etc.
    sudo pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg  --config "${pacman_config}" --noconfirm -Sy terminus-font acpi zsh-syntax-highlighting pacman-contrib
    sudo pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg  --config "${pacman_config}" --noconfirm -U /tmp/fetchmirrors/*.pkg.tar.xz
    sudo pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg  --config "${pacman_config}" -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > "${custom_iso}"/arch/pkglist."${system_architecture}".txt
    sudo pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg  --config "${pacman_config}" --noconfirm -Scc
    sudo rm -f "${squashfs}"/var/cache/pacman/pkg/*
    echo "Done" | tee ${log_file}
    echo ""

    # cd back into root system directory, remove old system
    cd "${custom_iso}"/arch/"${system_architecture}" || exit
    rm airootfs.sfs

    # Recreate the iso using compression, remove unsquashed system, generate checksums
    echo "Recreating ${system_architecture} image ..." | tee ${log_file}
    sudo mksquashfs squashfs-root airootfs.sfs -b 1024k -comp xz
    sudo rm -r squashfs-root
    md5sum airootfs.sfs > airootfs.md5
    echo "Done recreating ${system_architecture} image" | tee ${log_file}
    echo ""
}

configure_boot() {
    echo "Configuring boot ..." | tee ${log_file}
    arch_iso_label=$(<"${custom_iso}"/loader/entries/archiso-x86_64.conf awk 'NR==6{print $NF}' | sed 's/.*=//')
    arch_iso_hex=$(<<<"${arch_iso_label}" xxd -p)
    anarchy_iso_hex=$(<<<"${anarchy_iso_label}" xxd -p)
    cp "${working_dir}"/boot/splash.png "${custom_iso}"/arch/boot/syslinux/ | tee ${log_file}
    cp "${working_dir}"/boot/iso/archiso_head.cfg "${custom_iso}"/arch/boot/syslinux/ | tee ${log_file}
    sed -i "s/${arch_iso_label}/${anarchy_iso_label}/;s/Arch Linux archiso/Anarchy Linux/" "${custom_iso}"/loader/entries/archiso-x86_64.conf
    sed -i "s/${arch_iso_label}/${anarchy_iso_label}/;s/Arch Linux/Anarchy Linux/" "${custom_iso}"/arch/boot/syslinux/archiso_sys.cfg
    sed -i "s/${arch_iso_label}/${anarchy_iso_label}/;s/Arch Linux/Anarchy Linux/" "${custom_iso}"/arch/boot/syslinux/archiso_pxe.cfg
    cd "${custom_iso}"/EFI/archiso/ || exit
    echo -e "Replacing label hex in efiboot.img...\n${arch_iso_label} ${arch_iso_hex} > ${anarchy_iso_label} ${anarchy_iso_hex}" | tee ${log_file}
    xxd -c 256 -p efiboot.img | sed "s/${arch_iso_hex}/${anarchy_iso_hex}/" | xxd -r -p > efiboot1.img
    if ! (xxd -c 256 -p efiboot1.img | grep "${anarchy_iso_hex}" &>/dev/null); then
        echo "\nError: failed to replace label hex in efiboot.img" | tee ${log_file}
        echo "Press any key to continue." | tee ${log_file}
        read input
    fi
    mv efiboot1.img efiboot.img
    echo "Done" | tee ${log_file}
    echo ""
}

create_iso() {
    echo "Creating new Anarchy Linux image ..." | tee ${log_file}
    cd "${working_dir}" || exit
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
    -output "${anarchy_iso_name}" \
    "${custom_iso}"

    if [[ "$?" -eq "0" ]]; then
        rm -rf "${custom_iso}" | tee ${log_file}
        generate_checksums
    else
        echo "Error: Image creation failed, exiting." | tee ${log_file}
        exit 4
    fi
}

generate_checksums() {
    echo "Generating image checksum ..." | tee ${log_file}
    local sha_256_sum=$(sha256sum "${anarchy_iso_name}")
    echo "${sha_256_sum}" > "${anarchy_iso_name}".sha256sum
    echo "Done generating image checksum" | tee ${log_file}
    echo ""
}

usage() {
    clear
    echo "Usage: iso-generator.sh [architecture]"
    echo "  --i686)     create i686 (32-bit) installer"
    echo "  --x86_64)   create x86_64 (64-bit) installer (default)"
    echo ""
}

if (<<<"$@" grep "\-\-i686" >/dev/null); then
    system_architecture=i686 # prev: sys
    pacman_config=etc/i686-pacman.conf # prev: paconf
    sudo wget "https://raw.githubusercontent.com/archlinux32/packages/master/core/pacman-mirrorlist/mirrorlist" -O /etc/pacman.d/mirrorlist32
    sudo sed -i 's/#//' /etc/pacman.d/mirrorlist32
else
    system_architecture=x86_64
    pacman_config=/etc/pacman.conf
fi

while (true); do
    case "$1" in
        --i686|--x86_64)
            shift
        ;;
        -h|--help)
            usage
            exit 0
        ;;
        *)
            prettify
            set_version
            init
            extract_arch_iso
            copy_config_files
            build_system
            configure_boot
            create_iso
            echo "${anarchy_iso_name} image generated successfully." | tee ${log_file}
            exit 0
        ;;
    esac
done

# vim: ai:ts=4:sw=4:et