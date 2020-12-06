#!/usr/bin/env sh

print_header(){
  echo ''
  echo '-------------------------------------------------------'
  echo "$1"
  echo '-------------------------------------------------------'
  echo ''
}

fedora_install(){
  #####################################
  print_header 'Starting OS Prep...'
  ##################################

  echo 'Patching ZRAM on Fedora...'
  sudo touch /etc/systemd/zram-generator.conf 
  sudo swapoff -a

  echo 'Disabling SELinux...'
  sudo setenforce 0
  sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

  echo 'Patching Firewall...'
  sudo systemctl stop firewalld.service
  sudo systemctl disable firewalld.service
  
  echo 'Updating System...'
  sudo yum -y update
  sudo dnf -y install dnf-plugins-core


  #####################################
  print_header 'Installing CRI-O...'
  ##################################

  sudo dnf -y module enable cri-o:nightly
  sudo dnf install -y cri-o
  sudo systemctl enable crio
  sudo systemctl start crio

  # Add CRI-O Conf For Kube
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
  print_header 'Install Kubernetes...'
  ##################################

  # Add Repo
  sudo runuser -l root -c "echo '[kubernetes]' > /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'name=Kubernetes' >> /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch' >> /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'enabled=1' >> /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'gpgcheck=1' >> /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'repo_gpgcheck=1' >> /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg' >> /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'exclude=kubelet kubeadm kubectl' >> /etc/yum.repos.d/kubernetes.repo"
  
  # Add Launch Conf
  # sudo runuser -l root -c "echo 'KUBELET_EXTRA_ARGS=--cgroup-driver=systemd' > /etc/sysconfig/kubelet"
  sudo runuser -l root -c "echo 'KUBELET_EXTRA_ARGS=--cgroup-driver=systemd --container-runtime=remote --container-runtime-endpoint=\"unix:///var/run/crio/crio.sock\"' >/etc/sysconfig/kubelet"

  # Install
  sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
  sudo systemctl start kubelet
  sudo systemctl enable kubelet
}
