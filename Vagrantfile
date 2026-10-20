# -*- mode: ruby -*-
# vi: set ft=ruby :
# OTUS: DHCP + PXE. Автоматическая установка Ubuntu 24.04 по сети (BIOS и UEFI).

Vagrant.configure("2") do |config|

  # PXE-сервер: dnsmasq (DHCP + TFTP) + apache2 (HTTP)
  config.vm.define "pxeserver" do |server|
    server.vm.box = 'bento/ubuntu-22.04'
    server.vm.host_name = 'pxeserver'
    server.vm.network "forwarded_port", guest: 80, host: 8080
    server.vm.network :private_network,
                      ip: "10.0.0.20",
                      virtualbox__intnet: 'pxenet'
    server.vm.network :private_network, ip: "192.168.50.10", adapter: 3
    server.vm.provider "virtualbox" do |vb|
      vb.name   = "pxeserver"
      vb.memory = "1024"
      vb.cpus   = 2
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end
    server.vm.provision "ansible" do |ansible|
      ansible.playbook          = "ansible/provision.yml"
      ansible.inventory_path    = "ansible/hosts"
      ansible.host_key_checking = "false"
      ansible.limit             = "all"
    end
  end

  # PXE-клиент BIOS (Legacy)
  config.vm.define "pxeclient" do |pxeclient|
    pxeclient.vm.box = 'bento/ubuntu-22.04'
    pxeclient.vm.host_name = 'pxeclient'
    pxeclient.vm.network :private_network, ip: "10.0.0.21"
    pxeclient.vm.synced_folder ".", "/vagrant", disabled: true
    pxeclient.vm.boot_timeout = 30
    pxeclient.vm.provider :virtualbox do |vb|
      vb.name   = "pxeclient"
      vb.memory = "8192"
      vb.cpus   = 2
      vb.customize [
        'modifyvm', :id,
        '--nic1', 'intnet', '--intnet1', 'pxenet',
        '--nic2', 'nat',
        '--boot1', 'net', '--boot2', 'none', '--boot3', 'none', '--boot4', 'none'
      ]
      vb.customize [
        'modifyvm', :id,
        '--uart1', '0x3F8', '4',
        '--uartmode1', 'file', File.join(__dir__, 'pxeclient-serial.log')
      ]
    end
  end

  # PXE-клиент UEFI (задание со звёздочкой). Не стартует при обычном "vagrant up".
  # NIC1 virtio  - UEFI PXE (прошивка VirtualBox создаёт PXE-пункт только для virtio)
  # NIC3 e1000   - скачивание ISO установщиком (enp0s9, быстро)
  config.vm.define "pxeclient-uefi", autostart: false do |uefi|
    uefi.vm.box = 'bento/ubuntu-22.04'
    uefi.vm.host_name = 'pxeclient-uefi'
    uefi.vm.network :private_network, ip: "10.0.0.22"
    uefi.vm.synced_folder ".", "/vagrant", disabled: true
    uefi.vm.boot_timeout = 30
    uefi.vm.provider :virtualbox do |vb|
      vb.name   = "pxeclient-uefi"
      vb.memory = "8192"
      vb.cpus   = 2
      vb.customize [
        'modifyvm', :id,
        '--firmware', 'efi',
        '--nic1', 'intnet', '--intnet1', 'pxenet', '--nictype1', 'virtio', '--macaddress1', '080027AA0022',
        '--nic2', 'nat', '--nictype2', '82540EM',
        '--nic3', 'intnet', '--intnet3', 'pxenet', '--nictype3', '82540EM', '--macaddress3', '080027AA0033',
        '--boot1', 'net', '--boot2', 'none', '--boot3', 'none', '--boot4', 'none'
      ]
      vb.customize [
        'modifyvm', :id,
        '--uart1', '0x3F8', '4',
        '--uartmode1', 'file', File.join(__dir__, 'pxeclient-uefi-serial.log')
      ]
    end
  end

end
