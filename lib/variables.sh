#!/usr/bin/env bash

variables() {
    echo "#!/usr/bin/env bash" > /tmp/vars.log

    echo "BOOT=$BOOT" >> /tmp/vars.log
    echo "DE=\"$DE\"" >> /tmp/vars.log
    echo "DM=$DM" >> /tmp/vars.log
    echo "DRIVE=$DRIVE" >> /tmp/vars.log
    echo "FS=$FS" >> /tmp/vars.log
    echo "GPT=$GPT" >> /tmp/vars.log
    echo "GPU=\"$GPU\"" >> /tmp/vars.log
    echo "HOSTNAME=$HOSTNAME" >> /tmp/vars.log
    echo "ILANG=$ILANG" >> /tmp/vars.log
    echo "LANG=$LANG" >> /tmp/vars.log
    echo "LAPTOP=$LAPTOP" >> /tmp/vars.log
    echo "LOCALE=$LOCALE" >> /tmp/vars.log
    echo "NVIDIA=$NVIDIA" >> /tmp/vars.log
    echo "PART=\"$PART\"" >> /tmp/vars.log
    echo "ROOT=$ROOT" >> /tmp/vars.log
    echo "SUBZONE=$SUBZONE" >> /tmp/vars.log
    echo "SWAP=$SWAP" >> /tmp/vars.log
    echo "SWAPSPACE=$SWAPSPACE" >> /tmp/vars.log
    echo "UEFI=$UEFI" >> /tmp/vars.log
    echo "USER=$USER" >> /tmp/vars.log
    echo "VM=$VM" >> /tmp/vars.log
    echo "ZONE=$ZONE" >> /tmp/vars.log
    echo "base_defaults=\"$base_defaults\"" >> /tmp/vars.log
    echo "base_install=\"$base_install\"" >> /tmp/vars.log
    echo "bluetooth=$bluetooth" >> /tmp/vars.log
    echo "bootloader=$bootloader" >> /tmp/vars.log
    echo "btrfs=$btrfs" >> /tmp/vars.log
    echo "code=$code" >> /tmp/vars.log
    echo "config_env=$config_env" >> /tmp/vars.log
    echo "crypted=$crypted" >> /tmp/vars.log
    echo "de=$de" >> /tmp/vars.log
    echo "desktop=$desktop" >> /tmp/vars.log
    echo "dhcp=$dhcp" >> /tmp/vars.log
    echo "drm=$drm" >> /tmp/vars.log
    echo "enable_bt=$enable_bt" >> /tmp/vars.log
    echo "enable_btrfs=$enable_btrfs" >> /tmp/vars.log
    echo "enable_cups=$enable_cups" >> /tmp/vars.log
    echo "enable_dm=$enable_dm" >> /tmp/vars.log
    echo "enable_f2fs=$enable_f2fs" >> /tmp/vars.log
    echo "enable_ftp=$enable_ftp" >> /tmp/vars.log
    echo "enable_http=$enable_http" >> /tmp/vars.log
    echo "enable_nm=$enable_nm" >> /tmp/vars.log
    echo "enable_ssh=$enable_ssh" >> /tmp/vars.log
    echo "frmt=$frmt" >> /tmp/vars.log
    echo "full_user=$full_user" >> /tmp/vars.log
    echo "gtk3_var=\"$gtk3_var\"" >> /tmp/vars.log
    echo "hostname=$hostname" >> /tmp/vars.log
    echo "interface=$interface" >> /tmp/vars.log
    echo "kernel=$kernel" >> /tmp/vars.log
    echo "keyboard=$keyboard" >> /tmp/vars.log
    echo "multilib=$multilib" >> /tmp/vars.log
    echo "root_sh=$root_sh" >> /tmp/vars.log
    echo "sh=$sh" >> /tmp/vars.log
    echo "shrc=$shrc" >> /tmp/vars.log
    echo "start_term=$start_term" >> /tmp/vars.log
    echo "vfat=$vfat" >> /tmp/vars.log
    echo "install_opt=$install_opt" >> /tmp/vars.log
    echo "install_menu=$install_menu" >> /tmp/vars.log
    echo "shell=$shell" >> /tmp/vars.log
    echo "net_util=$net_util" >> /tmp/vars.log
    echo "wifi=$wifi" >> /tmp/vars.log
    echo "rp-pppoe=${rp-pppoe}" >> /tmp/vars.log
    echo "os-prober=${os-prober}" >> /tmp/vars.log
    echo "kernel=$kernel" >> /tmp/vars.log
}
























