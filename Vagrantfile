# -*- mode: ruby -*-
# vi: set ft=ruby :
# OTUS: DHCP + PXE. Автоматическая установка Ubuntu 24.04 по сети.

Vagrant.configure("2") do |config|

  # PXE-сервер: dnsmasq (DHCP + TFTP) + apache2 (HTTP)
  config.vm.define "pxeserver" do |server|
    server.vm.box = 'bento/ubuntu-22.04'
    server.vm.host_name = 'pxeserver'
    server.vm.network "forwarded_port", guest: 80, host: 8080
    # Сеть PXE (internal network VirtualBox)
    server.vm.network :private_network,
                      ip: "10.0.0.20",
                      virtualbox__intnet: 'pxenet'
    # Сеть для Ansible
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

  # PXE-клиент: загрузка только по сети (BIOS / Legacy)
  config.vm.define "pxeclient" do |pxeclient|
    pxeclient.vm.box = 'bento/ubuntu-22.04'
    pxeclient.vm.host_name = 'pxeclient'
    pxeclient.vm.network :private_network, ip: "10.0.0.21"
    pxeclient.vm.synced_folder ".", "/vagrant", disabled: true
    # SSH на клиенте не поднимется (он грузится по сети) — не ждём долго
    pxeclient.vm.boot_timeout = 30
    pxeclient.vm.provider :virtualbox do |vb|
      vb.name   = "pxeclient"
      # ISO 24.04 (~3.2 ГБ) загружается в ОЗУ клиента
      vb.memory = "8192"
      vb.cpus   = 2
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize [
        'modifyvm', :id,
        '--nic1', 'intnet',
        '--intnet1', 'pxenet',
        '--nic2', 'nat',
        '--boot1', 'net',
        '--boot2', 'none',
        '--boot3', 'none',
        '--boot4', 'none'
      ]
      # Последовательная консоль клиента в файл — смотрим загрузку по SSH через tail -f
      vb.customize [
        'modifyvm', :id,
        '--uart1', '0x3F8', '4',
        '--uartmode1', 'file', File.join(__dir__, 'pxeclient-serial.log')
      ]
    end
  end

end
