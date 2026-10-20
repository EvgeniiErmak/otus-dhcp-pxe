# OTUS: DHCP, PXE — автоматическая установка Ubuntu 24.04 по сети

Стенд **Vagrant + VirtualBox + Ansible**: PXE-сервер раздаёт по сети установщик Ubuntu 24.04,
клиенты загружаются по PXE (**BIOS** и **UEFI**) и ставят ОС автоматически (`autoinstall`, `user-data`).
ISO-образ клиент получает по **HTTP**.

## Структура репозитория

| Путь | Назначение |
|------|------------|
| [Vagrantfile](Vagrantfile) | ВМ `pxeserver`, `pxeclient` (BIOS), `pxeclient-uefi` (UEFI) |
| [ansible/](ansible/) | Настройка PXE-сервера |
| [ansible/provision.yml](ansible/provision.yml) | Плейбук: dnsmasq, apache2, netboot, ISO, user-data, grub.cfg |
| [ansible/hosts](ansible/hosts) | Inventory |
| [ansible/templates/](ansible/templates/) | `pxe.conf`, `pxelinux-default`, `grub.cfg`, `ks-server.conf`, `user-data` |
| [screenshots/](screenshots/) | Скриншоты выполнения |
| [git_push.sh](git_push.sh) | Создание репозитория на GitHub и push (PAT classic) |

## Стенд

| ВМ | Сети | IP |
|----|------|----|
| pxeserver | NAT / intnet `pxenet` / host-only (Ansible) | 10.0.2.15 / **10.0.0.20** / 192.168.50.10 |
| pxeclient (BIOS) | intnet `pxenet` (enp0s3) / NAT | DHCP 10.0.0.100–120 |
| pxeclient-uefi (UEFI) | intnet `pxenet` virtio (PXE) / NAT / intnet `pxenet` e1000 (enp0s9, ISO) | DHCP 10.0.0.100–120 |

| Компонент | Роль |
|-----------|------|
| dnsmasq | DHCP + TFTP. BIOS → `pxelinux.0`, UEFI (client-arch 7/9) → `bootx64.efi` |
| apache2 | HTTP: ISO `/srv/images/noble-live-server-amd64.iso`, autoinstall `/srv/ks/` |

Цепочки загрузки:

- **BIOS:** DHCP → TFTP `pxelinux.0` → `pxelinux.cfg/default` → `linux` + `initrd` → HTTP ISO + `user-data` → установка
- **UEFI:** DHCP → TFTP `bootx64.efi` (shim) → `grubx64.efi` → `grub/grub.cfg` → `linux` + `initrd` → HTTP ISO + `user-data` → установка

## Требования

- VirtualBox **от Oracle** (проверено 7.2.20). В сборке из репозитория Ubuntu (`virtualbox 7.2.6-dfsg`)
  сеть в режиме UEFI не работает: пакеты EFI-клиента не доходят до сервера.
- Разрешить сети стенда: `echo "* 10.0.0.0/8 192.168.0.0/16" > /etc/vbox/networks.conf`

## Запуск

```bash
vagrant up pxeserver                         # сервер + Ansible
vagrant up pxeclient                         # BIOS-клиент (таймаут SSH ожидаем)
tail -f pxeclient-serial.log                 # ход установки
vagrant up pxeclient-uefi                    # UEFI-клиент (таймаут SSH ожидаем)
tail -f pxeclient-uefi-serial.log
```

## Ручные шаги

После установки ВМ выключается сама (`shutdown: poweroff`). Загрузка с диска:

```bash
VBoxManage modifyvm pxeclient      --boot1 disk
VBoxManage startvm  pxeclient      --type headless
VBoxManage modifyvm pxeclient-uefi --boot1 disk
VBoxManage startvm  pxeclient-uefi --type headless
```

Вход (логин `otus`, пароль `123`):

```bash
vagrant ssh pxeserver -c 'cat /var/lib/misc/dnsmasq.leases'   # IP клиентов
vagrant ssh pxeserver
ssh otus@10.0.0.1xx
```

## Отличия от методички

| Что | Почему |
|-----|--------|
| ISO/netboot с `releases.ubuntu.com/24.04` (последний 24.04.x, SHA256) | `daily-live/current` больше не содержит noble |
| `ip=:::::enp0s3:dhcp` (BIOS), `ip=:::::enp0s9:dhcp` (UEFI) | у клиентов несколько NIC, initramfs брал адрес с NAT |
| `ramdisk_size=5000000`, ОЗУ клиента 8 ГБ | ISO 24.04.5 ≈ 3.9 ГБ загружается в память |
| UEFI-клиент: NIC1 virtio + NIC3 e1000 | UEFI VirtualBox даёт PXE только с virtio; virtio в Linux качает ISO очень медленно |
| `apt.fallback: offline-install`, `shutdown: poweroff` | установка без интернета; не грузиться снова по сети |
| Serial-консоль клиентов в `*-serial.log` | хост без GUI |

## Результат

- **BIOS:** Ubuntu 24.04.5 установлена автоматически по сети (hostname `linux`, пользователь `otus`, LVM).
- **UEFI\*:** Ubuntu 24.04.5 установлена автоматически по сети, загружается в режиме UEFI (`/boot/efi`, shim + grub-efi).

Скриншоты — в папке [screenshots/](screenshots/).
