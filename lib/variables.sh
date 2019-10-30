#!/usr/bin/env bash

variables() {
    echo "#!/usr/bin/env bash" > /tmp/variables.conf

    echo "BOOT=$BOOT" >> /tmp/variables.conf
    echo "DE=\"$DE\"" >> /tmp/variables.conf
    echo "DM=$DM" >> /tmp/variables.conf
    echo "DRIVE=$DRIVE" >> /tmp/variables.conf
    echo "FS=$FS" >> /tmp/variables.conf
    echo "GPT=$GPT" >> /tmp/variables.conf
    echo "GPU=\"$GPU\"" >> /tmp/variables.conf
    echo "HOSTNAME=$HOSTNAME" >> /tmp/variables.conf
    echo "ILANG=$ILANG" >> /tmp/variables.conf
    echo "LANG=$LANG" >> /tmp/variables.conf
    echo "LAPTOP=$LAPTOP" >> /tmp/variables.conf
    echo "LOCALE=$LOCALE" >> /tmp/variables.conf
    echo "NVIDIA=$NVIDIA" >> /tmp/variables.conf
    echo "PART=\"$PART\"" >> /tmp/variables.conf
    echo "ROOT=$ROOT" >> /tmp/variables.conf
    echo "SUBZONE=$SUBZONE" >> /tmp/variables.conf
    echo "SWAP=$SWAP" >> /tmp/variables.conf
    echo "SWAPSPACE=$SWAPSPACE" >> /tmp/variables.conf
    echo "UEFI=$UEFI" >> /tmp/variables.conf
    echo "USER=$USER" >> /tmp/variables.conf
    echo "VM=$VM" >> /tmp/variables.conf
    echo "ZONE=$ZONE" >> /tmp/variables.conf
    echo "base_defaults=\"$base_defaults\"" >> /tmp/variables.conf
    echo "base_install=\"${base_install[@]}\"" >> /tmp/variables.conf
    echo "bluetooth=$bluetooth" >> /tmp/variables.conf
    echo "bootloader=$bootloader" >> /tmp/variables.conf
    echo "btrfs=$btrfs" >> /tmp/variables.conf
    echo "code=$code" >> /tmp/variables.conf
    echo "config_env=$config_env" >> /tmp/variables.conf
    echo "crypted=$crypted" >> /tmp/variables.conf
    echo "de=$de" >> /tmp/variables.conf
    echo "desktop=$desktop" >> /tmp/variables.conf
    echo "dhcp=$dhcp" >> /tmp/variables.conf
    echo "drm=$drm" >> /tmp/variables.conf
    echo "enable_bt=$enable_bt" >> /tmp/variables.conf
    echo "enable_btrfs=$enable_btrfs" >> /tmp/variables.conf
    echo "enable_cups=$enable_cups" >> /tmp/variables.conf
    echo "enable_dm=$enable_dm" >> /tmp/variables.conf
    echo "enable_f2fs=$enable_f2fs" >> /tmp/variables.conf
    echo "enable_ftp=$enable_ftp" >> /tmp/variables.conf
    echo "enable_http=$enable_http" >> /tmp/variables.conf
    echo "enable_nm=$enable_nm" >> /tmp/variables.conf
    echo "enable_ssh=$enable_ssh" >> /tmp/variables.conf
    echo "frmt=$frmt" >> /tmp/variables.conf
    echo "full_user=$full_user" >> /tmp/variables.conf
    echo "hostname=$hostname" >> /tmp/variables.conf
    echo "interface=$interface" >> /tmp/variables.conf
    echo "kernel=$kernel" >> /tmp/variables.conf
    echo "keyboard=$keyboard" >> /tmp/variables.conf
    echo "multilib=$multilib" >> /tmp/variables.conf
    echo "root_sh=$root_sh" >> /tmp/variables.conf
    echo "sh=$sh" >> /tmp/variables.conf
    echo "shrc=$shrc" >> /tmp/variables.conf
    echo "start_term=\"$start_term\"" >> /tmp/variables.conf
    echo "vfat=$vfat" >> /tmp/variables.conf
    echo "install_opt=$install_opt" >> /tmp/variables.conf
    echo "install_menu=$install_menu" >> /tmp/variables.conf
    echo "shell=\"$shell\"" >> /tmp/variables.conf
    echo "net_util=$net_util" >> /tmp/variables.conf
    echo "wifi=$wifi" >> /tmp/variables.conf
    # echo "rp-pppoe=${rp-pppoe}" >> /tmp/variables.conf
    # echo "os-prober=${os-prober}" >> /tmp/variables.conf
}
























