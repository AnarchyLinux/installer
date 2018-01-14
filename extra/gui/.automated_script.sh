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

if [[ $(tty) == "/dev/tty1" ]]; then
    automated_script
    case $(systemd-detect-virt) in
         oracle) sudo modprobe -a vboxguest vboxsf vboxvideo ;;
         *) sudo rm /usr/bin/VBoxClient
            sudo rm /usr/bin/VBoxClient-all
            sudo rm /usr/bin/VBoxControl
            sudo rm /usr/bin/VBoxService ;;
    esac
    startx &>/tmp/startx.log

    if [ "$?" -gt "0" ]; then
        cat /etc/issue_cli
        echo -e "\nERROR: failed to start xorg server"
        echo -e " > Output logged to: /tmp/startx.log\n > Falling back to text mode."
        exit 1
    fi
fi
