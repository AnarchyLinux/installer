#!/usr/bin/env bash
# A library for updating Anarchy Linux

function update_anarchy() {
    local tmp_dir
    local wallpaper_dir

    tmp_dir="$(mktemp -d)"
    wallpaper_dir="$(mktemp -d)"

    echo -ne "\n${Yellow}*> Anarchy: Downloading files and scripts..."
    wget -q -4 --no-check-certificate -O ${tmp_dir}/master.tar.gz https://github.com/AnarchyLinux/installer/archive/master.tar.gz

    if [[ $? -gt 0 ]]; then
        echo -e "${Red}*> Error: ${Yellow}Active network connection not detected - Please connect to the internet and try again. Exiting..."
        return 2
    fi

    wget -q -4 --no-check-certificate -O ${wallpaper_dir}/master.tar.gz https://github.com/AnarchyLinux/brand/archive/master.tar.gz

    if [[ $? -gt 0 ]]; then
        echo -e "${Red}*> Error: ${Yellow}Active network connection not detected - Please connect to the internet and try again. Exiting..."
        return 2
    fi

    echo -e "${Green}Done"

    echo -ne "\n${Yellow}*> Anarchy: Extracting and moving files..."
    tar zxf ${tmp_dir}/master.tar.gz -C ${tmp_dir} &> /dev/null
    tar zxf ${wallpaper_dir}/master.tar.gz -C ${wallpaper_dir} &> /dev/null
    # TODO: Move update to a library
    cp ${tmp_dir}/installer-master/anarchy /usr/bin/anarchy
    cp ${tmp_dir}/installer-master/etc/anarchy.d/anarchy.conf "${ANARCHY_DIRECTORY}"/
    cp ${tmp_dir}/installer-master/libs/* "${ANARCHY_LIBRARIES_DIRECTORY}"/
    cp ${tmp_dir}/installer-master/scripts/* "${ANARCHY_SCRIPTS_DIRECTORY}"/
    cp ${tmp_dir}/installer-master/lang/* "${ANARCHY_TRANSLATIONS_DIRECTORY}"/
    cp "${wallpaper_dir}"/brand-master/wallpapers/official/* "${ANARCHY_WALLPAPERS_DIRECTORY}"/
    cp -f ${tmp_dir}/installer-master/extra/sysinfo /installer-master/extra/iptest /usr/bin/
    cp -r ${tmp_dir}/installer-master/extra/* "${ANARCHY_EXTRA_DIRECTORY}"/
    echo -e "${Green}Done"

    echo -e "\n${Green}*> ${Yellow}Anarchy updated successfully, you may now run anarchy${ColorOff}"
    return 0
}

function update_keys() {
    echo -e "${Yellow}*> Anarchy: Updating pacman keys..."
    pacman-db-upgrade
    pacman-key --init
    pacman-key --populate archlinux
    pacman-key --refresh-keys

    if [[ $? -gt 0 ]]; then
        echo -e "${Red}*> Error: ${Yellow}Failed to update pacman keys, exiting..."
        return 1
    else
        echo -e "${Green}*> Updated: ${Yellow}Updated pacman keys successfully."
        return 0
    fi
}

function update_variable() {
    local variable
    local state

    variable="$1"
    state="$2"

    sed --in-place "s/${variable}=.*/${variable}=${state}/" "${ANARCHY_DIRECTORY}/anarchy.conf"
    return "$?"
}