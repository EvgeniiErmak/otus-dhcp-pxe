# OTUS: DHCP, PXE — автоматическая установка Ubuntu 24.04 по сети

Стенд **Vagrant + VirtualBox + Ansible**: PXE-сервер раздаёт по сети установщик Ubuntu 24.04,
клиент загружается по PXE (BIOS) и устанавливает ОС автоматически (`autoinstall`, файл `user-data`).
ISO-образ клиент получает по **HTTP**.

## Структура репозитория

| Путь | Назначение |
|------|------------|
| [Vagrantfile](Vagrantfile) | ВМ `pxeserver` и `pxeclient` |
| [ansible/](ansible/) | Настройка PXE-сервера |
| [ansible/provision.yml](ansible/provision.yml) | Плейбук: dnsmasq, apache2, netboot, ISO, user-data |
| [ansible/hosts](ansible/hosts) | Inventory |
| [ansible/templates/](ansible/templates/) | Шаблоны: `pxe.conf`, `pxelinux.cfg/default`, `ks-server.conf`, `user-data` |
| [screenshots/](screenshots/) | Скриншоты выполнения |
| [git_push.sh](git_push.sh) | Создание репозитория на GitHub и push (PAT classic) |

## Стенд

| ВМ | Сети | IP |
|----|------|----|
| pxeserver | NAT / intnet `pxenet` / host-only (Ansible) | 10.0.2.15 / **10.0.0.20** / 192.168.50.10 |
| pxeclient | intnet `pxenet` (enp0s3) / NAT (enp0s8), загрузка: сеть | DHCP 10.0.0.100–120 |

| Компонент на pxeserver | Роль |
|------------------------|------|
| dnsmasq | DHCP + TFTP: `pxelinux.0`, `linux`, `initrd` из netboot-архива Ubuntu 24.04 |
| apache2 | HTTP: `/srv/images/noble-live-server-amd64.iso` и `/srv/ks/{user-data,meta-data}` |
| iptables NAT | Выход клиента в интернет через сервер во время установки |

Процесс загрузки: **DHCP** (адрес + `pxelinux.0`) → **TFTP** (`pxelinux.0`, `default`, `linux`, `initrd`) →
**HTTP** (ISO в ОЗУ, `user-data`) → autoinstall → выключение ВМ.

## Запуск

```bash
# 1. Разрешить VirtualBox 7.x сети стенда (однократно, на хосте)
mkdir -p /etc/vbox && echo "* 10.0.0.0/8 192.168.0.0/16" > /etc/vbox/networks.conf

# 2. Сервер (создание + Ansible)
vagrant up pxeserver

# 3. Клиент: загрузка по PXE и автоустановка.
#    Ошибка "Timed out while waiting for the machine to boot" ожидаема — SSH у клиента нет.
vagrant up pxeclient
tail -f pxeclient-serial.log          # консоль клиента (serial)
```

## Ручные шаги

После установки ВМ выключается сама (`shutdown: poweroff`). Загрузка с диска:

```bash
VBoxManage modifyvm pxeclient --boot1 disk --boot2 none --boot3 none --boot4 none
VBoxManage startvm pxeclient --type headless
```

Вход в установленную систему (логин `otus`, пароль `123`):

```bash
vagrant ssh pxeserver -c 'cat /var/lib/misc/dnsmasq.leases'   # IP клиента
vagrant ssh pxeserver
ssh otus@10.0.0.1xx
```

## Отличия от методички

| Что | Почему |
|-----|--------|
| ISO/netboot с `releases.ubuntu.com/24.04` (последний 24.04.x, проверка SHA256) | `daily-live/current` больше не содержит noble |
| `ip=:::::enp0s3:dhcp` вместо `ip=dhcp` | у клиента 2 сетевые карты, initramfs брал адрес с NAT и не видел сервер |
| `ramdisk_size=5000000`, ОЗУ клиента 8 ГБ | ISO 24.04.5 ≈ 3.9 ГБ, загружается в память |
| `apt.fallback: offline-install`, `shutdown: poweroff` | установка без интернета; не загружаться повторно по сети |
| Serial-консоль клиента в `pxeclient-serial.log` | хост без GUI, процесс виден в терминале |

## Результат

Клиент получил адрес по DHCP, загрузился по PXE, скачал ISO по HTTP и установил
**Ubuntu 24.04.5 LTS** без участия пользователя (hostname `linux`, пользователь `otus`, LVM).
Скриншоты — в папке [screenshots/](screenshots/).
