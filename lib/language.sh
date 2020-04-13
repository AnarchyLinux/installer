#!/usr/bin/env bash
###############################################################
### Anarchy Linux Install Script
### language.sh
###
### Copyright (C) 2017 Dylan Schacht
###
### By: Dylan Schacht (deadhead)
### Email: deadhead3492@gmail.com
### Webpage: https://anarchylinux.org
###
### Any questions, comments, or bug reports may be sent to above
### email address. Enjoy, and keep on using Arch.
###
### License: GPL v2.0
###############################################################

language() {

    echo "$(date -u "+%F %H:%M") : Start anarchy installer" > "${log}"
    op_title=" -| Language Select |- "
    ILANG=$(dialog --nocancel --menu "\nAnarchy Installer\n\n \Z2*\Zn Select your install language:" 20 60 10 \
        "English" "-" \
        "Bulgarian" "Български" \
        "Dutch" "Nederlands" \
        "French" "Français" \
        "German" "Deutsch" \
        "Greek" "Greek" \
        "Hungarian" "Magyar" \
        "Indonesian" "bahasa Indonesia" \
        "Italian" "Italiano" \
        "Latvian" "Latviešu" \
        "Lithuanian" "Lietuvių" \
        "Polish" "Polski" \
        "Portuguese" "Português" \
        "Portuguese-Brazilian" "Português do Brasil" \
        "Romanian" "Română" \
        "Russian" "Russian" \
        "Spanish" "Español" \
        "Swedish" "Svenska" 3>&1 1>&2 2>&3)

    case "$ILANG" in
        "English") export lang_file="${anarchy_directory}"/lang/english.conf ;;
        "Bulgarian") export lang_file="${anarchy_directory}"/lang/bulgarian.conf lib=bg bro=bg ;;
        "Dutch") export lang_file="${anarchy_directory}"/lang/dutch.conf lib=nl bro=nl ;;
        "French") export lang_file="${anarchy_directory}"/lang/french.conf lib=fr bro=fr ;;
        "German") export lang_file="${anarchy_directory}"/lang/german.conf lib=de bro=de ;;
        "Greek") export lang_file="${anarchy_directory}"/lang/greek.conf lib=el bro=el ;;
        "Hungarian") export lang_file="${anarchy_directory}"/lang/hungarian.conf lib=hu bro=hu ;;
        "Indonesian") export lang_file="${anarchy_directory}"/lang/indonesia.conf lib=id bro=id ;;
        "Italian") export lang_file="${anarchy_directory}"/lang/italian.conf lib=it bro=it ;;
        "Latvian") export lang_file="${anarchy_directory}"/lang/latvian.conf lib=lv bro=lv ;;
        "Lithuanian") export lang_file="${anarchy_directory}"/lang/lithuanian.conf lib=lt bro=lt ;;
        "Polish") export lang_file="${anarchy_directory}"/lang/polish.conf lib=pl bro=pl ;;
        "Portuguese") export lang_file="${anarchy_directory}"/lang/portuguese.conf lib=pt bro=pt-pt ;;
        "Portuguese-Brazilian") export lang_file="${anarchy_directory}"/lang/portuguese-br.conf lib=pt-br bro=pt-br ;;
        "Romanian") export lang_file="${anarchy_directory}"/lang/romanian.conf lib=ro bro=ro ;;
        "Russian") export lang_file="${anarchy_directory}"/lang/russian.conf lib=ru bro=ru ;;
        "Spanish") export lang_file="${anarchy_directory}"/lang/spanish.conf lib=es bro=es-es ;;
        "Swedish") export lang_file="${anarchy_directory}"/lang/swedish.conf lib=sv bro=sv-se ;;
    esac

}

# vim: ai:ts=4:sw=4:et
