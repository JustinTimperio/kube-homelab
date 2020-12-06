#!/usr/bin/env sh

debian_install(){
  # Prep OS
  echo ''
  echo '-------------------------------------------------------'
  echo 'Starting OS Package Prep...'
  echo '-------------------------------------------------------'
  echo ''

  sudo apt -y update
  sudo apt -y install apt-transport-https curl gnupg2 software-properties-common

  # Patch IPtables
  sudo runuser -l root -c "echo 'net.bridge.bridge-nf-call-iptables = 1' > /etc/sysctl.d/99-kubernetes-cri.conf"
  sudo runuser -l root -c "echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-kubernetes-cri.conf"
  sudo runuser -l root -c "echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.d/99-kubernetes-cri.conf"

  sudo modprobe overlay
  sudo modprobe br_netfilter
  sudo sysctl --system

  echo ''
  echo '-------------------------------------------------------'
  echo 'Installing CRI-O...'
  echo '-------------------------------------------------------'
  echo ''

  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8BECF1637AD8C79D
  sudo runuser -l root -c "echo 'deb http://ppa.launchpad.net/projectatomic/ppa/ubuntu bionic main' > /etc/apt/sources.list.d/projectatomics.list"
  sudo runuser -l root -c "echo 'deb-src http://ppa.launchpad.net/projectatomic/ppa/ubuntu bionic main' >> /etc/apt/sources.list.d/projectatomics.list"
  sudo apt update
  sudo apt install -y cri-o-1.15 containernetworking-plugins
  sudo sed 's/\/usr\/libexec\/crio\/conmon/\/usr\/bin\/conmon/g' /etc/crio/crio.conf
  sudo curl https://raw.githubusercontent.com/projectatomic/registries/master/registries.fedora -o /etc/containers/registries.conf


  # Install Kube
  echo ''
  echo '-------------------------------------------------------'
  echo 'Install Kubernetes...'
  echo '-------------------------------------------------------'
  echo ''

  sudo runuser -l root -c "echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list"
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  sudo apt update
  sudo apt install -y kubeadm kubelet kubectl
  sudo apt-mark hold kubelet kubeadm kubectl
  
  sudo runuser -l root -c "echo 'KUBELET_EXTRA_ARGS=--cgroup-driver=systemd --container-runtime=remote --container-runtime-endpoint=\"unix:///var/run/crio/crio.sock\"' > /etc/default/kubelet"

  sudo systemctl daemon-reload
  sudo systemctl start kubelet
  sudo systemctl enable kubelet
}
