#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain} must be root to run this script! \n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "armbian"; then
    release="armbian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "System version not detected by ${red}, please contact the script author! ${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="x86_64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="aarch64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
elif [[ $arch == "riscv64" ]]; then
    arch="riscv64"
else
    arch="x86_64"
    echo -e "${red}Failed to detect schema, use default schema: ${arch}${plain}"
fi

echo "Your CPU arch: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "This software does not support 32-bit system (x86), please use 64-bit system (x86_64), if the detection is wrong, please contact the author"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher! ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or later! ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}For security reasons, it is necessary to forcibly modify the port and account password after the installation/update is completed.${plain}"
    read -p "Confirm whether to continue?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Please set your account name:" config_account
        echo -e "${yellow}Your account name will be set to:${config_account}${plain}"
        read -p "Please set your account password:" config_password
        echo -e "${yellow}Please set your account password:${config_password}${plain}"
        read -p "Please set the panel access port:" config_port
        echo -e "${yellow}Your panel access port will be set to:${config_port}${plain}"
        echo -e "${yellow}Confirm setting, setting${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}Account password setting completed${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}Panel port setting completed${plain}"
    else
        echo -e "${red}Cancelled, all setting items are default settings, please modify in time${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/X-UI-Unofficial/release/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}The failure of the X-UI version may be beyond the GitHub API limit, please try it later, or manually specify the X-UI version installation${plain}"
            exit 1
        fi
        echo -e "detected x-ui The latest version of: ${last_version}, start installation"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/X-UI-Unofficial/release/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download x-ui, please make sure your server can download Github files${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/X-UI-Unofficial/release/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "start installation x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download x-ui v$1, please make sure this version exists${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi
    
    if [[ -e /usr/bin/x-ui/ ]]; then
        rm /usr/bin/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    cp -r /usr/local/x-ui/x-ui.sh /usr/bin/x-ui/x-ui
    if [[ $arch == "aarch64" || $arch == "arm64" ]]; then
       mv /usr/local/x-ui/bin/xray-linux-aarch64 /usr/local/x-ui/bin/xray-linux-arm64
    elif [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
       mv /usr/local/x-ui/bin/xray-linux-x86_64 /usr/local/x-ui/bin/xray-linux-amd64
    fi
    config_after_install
    # echo -e "If it is a fresh installation, the default web port is ${green}54321${plain}, and the default username and password are ${green}admin${plain}"
    # echo -e "Please make sure this port is not occupied by other programs, ${yellow} and make sure port 54321 is released ${plain}"
    # echo -e "If you want to modify 54321 to another port, enter the x-ui command to modify it, and also make sure that the port you modify is also released"
    # echo -e ""
    # echo -e "If it's the update panel, access the panel as you did before"
    # echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} The installation is complete, the panel is launched."
    echo -e ""
    echo -e "x-ui How to use the management script: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Show admin menu (more functions)"
    echo -e "x-ui start        - Start the x-ui panel"
    echo -e "x-ui stop         - stop x-ui panel"
    echo -e "x-ui restart      - restart x-ui panel"
    echo -e "x-ui status       - View x-ui status"
    echo -e "x-ui enable       - Set x-ui to start automatically at boot"
    echo -e "x-ui disable      - Cancel x-ui boot auto-start"
    echo -e "x-ui log          - View x-ui logs"
    echo -e "x-ui v2-ui        - Migrate the v2-ui account data of this machine to x-ui"
    echo -e "x-ui update       - Update x-ui panel"
    echo -e "x-ui install      - install x-ui panel"
    echo -e "x-ui uninstall    - uninstall x-ui panel"
    echo -e "----------------------------------------------"
}

echo -e "${green}start installation${plain}"
install_base
install_x-ui $1
