#!/bin/bash
set -e

export GITHUB_SOURCE="v1.1.1"
export SCRIPT_RELEASE="v1.1.1"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/FatimaQulzam/SERVER"
export LIB_URL="$GITHUB_BASE_URL/master/lib/lib.sh"
LOG_PATH="/var/log/pterodactyl-installer.log"

# Check curl
if ! command -v curl >/dev/null 2>&1; then
  echo "❌ curl is required. Install using apt, yum, or dnf."
  exit 1
fi

# Check if lib.sh is reachable and valid
if ! curl -fsSL "$LIB_URL" | grep -q "^#!/bin/bash"; then
  echo "❌ Could not fetch valid lib.sh from GitHub!"
  curl -s "$LIB_URL" | head -n 10
  exit 1
fi

# ✅ Source lib.sh directly (NO /tmp usage at all)
# shellcheck disable=SC1090
source <(curl -fsSL "$LIB_URL")

execute() {
  echo -e "\n\n* pterodactyl-installer $(date) \n\n" >>"$LOG_PATH"

  [[ "$1" == *"canary"* ]] && export GITHUB_SOURCE="master" && export SCRIPT_RELEASE="canary"
  update_lib_source
  run_ui "${1//_canary/}" |& tee -a "$LOG_PATH"

  if [[ -n $2 ]]; then
    echo -n "* Installation of $1 completed. Proceed to $2 installation? (y/N): "
    read -r CONFIRM
    if [[ "$CONFIRM" =~ [Yy] ]]; then
      execute "$2"
    else
      error "Installation of $2 aborted."
      exit 1
    fi
  fi
}

welcome ""

done=false
while [ "$done" == false ]; do
  options=(
    "Install the panel"
    "Install Wings"
    "Install both [0] and [1] on the same machine"
    "Install panel with canary version"
    "Install Wings with canary version"
    "Install both [3] and [4] on same machine"
    "Uninstall panel or wings with canary version"
  )

  actions=(
    "panel"
    "wings"
    "panel;wings"
    "panel_canary"
    "wings_canary"
    "panel_canary;wings_canary"
    "uninstall_canary"
  )

  output "What would you like to do?"
  for i in "${!options[@]}"; do
    output "[$i] ${options[$i]}"
  done

  echo -n "* Input 0-$((${#actions[@]} - 1)): "
  read -r action

  [ -z "$action" ] && error "Input is required" && continue

  valid_input=("$(for ((i = 0; i < ${#actions[@]}; i++)); do echo "$i"; done)")
  if [[ ! " ${valid_input[*]} " =~ " ${action} " ]]; then
    error "Invalid option"
    continue
  fi

  done=true
  IFS=";" read -r i1 i2 <<<"${actions[$action]}"
  execute "$i1" "$i2"
done
