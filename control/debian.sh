#!/usr/bin/env sh

print_header(){
  echo ''
  echo '-------------------------------------------------------'
  echo "$1"
  echo '-------------------------------------------------------'
  echo ''
}

debian_install(){

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


  #####################################
  print_header 'Configuring Kubernetes...'
  ##################################

  ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
  subnet='10.244.0.0/16'

  sudo kubeadm config images pull
  sudo kubeadm init --apiserver-advertise-address=$ip4 --pod-network-cidr=$subnet --cri-socket=/var/run/crio/crio.sock

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # Create Pod Network
  echo 'Adding Calico Network for Pod Communication...'
  kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
  # echo 'Adding Flannel Network for Pod Communication...'
  # kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

}
