#!/bin/bash

script_cmdline ()
{
    local param
    for param in $(< /proc/cmdline); do
        case "${param}" in
            script=*) echo "${param#*=}" ; return 0 ;;
        esac
    done
}

automated_script ()
{
    local script rt
    script="$(script_cmdline)"
    if [[ -n "${script}" && ! -x /tmp/startup_script ]]; then
        if [[ "${script}" =~ ^http:// || "${script}" =~ ^ftp:// ]]; then
            wget "${script}" --retry-connrefused -q -O /tmp/startup_script >/dev/null
            rt=$?
        else
            cp "${script}" /tmp/startup_script
            rt=$?
        fi
        if [[ ${rt} -eq 0 ]]; then
            chmod +x /tmp/startup_script
            /tmp/startup_script
        fi
    fi
}

check_vm() {

    case $(systemd-detect-virt) in
         oracle) modprobe -a vboxguest vboxsf vboxvideo ;;
    esac

}

if [[ $(tty) == "/dev/tty1" ]]; then
    automated_script
    check_vm
    startx &>/dev/null

    if [ "$?" -gt "0" ]; then
        echo -e "\nERROR: failed to start xorg server"
        systemctl stop NetworkManager.service
        systemctl start netctl.service
        cat ~/.issue_cli
        exit 1
    fi
fi
