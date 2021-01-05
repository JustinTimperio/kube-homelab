#!/usr/bin/env sh


print_header(){
  echo ''
  echo '-------------------------------------------------------'
  echo "$1"
  echo '-------------------------------------------------------'
  echo ''
}

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
    #####################################
    print_header 'Starting OS Prep...'
    ##################################

    # Update
    sudo apt -y update
    sudo apt -y install apt-transport-https curl gnupg2 software-properties-common

    # Patch IPtables
    sudo runuser -l root -c "echo 'net.bridge.bridge-nf-call-iptables = 1' > /etc/sysctl.d/99-kubernetes-cri.conf"
    sudo runuser -l root -c "echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-kubernetes-cri.conf"
    sudo runuser -l root -c "echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.d/99-kubernetes-cri.conf"
    
    # Load Modules
    sudo modprobe overlay
    sudo modprobe br_netfilter
    sudo runuser -l root -c "echo 'overlay' > /etc/modules-load.d/crio-net.conf"
    sudo runuser -l root -c "echo 'br_netfilter' >> /etc/modules-load.d/crio-net.conf"
    sudo sysctl --system


    #####################################
    print_header 'Installing CRI-O...'
    ##################################

    # Add CRI-O Repo
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8BECF1637AD8C79D
    sudo runuser -l root -c "echo 'deb http://ppa.launchpad.net/projectatomic/ppa/ubuntu bionic main' > /etc/apt/sources.list.d/projectatomics.list"
    sudo runuser -l root -c "echo 'deb-src http://ppa.launchpad.net/projectatomic/ppa/ubuntu bionic main' >> /etc/apt/sources.list.d/projectatomics.list"
    sudo apt update

    # Install CRI-O
    sudo apt install -y cri-o-1.15 containernetworking-plugins
    sudo sed -i 's/\/usr\/libexec\/crio\/conmon/\/usr\/bin\/conmon/g' /etc/crio/crio.conf
    sudo curl -s https://raw.githubusercontent.com/projectatomic/registries/master/registries.fedora -o /etc/containers/registries.conf
    sudo systemctl enable crio
    sudo systemctl start crio


    #####################################
    print_header 'Install Kubernetes...'
    ##################################

    # Add Repo
    sudo runuser -l root -c "echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list"
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    sudo apt update
    sudo apt install -y kubeadm kubelet kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    
    # Add Launch Conf
    sudo runuser -l root -c "echo 'KUBELET_EXTRA_ARGS=--cgroup-driver=systemd --container-runtime=remote --container-runtime-endpoint=\"unix:///var/run/crio/crio.sock\"' > /etc/default/kubelet"

    # Install
    sudo systemctl daemon-reload
    sudo systemctl start kubelet
    sudo systemctl enable kubelet

      # Configure
      echo ''
      echo ''
      echo '===================================='
      echo 'Ready to Attach Node to Controller!'
      echo '===================================='
      echo ''
      ;;

esac
