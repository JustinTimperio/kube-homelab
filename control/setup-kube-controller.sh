#!/usr/bin/env sh

print_header(){
  echo ''
  echo '-------------------------------------------------------'
  echo "$1"
  echo '-------------------------------------------------------'
  echo ''
}

##########################
# Generic Sys Setup
#######################

echo 'Disabling SWAP...'
sudo swapoff -a
sudo sed -e'/swap/s/^#*/#/g' -i /etc/fstab

echo 'Changing Hostname...'
hostname=`cat /etc/hostname`
c_name=`kcontrol-"$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 32 | head -n 1 | cut -c1-6)"`
sudo hostname $c_name
sudo sed -i "s/$hostname/$c_name/g" /etc/hostname
sudo sed -i "s/$hostname/$c_name/g" /etc/hosts


##########################
# Distro Spesific Setup
########################

case $(awk -F'[= ]' '/^NAME=/{ gsub(/"/,""); print tolower($2)}' /etc/os-release) in

  ##########################
  # Arch Based Systems
  #######################
  
  "arch")
    echo 'NOT SUPPORTED YET!'
    exit 1
    ;;
  
  ##########################
  # Deb Based Systems
  #######################

  "debian")
    source debian.sh
    debian_install
    ;;

  "ubuntu")
    ;;
  
  ##########################
  # RPM Based Systems
  #######################
  
  "fedora")
    source fedora.sh
    fedora_install
    ;;
  
  "centos")
    echo 'CENTOS IS NOT SUPPORTED!'
    echo 'Unfortunately, if you CentOS you won’t be able to run any pods which depend on other pods (like a db-backend).'
    echo 'The networking of k8s depends on iptables which is not compatible with CentOS/Redhat.'
    exit 1
    ;;

  "opensuse tumbleweed"|"opensuse leap")
    echo 'NOT SUPPORTED YET!'
    exit 1
    ;;

esac


#########################
# Setup Cluster
######################

ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
subnet='10.244.0.0/16'

print_header 'Configuring Kubernetes...'
sudo kubeadm config images pull
sudo kubeadm init --pod-network-cidr=$subnet --apiserver-advertise-address=$ip4

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

exit
# Create Pod Network
echo 'Adding Flannel Network for Pod Communication...'
kubectl apply -f https://docs.projectcalico.org/manifests/canal.yaml

echo ''
echo ''
echo '================================='
echo '  Ready to Attach Worker Nodes!  '
echo '================================='
sudo kubeadm token create --print-join-command
echo ''
