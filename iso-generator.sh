#!/usr/bin/env bash

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
# * Exit 3: Checksum did not match for Arch ISO (check_arch_iso)
# * Exit 4: Failed to create iso (create_iso)

# Exit on error
set -o errexit
set -o errtrace

# Enable tracing of what gets executed
#set -o xtrace

# Declare important variables
working_dir=$(pwd) # prev: aa
log_dir="${working_dir}"/log
out_dir="${working_dir}"/out # Directory for generated ISOs

# Define colors depending on script arguments
set_up_colors() {
    if [[ "${show_color}" == true ]]; then
        color_blank='\e[0m'
        color_green='\e[1;32m'
        color_red='\e[1;31m'
        color_white="\e[1m"
    else
        # Replace all colors with reset codes
        color_blank='\e[0m'
        color_green='\e[0m'
        color_red='\e[0m'
        color_white="\e[0m"
    fi
}

set_up_logging() {
    if [[ ! -d "${log_dir}" ]]; then
        mkdir "${log_dir}"
    fi

    log_file="${log_dir}"/iso-generator-"$(date +%d%m%y)".log

    # Remove existing logs and create a new one
    if [[ -e "${log_dir}"/"${log_file}" ]]; then
        rm "${log_dir}"/"${log_file}"
    fi

    touch "${log_file}"
}

log() {
    local entry
    read entry
    echo -e "$(date -u "+%d/%m/%Y %H:%M") : ${entry}" | tee -a "${log_file}"
}

# Clears the screen and adds a banner
prettify() {
    clear
    echo -e "${color_white}-- Anarchy Linux --${color_blank}"
    echo -e ""
}

set_version() {
    # Label must be 11 characters long
    anarchy_iso_label="ANARCHYV106" # prev: iso_label
    anarchy_iso_release="1.0.6" # prev: iso_rel
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

    if [[ ! -d "${out_dir}" ]]; then
        mkdir "${out_dir}"
    fi

    # Remove existing Anarchy iso with same name
    if [[ -e "${out_dir}"/"${anarchy_iso_name}" ]]; then
        rm "${out_dir}"/"${anarchy_iso_name}"
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
        'openbox-themes'
    )

    check_dependencies
    update_arch_iso
    check_arch_iso
    local_repo_builds
}

check_dependencies() { # prev: check_depends
    echo -e "Checking dependencies ..." | log

    # Dependencies with same name packages
    dependencies=(
    'wget'
    'libisoburn'
    'squashfs-tools'
    'p7zip'
    'arch-install-scripts'
    'xxd'
    'gtk3'
    'pacman-contrib'
    'pkgconf'
    'patch'
    'gcc'
    'make'
    'binutils'
    'file'
    'go'
    )

    for dep in "${dependencies[@]}"; do
        if ! pacman -Qi ${dep} > /dev/null; then
            missing_deps+=("${dep}")
        fi
    done

    if [[ "${#missing_deps[@]}" -ne 0 ]]; then
        echo -e "Missing dependencies: ${missing_deps[*]}" | log
        if [[ "${user_input}" == true ]]; then
            echo -e "Install them now? [y/N]: "
            local input
            read -r input

            case "${input}" in
                y|Y|yes|YES|Yes)
                    echo -e "Chose to install dependencies" | log
                    for pkg in "${missing_deps[@]}"; do
                        echo -e "Installing ${pkg} ..." | log
                        if [[ "${show_color}" == true ]]; then
                            sudo pacman --noconfirm -Sy "${pkg}"
                        else
                            sudo pacman --noconfirm --color never -Sy "${pkg}"
                        fi
                        echo -e "${pkg} installed" | log
                    done
                    ;;
                *)
                echo -e "Chose not to install dependencies" | log
                echo -e "${color_red}Error: Missing dependencies, exiting.${color_blank}" | log
                exit 1
                ;;
            esac
        else
            for pkg in "${missing_deps[@]}"; do
                echo -e "Installing ${pkg} ..." | log
                if [[ "${show_color}" == true ]]; then
                    sudo pacman --noconfirm -Sy "${pkg}"
                else
                    sudo pacman --noconfirm --color never -Sy "${pkg}"
                fi
                echo -e "${pkg} installed" | log
            done
        fi
    fi
    echo -e "Done installing dependencies"
    echo -e ""
}

