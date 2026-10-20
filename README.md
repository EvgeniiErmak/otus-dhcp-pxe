# OTUS: DHCP, PXE — автоматическая установка Ubuntu 24.04 по сети

Стенд **Vagrant + VirtualBox + Ansible**: PXE-сервер раздаёт по сети установщик Ubuntu 24.04,
клиент загружается по PXE и устанавливает ОС автоматически (`autoinstall`, файл `user-data`).

## Структура репозитория

| Путь | Назначение |
|------|------------|
| [Vagrantfile](Vagrantfile) | Описание ВМ `pxeserver` и `pxeclient` |
| [ansible/](ansible/) | Ansible-плейбук настройки PXE-сервера |
| [screenshots/](screenshots/) | Скриншоты выполнения задания |
| [git_push.sh](git_push.sh) | Создание репозитория на GitHub и push (PAT classic) |

## Компоненты PXE-сервера

| Компонент | Роль |
|-----------|------|
| dnsmasq | DHCP + TFTP (`pxelinux.0`, `linux`, `initrd`) |
| apache2 | HTTP: ISO-образ (`/srv/images`) и autoinstall (`/srv/ks/user-data`) |

## Стенд

| ВМ | Сеть | IP |
|----|------|----|
| pxeserver | intnet `pxenet` / host-only (Ansible) | 10.0.0.20 / 192.168.50.10 |
| pxeclient | intnet `pxenet`, загрузка по сети | DHCP 10.0.0.100–120 |

## Запуск

```
vagrant up pxeserver   # создание и настройка сервера через Ansible
vagrant up pxeclient   # загрузка клиента по PXE и автоустановка
```
