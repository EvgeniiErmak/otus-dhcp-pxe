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

## Ход выполнения (пояснения к скриншотам)

Скриншоты в папке [screenshots/](screenshots/) идут в порядке выполнения. Ниже — что происходило на каждом этапе, включая ошибки и их исправление.

### 1. Подготовка и репозиторий
- Проверка хоста: Ubuntu 26.04, AMD Ryzen 9 (AMD-V), 12 ГБ ОЗУ, установлены VirtualBox, Vagrant, Ansible, git.
- Настройка git, создание структуры проекта, скрипт `git_push.sh`.
- Создание репозитория на GitHub через API с Personal access token (classic) и первый push.

### 2. PXE-сервер (Vagrant + Ansible)
- Создание `/etc/vbox/networks.conf`: VirtualBox 7.x без него запрещает адреса 192.168.50.x и 10.0.0.x.
- Vagrantfile, inventory, плейбук и шаблоны; `--syntax-check`, `vagrant validate`.
- `vagrant up pxeserver`: Ansible ставит dnsmasq и apache2, скачивает netboot и ISO Ubuntu 24.04.5 (с проверкой SHA256).
- Проверки: службы `active`, порты 67/69/80, файлы TFTP, ISO и `user-data` отдаются по HTTP (`200 OK`), `pxelinux.0` скачивается по TFTP.
- **Исправление:** ISO 24.04.5 весит 3.9 ГБ, а не 2.6 ГБ, как в методичке, поэтому `ramdisk_size` увеличен до 5000000.

### 3. BIOS-клиент
- `vagrant up pxeclient` заканчивается таймаутом SSH. Это ожидаемо: клиент грузится по сети.
- Лог dnsmasq: DHCP (`DHCPDISCOVER/OFFER/REQUEST/ACK`), TFTP `pxelinux.0`, `default`, `linux`, `initrd`.
- **Ошибка:** `wget: can't connect to remote host (10.0.0.20): Connection timed out` → `Unable to find a live file system on the network`.
  Причина: у клиента две сетевые карты, initramfs взял адрес на NAT-интерфейсе (`enp0s8`, 10.0.3.15) и не видел сервер.
  **Исправление:** в `pxelinux.cfg/default` указан интерфейс `ip=:::::enp0s3:dhcp`.
- Повторная загрузка: ISO скачан по HTTP, автоустановка (`subiquity/Install`, LVM, grub, openssh), `Power down`.
- Ручной шаг: загрузка с диска (`--boot1 disk`), клиент получил адрес с hostname `linux`.
- Вход `otus/123`: Ubuntu 24.04.5 LTS, LVM, адрес на `enp0s3`.
- Обновление README и push.

### 4. UEFI-клиент (задание со звёздочкой)
- Добавлены ВМ `pxeclient-uefi` (EFI), шаблон `grub.cfg`, задача в плейбуке, `client-arch 9` в dnsmasq.
- **Проблема:** клиент пишет `Start PXE over IPv4` → `PXE-E18: Server response timeout`, а в логе dnsmasq пусто.
- **Диагностика** (несколько скриншотов):
  - снимок экрана ВМ (`VBoxManage screenshotpng`): `PXE-E18`, `PXE-E16`, `No bootable option`;
  - `tcpdump` на сервере: `0 packets captured`;
  - смена карты virtio ↔ Intel e1000, отключение `LinkUpDelay`: без изменений;
  - `VBox.log`: карта подключена к `pxenet`, EFI-драйверы сети загружены;
  - запись трафика на карте ВМ (`--nictrace1`): прошивка отправляет только IPv6, DHCP по IPv4 нет;
  - попытки через iPXE: `ipxe.efi` завис; `snponly.efi` не видит сетевых карт; `ipxe.efi` через SNP: `No configuration methods succeeded`, `TX:0`;
  - ошибка запуска `Failed to get MAC address (VERR_CFGM_VALUE_NOT_FOUND)`: осталась настройка `LinkUpDelay` от e1000 при карте virtio, удалена;
  - контрольный опыт: та же ВМ `pxeclient` в BIOS получает DHCP, а после переключения в UEFI — `0 packets`.
- **Причина:** сеть в режиме UEFI не работает в сборке VirtualBox из репозитория Ubuntu (`virtualbox 7.2.6-dfsg`).
- **Исправление:** пакет Ubuntu удалён, установлен VirtualBox **7.2.20 от Oracle** (модули ядра собраны, ВМ сохранились).
- Проверка после замены: пакеты из UEFI-клиента доходят до сервера. На `pxeclient-uefi` (virtio):
  DHCP `PXEClient:Arch:00007` → `bootx64.efi` (shim) → `grubx64.efi` → `grub/grub.cfg` → `linux` → `initrd`.
  Чёрный экран ВМ нормален: вывод GRUB и ядра идёт в serial-консоль (`pxeclient-uefi-serial.log`).
- **Проблема:** через virtio ISO скачивался со скоростью ~300 КБ/с (ETA больше 3 часов).
  С картами Intel (82540EM, 82545EM) прошивка UEFI не создаёт PXE-пункт: `No bootable option or device was found`.
  **Исправление:** NIC1 virtio — для PXE-загрузки прошивки, NIC3 Intel e1000 в `pxenet` — для скачивания ISO (`ip=:::::enp0s9:dhcp` в `grub.cfg`).
- Результат: меню GRUB `Ubuntu 24.04 autoinstall (UEFI, HTTP)`, быстрое скачивание ISO, автоустановка с `efibootmgr`, `grub-efi-amd64`, `shim-signed`, `Power down`.
- Загрузка с диска, вход `otus/123`: `BOOT MODE: UEFI`, раздел `vfat` в `/boot/efi`, Ubuntu 24.04.5 LTS.
- Итоговый Vagrantfile с рабочей конфигурацией UEFI-клиента, обновление README, push.