update_arch_iso() { # prev: update_iso
    update=false

    # Check for latest Arch Linux iso
    if [[ "${system_architecture}" == "x86_64" ]]; then
        arch_iso_latest=$(curl -s https://www.archlinux.org/download/ | grep "Current Release" | awk '{print $3}' | sed -e 's/<.*//') # prev: archiso_latest
        arch_iso_link="https://mirrors.kernel.org/archlinux/iso/${arch_iso_latest}/archlinux-${arch_iso_latest}-x86_64.iso" # prev: archiso_link
        arch_checksum_link="https://mirrors.edge.kernel.org/archlinux/iso/${arch_iso_latest}/sha1sums.txt"
    else
        arch_iso_latest=$(curl -s https://mirror.archlinux32.org/archisos/ | grep -o ">.*.iso<" | tail -1 | sed 's/>//;s/<//')
        arch_iso_link="https://mirror.archlinux32.org/archisos/${arch_iso_latest}"
        arch_checksum_link="https://mirror.archlinux32.org/archisos/sha512sums"
    fi

    echo -e "Checking for updated Arch Linux image ..." | log
    iso_date=$(<<<"${arch_iso_link}" sed 's!.*/!!')
    if [[ "${iso_date}" != "${local_arch_iso}" ]]; then
        if [[ -z "${local_arch_iso}" ]]; then
            echo -e "No Arch Linux image found under ${working_dir}" | log
            if [[ "${user_input}" == true ]]; then
                echo -e "Download it? [y/N]: "
                local input
                read -r input

                case "${input}" in
                    y|Y|yes|YES|Yes)
                        echo -e "Chose to download image" | log
                        update=true
                        ;;
                    *)
                    echo -e "Chose not to download image" | log
                    echo -e "${color_red}Error: anarchy-creator requires an Arch Linux image located in: ${working_dir}, exiting.${color_blank}" | log
                    exit 2
                    ;;
                esac
            else
                update=true
            fi
        else
            echo -e "Updated Arch Linux image available: ${arch_iso_latest}" | log
            if [[ "${user_input}" == true ]]; then
                echo -e "Download it? [y/N]: "
                local input
                read -r input

                case "${input}" in
                    y|Y|yes|YES|Yes)
                        echo -e "Chose to update image" | log
                        local_arch_checksum=$(ls "${working_dir}"/sha*sum* | tail -n1 | sed 's!.*/!!')
                        update=true
                        ;;
                    *)
                    echo -e "Chose not to update image" | log
                    echo -e "Using old image: ${local_arch_iso}" | log
                    local_arch_checksum=$(ls "${working_dir}"/sha*sum* | tail -n1 | sed 's!.*/!!')
                    sleep 1
                    ;;
                esac
            else
                local_arch_checksum=$(ls "${working_dir}"/sha*sum* | tail -n1 | sed 's!.*/!!')
                update=true
            fi
        fi

        if "${update}" ; then
            cd "${working_dir}" || exit
            echo -e ""
            echo -e "Downloading Arch Linux image and checksum ..." | log
            echo -e "(Don't resize the window or it will mess up the progress bar)"
            wget -c -q --show-progress "${arch_checksum_link}"
            local_arch_checksum=$(ls "${working_dir}"/sha*sum* | tail -n1 | sed 's!.*/!!')
            wget -c -q --show-progress "${arch_iso_link}"
            local_arch_iso=$(ls "${working_dir}"/archlinux-*-"${system_architecture}".iso | tail -n1 | sed 's!.*/!!')
        fi
    fi
    echo -e "Done checking for Arch Linux image"
    echo -e ""
}

