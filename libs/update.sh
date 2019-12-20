#!/usr/bin/env bash
# Collection of libraries for updating various parts of Anarchy

function update_anarchy() {
    local tmp_dir
    local wallpaper_dir

    tmp_dir="$(mktemp -d)"
    wallpaper_dir="$(mktemp -d)"

    echo -ne "\n${color_yellow}*> Anarchy: Downloading files and scripts..."
    wget -q -4 --no-check-certificate -O ${tmp_dir}/master.tar.gz https://github.com/AnarchyLinux/installer/archive/master.tar.gz

    if [[ $? -gt 0 ]]; then
        echo -e "${color_red}*> Error: ${color_yellow}Active network connection not detected - Please connect to the internet and try again. Exiting..."
        return 2
    fi

    wget -q -4 --no-check-certificate -O ${wallpaper_dir}/master.tar.gz https://github.com/AnarchyLinux/brand/archive/master.tar.gz

    if [[ $? -gt 0 ]]; then
        echo -e "${color_red}*> Error: ${color_yellow}Active network connection not detected - Please connect to the internet and try again. Exiting..."
        return 2
    fi

    echo -e "${color_green}Done"

    echo -ne "\n${color_yellow}*> Anarchy: Extracting and moving files..."
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
    echo -e "${color_green}Done"

    echo -e "\n${color_green}*> ${color_yellow}Anarchy updated successfully, you may now run anarchy${color_none}"
    return 0
}

function update_keys() {
    echo -e "${color_yellow}*> Anarchy: Updating pacman keys..."
    pacman-db-upgrade
    pacman-key --init
    pacman-key --populate archlinux
    pacman-key --refresh-keys

    if [[ $? -gt 0 ]]; then
        echo -e "${color_red}*> Error: ${color_yellow}Failed to update pacman keys, exiting..."
        return 1
    else
        echo -e "${color_green}*> Updated: ${color_yellow}Updated pacman keys successfully."
        return 0
    fi
}

# Arguments:
#   $1 - variable name
#   $2 - variable value
function update_var() {
    local name
    local value

    name="$1"
    value="$2"

    sed --in-place "s/${name}=.*/${name}=${value}/" "${ANARCHY_DIRECTORY}/anarchy.conf"
    return "$?"
}