fedora_install(){
  # Prep OS
  echo ''
  echo '-------------------------------------------------------'
  echo 'Starting OS Prep...'
  echo '-------------------------------------------------------'
  echo ''
  echo 'Patching ZRAM on Fedora...'
  sudo touch /etc/systemd/zram-generator.conf 
  sudo swapoff -a

  echo 'Disabling SELinux...'
  sudo setenforce 0
  sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
  
  echo 'Updating System...'
  sudo yum -y update
  sudo dnf -y install dnf-plugins-core

  # Open Firewall
  echo 'Patching Firewall...'
  sudo modprobe br_netfilter
  sudo runuser -l root -c "echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables"
  sudo runuser -l root -c "echo '1' > /proc/sys/net/ipv4/ip_forward"
  sudo systemctl stop firewalld.service
  sudo systemctl disable firewalld.service

  # Patch IPtables
  patch_ip_tables

  # Install Docker
  echo ''
  echo '-------------------------------------------------------'
  echo 'Installing Docker...'
  echo '-------------------------------------------------------'
  echo ''
  sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 

  # Install Kube
  echo ''
  echo '-------------------------------------------------------'
  echo 'Install Kubernetes...'
  echo '-------------------------------------------------------'
  echo ''
  sudo runuser -l root -c "echo '[kubernetes]' > /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'name=Kubernetes' >> /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch' >> /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'enabled=1' >> /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'gpgcheck=1' >> /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'repo_gpgcheck=1' >> /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg' >> /etc/yum.repos.d/kubernetes.repo"
  sudo runuser -l root -c "echo 'exclude=kubelet kubeadm kubectl' >> /etc/yum.repos.d/kubernetes.repo"

  sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
  sudo systemctl start kubelet
  sudo systemctl enable kubelet
}