check_arch_iso() {
    echo -e "Comparing Arch Linux checksums ..." | log
    checksum=false
    local_arch_checksum=$(ls "${working_dir}"/sha*sum* | tail -n1 | sed 's!.*/!!')

    # Check if checksum exists
    if [[ -e "${local_arch_checksum}" ]]; then
        # Check checksum depending on architecture
        if [[ "${system_architecture}" == "x86_64" ]]; then
            if [[ $(sha1sum --check --ignore-missing "${local_arch_checksum}") ]]; then
                echo -e "${local_arch_iso}: OK" | log
                checksum=true
            fi
        else
            if [[ $(sha256sum --check --ignore-missing "${local_arch_checksum}") ]]; then
                echo -e "${local_arch_iso}: OK" | log
                checksum=true
            fi
        fi
    else
        echo -e "No checksum found!" | log
        if [[ "${user_input}" == true ]]; then
            echo -e "Download it? [Y/n]: "
            local input
            read -r input

            case "${input}" in
                n|N|no|NO|No)
                    echo -e "Chose not to download checksum" | log
                    ;;
                *)
                echo -e "Chose to download checksum" | log
                wget -c -q --show-progress "${arch_checksum_link}"
                local_arch_checksum=$(ls "${working_dir}"/sha*sum* | tail -n1 | sed 's!.*/!!')
                if [[ "${system_architecture}" == "x86_64" ]]; then
                    if [[ $(sha1sum --check --ignore-missing "${local_arch_checksum}") ]]; then
                        echo -e "${local_arch_iso}: OK" | log
                        checksum=true
                    fi
                else
                    if [[ $(sha256sum --check --ignore-missing "${local_arch_checksum}") ]]; then
                        echo -e "${local_arch_iso}: OK" | log
                        checksum=true
                    fi
                fi
                ;;
            esac
        else
            # Automatically download and compare checksum
            wget -c -q --show-progress "${arch_checksum_link}"
            local_arch_checksum=$(ls "${working_dir}"/sha*sum* | tail -n1 | sed 's!.*/!!')
            if [[ "${system_architecture}" == "x86_64" ]]; then
                if [[ $(sha1sum --check --ignore-missing "${local_arch_checksum}") ]]; then
                    echo -e "${local_arch_iso}: OK" | log
                    checksum=true
                fi
            else
                if [[ $(sha256sum --check --ignore-missing "${local_arch_checksum}") ]]; then
                    echo -e "${local_arch_iso}: OK" | log
                    checksum=true
                fi
            fi
        fi
    fi

    if [[ "${checksum}" == false ]]; then
        echo -e "Checksum did not match ISO file!" | log
        if [[ "${user_input}" == true ]]; then
            echo -e "Continue anyway? [y/N]: "
            local input
            read -r input

            case "${input}" in
                y|Y|yes|YES|Yes)
                    echo -e "Chose to continue" | log
                    ;;
                *)
                    echo -e "Chose not to continue" | log
                    echo -e "${color_red}Error: Checksum did not match file, exiting!${color_blank}" | log
                    exit 3
                    ;;
            esac
        else
            echo -e "${color_red}Error: Checksum did not match file, exiting!${color_blank}" | log
            exit 3
        fi
    fi
}

local_repo_builds() { # prev: aur_builds
    echo -e "Updating pacman databases ..." | log
    sudo pacman -Sy --noconfirm
    echo -e "Done updating pacman databases"

    echo -e "Building AUR packages for local repo ..." | log

    # Begin build loop checking /tmp for existing builds, then build packages & install if required
    for pkg in "${local_aur_packages[@]}"; do
        echo -e "Making ${pkg} ..." | log
        wget -qO- "${aur_snapshot_link}/${pkg}.tar.gz" | tar xz -C /tmp
        cd /tmp/"${pkg}" || exit
        if [[ "${show_color}" == true ]]; then
            makepkg -sif --noconfirm --nocheck
        else
            makepkg -sif --noconfirm --nocheck --nocolor
        fi
        echo -e "${pkg} made successfully" | log
    done

    echo -e "Done making packages"
    echo -e ""
}

extract_arch_iso() { # prev: extract_iso
    cd "${working_dir}" || exit

    if [[ -d "${custom_iso}" ]]; then
        sudo rm -rf "${custom_iso}"
    fi

    echo -e "Extracting Arch Linux image ..." | log

    # Extract Arch iso to mount directory and continue with build
    7z x "${local_arch_iso}" -o"${custom_iso}"

    echo -e "Done extracting image"
    echo -e ""
}

