#!/usr/bin/env sh

# Set Base Vars
n_id=`cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 32 | head -n 1 | cut -c1-6`
n_name="knode-$n_id"
hostname=`cat /etc/hostname`

######################
# Generic Sys Setup
####################

# Disable Swap
echo 'Disabling SWAP...'
sudo swapoff -a
sudo sed -e'/swap/s/^#*/#/g' -i /etc/fstab

# Change Hostname
echo 'Changing Hostname...'
sudo hostname $n_name
sudo sed -i "s/$hostname/$n_name/g" /etc/hostname
sudo sed -i "s/$hostname/$n_name/g" /etc/hosts

##########################
# Distro Spesific Setup
########################

distro=$(awk -F'[= ]' '/^NAME=/{ gsub(/"/,""); print tolower($2)}' /etc/os-release)

case $distro in
  "arch")
    echo 'NOT SUPPORTED!'
    exit 1
    ;;
  
  "opensuse tumbleweed"|"opensuse leap")
    echo 'NOT SUPPORTED!'
    exit 1
    ;;

  "debian"|"ubuntu")
    # Prep OS
    echo ''
    echo '-------------------------------------------------------'
    echo 'Starting OS Package Prep...'
    echo '-------------------------------------------------------'
    echo ''
    sudo apt -y update
    sudo apt -y upgrade
    sudo apt -y install apt-transport-https curl gnupg2
    sudo apt -y autoremove
    sudo apt -y clean

    # Patch IPtables
    echo ''
    echo '-------------------------------------------------------'
    echo 'Patching IP Tables...'
    echo '-------------------------------------------------------'
    echo ''
    sudo runuser -l root -c "echo 'net.bridge.bridge-nf-call-ip6tables = 1' > /etc/sysctl.d/k8s.conf"
    sudo runuser -l root -c "echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.d/k8s.conf"
    sudo sysctl --system

    # Install Docker
    echo ''
    echo '-------------------------------------------------------'
    echo 'Installing Docker...'
    echo '-------------------------------------------------------'
    echo ''
    sudo apt -y install docker.io
    sudo systemctl start docker
    sudo systemctl enable docker

    # Install Kube
    echo ''
    echo '-------------------------------------------------------'
    echo 'Install Kubernetes...'
    echo '-------------------------------------------------------'
    echo ''
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 6A030B21BA07F4FB
    sudo runuser -l root -c "echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list"
    sudo apt update
    sudo apt install -y kubeadm kubelet kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    sudo systemctl start kubelet
    sudo systemctl enable kubelet

    # Configure
    echo ''
    echo ''
    echo '=========================================='
    echo 'Ready to Attach Worker Node to Controller!'
    echo '=========================================='
    echo ''
    ;;

esac
