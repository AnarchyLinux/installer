#!/usr/bin/env bash

op_title="${install_op_msg}"

while (true); do
    install_opt=$(dialog --ok-button "${ok}" --cancel-button "${cancel}" --menu "${install_opt_msg}" 16 80 5 \
        1 "${install_opt1}" \
        2 "${install_opt2}" \
        3 "${install_opt3}" \
        4 "${install_opt4}" \
        5 "${install_opt0}" 3>&1 1>&2 2>&3)

    if [[ $? -gt 0 ]]; then
        if (dialog --defaultno --yes-button "${yes}" --no-button "${no}" --yesno "\n${exit_msg}" 10 60); then
            main_menu
        fi
    else
        break
    fi
done

case "${install_opt}" in
    5)
        source "${anarchy_scripts}"/choose_base.sh
        graphics
        ;;
    *) quick_install ;;
esac