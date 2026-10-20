#!/usr/bin/env bash
# Создание публичного репозитория на GitHub (если его нет) и push через PAT (classic).
# Использование: ./git_push.sh "сообщение коммита"
set -euo pipefail

GH_USER="EvgeniiErmak"
GH_EMAIL="djermak3000@mail.ru"
REPO="otus-dhcp-pxe"
MSG="${1:-update}"
API="https://api.github.com"

cd "$(dirname "$(readlink -f "$0")")"

# Токен: из переменной GH_TOKEN или скрытым вводом
if [[ -z "${GH_TOKEN:-}" ]]; then
  read -rsp "Personal access token (classic): " GH_TOKEN; echo
fi
HDR=(-H "Authorization: token ${GH_TOKEN}" -H "Accept: application/vnd.github+json")

# 1. Проверка токена
code=$(curl -s -o /dev/null -w '%{http_code}' "${HDR[@]}" "${API}/user")
[[ "$code" == "200" ]] || { echo "!!! Токен не принят GitHub (HTTP $code)"; exit 1; }

# 2. Создание репозитория, если его нет
code=$(curl -s -o /dev/null -w '%{http_code}' "${HDR[@]}" "${API}/repos/${GH_USER}/${REPO}")
if [[ "$code" == "404" ]]; then
  echo ">>> Создаю репозиторий ${GH_USER}/${REPO}"
  curl -sf "${HDR[@]}" -X POST "${API}/user/repos" \
    -d "{\"name\":\"${REPO}\",\"private\":false,\"description\":\"OTUS: DHCP + PXE, autoinstall Ubuntu 24.04 (Vagrant + Ansible)\"}" >/dev/null
  echo ">>> Репозиторий создан: https://github.com/${GH_USER}/${REPO}"
else
  echo ">>> Репозиторий уже существует (HTTP $code)"
fi

# 3. Локальный git
[[ -d .git ]] || git init -b main
git config user.name  "$GH_USER"
git config user.email "$GH_EMAIL"
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/${GH_USER}/${REPO}.git"
chmod +x git_push.sh
git add -A
git diff --cached --quiet && echo ">>> Нет новых изменений для коммита" || git commit -m "$MSG"

# 4. Авторизация только на время команды (токен не пишется в .git/config)
AUTH=$(printf '%s:%s' "$GH_USER" "$GH_TOKEN" | base64 -w0)
GITA=(git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic ${AUTH}")

# 5. Подтягиваем изменения, сделанные через браузер (скриншоты)
if "${GITA[@]}" ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
  "${GITA[@]}" pull --rebase origin main
fi

# 6. Push
"${GITA[@]}" push -u origin main
echo ">>> Готово: https://github.com/${GH_USER}/${REPO}"
