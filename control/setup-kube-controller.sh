#!/usr/bin/env sh


##########################
# Generic Sys Setup
#######################

# Disable Swap
echo 'Disabling SWAP...'
sudo swapoff -a
sudo sed -e'/swap/s/^#*/#/g' -i /etc/fstab

# Change Hostname
echo 'Changing Hostname...'
hostname=`cat /etc/hostname`
c_id=`cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 32 | head -n 1 | cut -c1-6`
c_name="kcontrol-$c_id"

sudo sed -i "s/$hostname/$c_name/g" /etc/hosts
sudo hostname $c_name
sudo sed -i "s/$hostname/$c_name/g" /etc/hostname

##########################
# Distro Spesific Setup
########################

distro=$(awk -F'[= ]' '/^NAME=/{ gsub(/"/,""); print tolower($2)}' /etc/os-release)

case $distro in
  "arch")
    echo 'NOT SUPPORTED YET!'
    exit 1
    ;;
  
  ##########################
  # Debian Based Systems
  #######################

  "debian")
    . $(dirname "$0")/debian.sh
    debian_install
    ;;

  "ubuntu")
    ;;
  
  ##########################
  # RHL Based Systems
  #######################
  
  "fedora")
    . $(dirname "$0")/fedora.sh
    ;;
  
  "centos")
    echo 'CENTOS IS NOT SUPPORTED!'
    echo 'Unfortunately, CentOS won’t be able to run any pods which depend on other pods (like a db-backend).'
    echo 'The networking of k8s depends on iptables which is not compatible with CentOS/Redhat.'
    exit 1
    ;;
  
  ##########################
  # SUSE Based Systems
  #######################

  "opensuse tumbleweed")
    echo 'NOT SUPPORTED YET!'
    exit 1
    ;;

  "opensuse leap")
    echo 'NOT SUPPORTED YET!'
    exit 1
    ;;

esac


#########################
# Setup Cluster
######################

ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
subnet='10.244.10.0/16'

print_header 'Configuring Kubernetes...'
sudo kubeadm config images pull
sudo kubeadm init --apiserver-advertise-address=$ip4 --pod-network-cidr=$subnet --cri-socket=/var/run/crio/crio.sock

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Create Pod Network
echo 'Adding Flannel Network for Pod Communication...'
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml


echo ''
echo ''
echo '================================='
echo '  Ready to Attach Worker Nodes!  '
echo '================================='
sudo kubeadm token create --print-join-command
echo ''