copy_config_files() { # prev: build_conf
    # Change directory into the iso, where the filesystem is stored.
    # Unsquash root filesystem 'airootfs.sfs', this creates a directory 'squashfs-root' containing the entire system
    echo -e "Unsquashing ${system_architecture} image ..." | log
    cd "${custom_iso}"/arch/"${system_architecture}" || exit
    sudo unsquashfs airootfs.sfs
    echo -e "Done unsquashing airootfs.sfs"
    echo -e ""

    echo -e "Adding console and locale config files to iso ..." | log
    # Copy over vconsole.conf (sets font at boot), locale.gen (enables locale(s) for font) & uvesafb.conf
    sudo cp "${working_dir}"/etc/vconsole.conf "${working_dir}"/etc/locale.gen "${squashfs}"/etc/
    sudo arch-chroot "${squashfs}" /bin/bash locale-gen

    # Copy over main Anarchy config and installer script, make them executable
    echo -e "Adding anarchy config and installer scripts to iso ..." | log
    sudo cp "${working_dir}"/etc/anarchy.conf "${squashfs}"/etc/
    sudo cp "${working_dir}"/anarchy-installer.sh "${squashfs}"/usr/bin/anarchy
    sudo cp "${working_dir}"/extra/sysinfo "${working_dir}"/extra/iptest "${squashfs}"/usr/bin/
    sudo chmod +x "${squashfs}"/usr/bin/anarchy "${squashfs}"/usr/bin/sysinfo "${squashfs}"/usr/bin/iptest

    # Create Anarchy and lang directories, copy over all lang files
    echo -e "Adding language files to iso ..." | log
    sudo mkdir -p "${squashfs}"/usr/share/anarchy/lang "${squashfs}"/usr/share/anarchy/extra "${squashfs}"/usr/share/anarchy/boot "${squashfs}"/usr/share/anarchy/etc
    sudo cp "${working_dir}"/lang/* "${squashfs}"/usr/share/anarchy/lang/

    # Create shell function library, copy /lib to squashfs-root
    echo -e "Adding anarchy scripts to iso ..." | log
    sudo mkdir "${squashfs}"/usr/lib/anarchy
    sudo cp "${working_dir}"/lib/* "${squashfs}"/usr/lib/anarchy/

    # Copy over extra files (dot files, desktop configurations, help file, issue file, hostname file)
    echo -e "Adding dot files and desktop configurations to iso ..." | log
    sudo rm "${squashfs}"/root/install.txt
    sudo cp "${working_dir}"/extra/shellrc/.zshrc "${squashfs}"/root/
    sudo cp "${working_dir}"/extra/.help "${working_dir}"/extra/.dialogrc "${squashfs}"/root/
    sudo cp "${working_dir}"/extra/shellrc/.zshrc "${squashfs}"/etc/zsh/zshrc
    sudo cp -r "${working_dir}"/extra/shellrc/. "${squashfs}"/usr/share/anarchy/extra/
    sudo cp -r "${working_dir}"/extra/desktop "${working_dir}"/extra/wallpapers "${working_dir}"/extra/fonts "${working_dir}"/extra/anarchy-icon.png "${squashfs}"/usr/share/anarchy/extra/
    cat "${working_dir}"/extra/.helprc | sudo tee -a "${squashfs}"/root/.zshrc >/dev/null
    sudo cp "${working_dir}"/etc/hostname "${working_dir}"/etc/issue_cli "${squashfs}"/etc/
    sudo cp -r "${working_dir}"/boot/splash.png "${working_dir}"/boot/loader/ "${squashfs}"/usr/share/anarchy/boot/
    sudo cp "${working_dir}"/etc/nvidia340.xx "${squashfs}"/usr/share/anarchy/etc/

    # Copy over built packages and create repository
    echo -e "Adding built AUR packages to iso ..." | log
    sudo mkdir "${custom_iso}"/arch/"${system_architecture}"/squashfs-root/usr/share/anarchy/pkg

    for pkg in $(echo -e "${local_aur_packages[@]}"); do
        sudo cp /tmp/"${pkg}"/*.pkg.tar.xz "${squashfs}"/usr/share/anarchy/pkg/
    done

    cd "${squashfs}"/usr/share/anarchy/pkg || exit
    sudo repo-add anarchy-local.db.tar.gz *.pkg.tar.xz
    echo -e "\n[anarchy-local]\nServer = file:///usr/share/anarchy/pkg\nSigLevel = Never" | sudo tee -a "${squashfs}"/etc/pacman.conf > /dev/null
    cd "${working_dir}" || exit

    if [[ "${system_architecture}" == "i686" ]]; then
        sudo rm -r "${squashfs}"/root/.gnupg
        sudo rm -r "${squashfs}"/etc/pacman.d/gnupg
        sudo linux32 arch-chroot "${squashfs}" dirmngr < /dev/null
        sudo linux32 arch-chroot "${squashfs}" pacman-key --init
        sudo linux32 arch-chroot "${squashfs}" pacman-key --populate archlinux32
        sudo linux32 arch-chroot "${squashfs}" pacman-key --refresh-keys
    fi
    echo -e "Done adding files to iso"
    echo -e ""
}

build_system() { # prev: build_sys
    echo -e "Installing packages to new system ..." | log
    # Install fonts, fbterm, fetchmirrors etc.
    sudo pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg  --config "${pacman_config}" --noconfirm -Sy terminus-font acpi zsh-syntax-highlighting pacman-contrib
    sudo pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg  --config "${pacman_config}" --noconfirm -U /tmp/fetchmirrors/*.pkg.tar.xz
    sudo pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg  --config "${pacman_config}" -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > "${custom_iso}"/arch/pkglist."${system_architecture}".txt
    sudo pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg  --config "${pacman_config}" --noconfirm -Scc
    sudo rm -f "${squashfs}"/var/cache/pacman/pkg/*
    echo -e "Done installing packages to new system"
    echo -e ""

    # cd back into root system directory, remove old system
    cd "${custom_iso}"/arch/"${system_architecture}" || exit
    rm airootfs.sfs

    # Recreate the iso using compression, remove unsquashed system, generate checksums
    echo -e "Recreating ${system_architecture} image ..." | log
    sudo mksquashfs squashfs-root airootfs.sfs -b 1024k -comp xz
    sudo rm -r squashfs-root
    md5sum airootfs.sfs > airootfs.md5
    echo -e "Done recreating ${system_architecture} image"
    echo -e ""
}

configure_boot() {
    echo -e "Configuring boot ..." | log
    arch_iso_label=$(<"${custom_iso}"/loader/entries/archiso-x86_64.conf awk 'NR==6{print $NF}' | sed 's/.*=//')
    arch_iso_hex=$(<<<"${arch_iso_label}" xxd -p)
    anarchy_iso_hex=$(<<<"${anarchy_iso_label}" xxd -p)
    cp "${working_dir}"/boot/splash.png "${custom_iso}"/arch/boot/syslinux/
    cp "${working_dir}"/boot/iso/archiso_head.cfg "${custom_iso}"/arch/boot/syslinux/
    sed -i "s/${arch_iso_label}/${anarchy_iso_label}/;s/Arch Linux archiso/Anarchy Linux/" "${custom_iso}"/loader/entries/archiso-x86_64.conf
    sed -i "s/${arch_iso_label}/${anarchy_iso_label}/;s/Arch Linux/Anarchy Linux/" "${custom_iso}"/arch/boot/syslinux/archiso_sys.cfg
    sed -i "s/${arch_iso_label}/${anarchy_iso_label}/;s/Arch Linux/Anarchy Linux/" "${custom_iso}"/arch/boot/syslinux/archiso_pxe.cfg
    cd "${custom_iso}"/EFI/archiso/ || exit
    echo -e "Replacing label hex in efiboot.img...\n${arch_iso_label} ${arch_iso_hex} > ${anarchy_iso_label} ${anarchy_iso_hex}" | log
    xxd -c 256 -p efiboot.img | sed "s/${arch_iso_hex}/${anarchy_iso_hex}/" | xxd -r -p > efiboot1.img
    if ! (xxd -c 256 -p efiboot1.img | grep "${anarchy_iso_hex}" &>/dev/null); then
        echo -e "${color_red}\nError: failed to replace label hex in efiboot.img${color_blank}" | log
        echo -e "Press any key to continue."
        read input
    fi
    mv efiboot1.img efiboot.img
    echo -e "Done configuring boot"
    echo -e ""
}

create_iso() {
    echo -e "Creating new Anarchy image ..." | log
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
    -output "${out_dir}"/"${anarchy_iso_name}" \
    "${custom_iso}"

    if [[ "$?" -eq 0 ]]; then
        rm -rf "${custom_iso}"
        generate_checksums
    else
        echo -e "${color_red}Error: Image creation failed, exiting.${color_blank}" | log
        exit 4
    fi
}

generate_checksums() {
    echo -e "Generating image checksum ..." | log
    local sha_256_sum
    sha_256_sum=$(sha256sum "${out_dir}"/"${anarchy_iso_name}")
    echo -e "${sha_256_sum}" > "${out_dir}"/"${anarchy_iso_name}".sha256sum
    echo -e "Done generating image checksum"
    echo -e ""
}

uninstall_dependencies() {
    if [[ "${#missing_deps[@]}" -ne 0 ]]; then
        echo -e "Installed dependencies: ${missing_deps[*]}" | log
        if [[ "${user_input}" == true ]]; then
            echo -e "Uninstall these dependencies? [y/N]: "
            local input
            read -r input

            case "${input}" in
                y|Y|yes|YES|Yes)
                    echo -e "Chose to remove dependencies" | log
                    for pkg in "${missing_deps[@]}"; do
                        echo -e "Removing ${pkg} ..." | log
                        sudo pacman -Rs ${pkg}
                        echo -e "${pkg} removed" | log
                    done
                    echo -e "Removed all dependencies" | log
                    ;;
                *)
                    echo -e "Chose not to remove dependencies" | log
                    ;;
            esac
        fi
    fi
}

# Logs last command to display it in cleanup
command_log() {
    current_command="${BASH_COMMAND}"
    last_command="${current_command}"
}

# Starts if the iso-generator is interrupted
cleanup() {
    # Check if user exited or if there was an error
    if [[ "${last_command}" == "init" ]]; then
        echo -e "User force stopped the script" | log
    else
        echo -e "${color_red}An error occured: ${last_command} exited with error code $?${color_blank}" | log
    fi

    # Check if customiso is mounted
    if mount | grep "${custom_iso}" > /dev/null; then
        echo -e "Unmounting customiso directory ..." | log
        sudo umount "${custom_iso}"
    fi

    # Check and clean the customiso directory
    if [[ -d "${custom_iso}" ]]; then
        echo -e "Removing customiso directory ..." | log
        # We have to use sudo in case root owns files inside customiso
        sudo rm -rf "${custom_iso}"
    fi

    if [[ "${last_command}" != "init" ]]; then
        echo -e "${color_white}Please report this issue to our Github issue tracker: https://git.io/JeOxK${color_blank}"
        echo -e "${color_white}Make sure to include the relevant log: ${log_file}${color_blank}"
        echo -e "${color_white}You can also ask about the issue in our Telegram: https://t.me/anarchy_linux${color_blank}"
    fi
}

usage() {
    clear
    echo -e "${color_white}Usage: iso-generator.sh [options]${color_blank}"
    echo -e "${color_white}     --i686)     create i686 (32-bit) installer${color_blank}"
    echo -e "${color_white}     --x86_64)   create x86_64 (64-bit) installer (default)${color_blank}"
    echo -e "${color_white}     -c | --no-color)    Disable color output${color_blank}"
    echo -e "${color_white}     -i | --no-input)    Don't ask user for input${color_blank}"
    echo -e ""
}

if (<<<"$@" grep "\-\-i686" > /dev/null); then
    system_architecture=i686 # prev: sys
    pacman_config=etc/i686-pacman.conf # prev: paconf
    sudo wget "https://raw.githubusercontent.com/archlinux32/packages/master/core/pacman-mirrorlist/mirrorlist" -O /etc/pacman.d/mirrorlist32
    sudo sed -i 's/#//' /etc/pacman.d/mirrorlist32
else
    system_architecture=x86_64
    pacman_config=/etc/pacman.conf
fi

# Enable traps
trap command_log DEBUG
trap cleanup ERR

# Enable color output and user input by default
show_color=true
user_input=true

while (true); do
    case "$1" in
        --i686|--x86_64)
            shift
        ;;
        -h|--help)
            usage
            exit 0
        ;;
        -c|--no-color)
            show_color=false
            shift
        ;;
        -i|--no-input)
            user_input=false
            shift
        ;;
        -o|--output-dir)
            shift
            out_dir=$1
            shift
        ;;
        -l|--log-dir)
            shift
            log_dir=$1
            shift
        ;;
        #-a|--arch-iso)
        #    shift
        #    local_arch_iso=$1
        #    shift
        #;;
        *)
            prettify
            set_up_logging
            set_version
            init
            extract_arch_iso
            copy_config_files
            build_system
            configure_boot
            create_iso
            uninstall_dependencies
            echo -e "${color_green}${anarchy_iso_name} image generated successfully.${color_blank}" | log
            exit 0
        ;;
    esac
done

# vim: ai:ts=4:sw=4:et
