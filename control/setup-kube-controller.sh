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
sudo hostnamectl set-hostname $c_name
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
    fedora_install
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

echo ''
echo ''
echo '================================='
echo '  Ready to Attach Worker Nodes!  '
echo '================================='
echo ''
kubectl get nodes
echo ''
echo '===================='
echo ''
kubectl get pods --all-namespaces
echo ''
echo '===================='
echo ''
kubeadm token create --print-join-command
echo ''
echo '===================='
