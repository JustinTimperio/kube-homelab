#!/usr/bin/env sh

# Set Base Vars
c_id=`cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 32 | head -n 1 | cut -c1-6`
c_name="kcontrol-$c_id"
hostname=`cat /etc/hostname`
subnet='10.244.10.0/16'
ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)

######################
# Generic Sys Setup
####################

# Disable Swap
echo 'Disabling SWAP...'
sudo swapoff -a
sudo sed -e'/swap/s/^#*/#/g' -i /etc/fstab

# Change Hostname
echo 'Changing Hostname...'
sudo hostname $c_name
sudo sed -i "s/$hostname/$c_name/g" /etc/hostname
sudo sed -i "s/$hostname/$c_name/g" /etc/hosts

# Setup User
init_kube(){
  echo ''
  echo '-------------------------------------------------------'
  echo 'Configuring Kubernetes...'
  echo '-------------------------------------------------------'
  echo ''
  sudo kubeadm config images pull
  sudo kubeadm init --pod-network-cidr=$subnet --apiserver-advertise-address=$ip4

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # Create Pod Network
  echo 'Adding Flannel Network for Pod Communication...'
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
}

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
    init_kube

    ;;

esac



echo ''
echo ''
echo '================================='
echo '  Ready to Attach Worker Nodes!  '
echo '================================='
sudo kubeadm token create --print-join-command
echo ''

