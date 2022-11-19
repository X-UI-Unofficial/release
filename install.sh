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
        yum install wget curl tar newt -y
    else
        apt-get install wget curl tar whiptail -y
    fi
}

config_after_install() {
    whiptail --title "Warning" --msgbox "For security reasons, it is necessary to forcibly modify the port and account password after the installation/update is completed." 8 78
    if (whiptail --title "Confirm whether to continue ?" --yesno "Select Yes if you want to setup username / password X-UI, select No for default Login." 8 78); then
        config_account=$(whiptail --inputbox "Please set your account name" 8 39 --title "Create Account" 3>&1 1>&2 2>&3)
        [[ ! -z "${config_account}" ]] || config_account="admin"
        config_password=$(whiptail --passwordbox "Please set your password" 8 39 --title "Create Account" 3>&1 1>&2 2>&3)
        [[ ! -z "${config_password}" ]] || config_password="admin"
        config_port=$(whiptail --inputbox "Please set your port" 8 39 --title "Setup X-UI" 3>&1 1>&2 2>&3)
        [[ ! -z "${config_port}" ]] || config_port="54321"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        /usr/local/x-ui/x-ui setting -port ${config_port}
        whiptail --title "X-UI Installer" --msgbox "X-UI Settings Complete" 8 78
    else
        whiptail --title "X-UI Installer" --msgbox "Cancelled, all setting items are default settings, please modify in time.\nDefault username: admin \nDefault password: admin \nDefault port: 54321" 12 80
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/X-UI-Unofficial/release/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            whiptail --title "X-UI Installer" --msgbox "The failure of the X-UI version may be beyond the GitHub API limit, please try it later, or manually specify the X-UI version installation" 8 78
            exit 1
        fi
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/X-UI-Unofficial/release/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz 2>&1 |  stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' |  whiptail --title "X-UI Installer" --gauge "Download X-UI ..." 6 50 0
        if [[ $? -ne 0 ]]; then
            whiptail --title "X-UI Installer" --msgbox "Failed to download x-ui, please make sure your server can download Github files" 8 78
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/X-UI-Unofficial/release/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url} 2>&1 |  stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' |  whiptail --title "X-UI Installer" --gauge "Download X-UI ..." 6 50 0
        if [[ $? -ne 0 ]]; then
            whiptail --title "X-UI Installer" --msgbox "Failed to download x-ui v$1, please make sure this version exists" 8 78
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    if [[ -e /usr/bin/x-ui/ ]]; then
        rm /usr/bin/x-ui -rf
    fi

    tar zxf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    cp -r /usr/local/x-ui/x-ui.sh /usr/bin/x-ui
    if [[ $arch == "aarch64" || $arch == "arm64" ]]; then
       mv /usr/local/x-ui/bin/xray-linux-aarch64 /usr/local/x-ui/bin/xray-linux-arm64
    elif [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
       mv /usr/local/x-ui/bin/xray-linux-x86_64 /usr/local/x-ui/bin/xray-linux-amd64
    fi
    config_after_install
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    whiptail --title "X-UI Installer" --msgbox "Install X-UI Complete: ${last_version} \nUse command x-ui for more infomation." 8 78
}
whiptail --title "X-UI Installer" --msgbox "Start install X-UI" 8 78
install_base
install_x-ui $1
