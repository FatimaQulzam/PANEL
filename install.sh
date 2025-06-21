#!/bin/bash
set -e

export GITHUB_SOURCE="v1.1.1"
export SCRIPT_RELEASE="v1.1.1"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/FatimaQulzam/SERVER"
LOG_PATH="/var/log/pterodactyl-installer.log"
LIB_PATH="/tmp/htd-lib.sh" # ✅ custom file path to avoid clashes

# Check for curl
if ! command -v curl >/dev/null 2>&1; then
  echo "* curl is required for this script to work."
  echo "* install it using apt (Debian/Ubuntu) or yum/dnf (CentOS/RHEL)"
  exit 1
fi

# Remove old lib.sh if exists
[ -f "$LIB_PATH" ] && rm -f "$LIB_PATH"

# Download lib.sh safely
echo "* Downloading lib.sh from GitHub..."
if ! curl -fsSL -o "$LIB_PATH" "$GITHUB_BASE_URL/master/lib/lib.sh"; then
  echo "❌ Failed to download lib.sh from $GITHUB_BASE_URL"
  exit 1
fi

# Check if lib.sh is valid
if ! grep -q "^#!/bin/bash" "$LIB_PATH"; then
  echo "❌ Invalid lib.sh file downloaded. It may be a 404 page or corrupted."
  cat "$LIB_PATH" | head -n 10
  exit 1
fi

# shellcheck source=/dev/null
source "$LIB_PATH"

execute() {
  echo -e "\n\n* pterodactyl-installer $(date) \n\n" >>"$LOG_PATH"

  [[ "$1" == *"canary"* ]] && export GITHUB_SOURCE="master" && export SCRIPT_RELEASE="canary"
  update_lib_source
  run_ui "${1//_canary/}" |& tee -a "$LOG_PATH"

  if [[ -n $2 ]]; then
    echo -n "* Installation of $1 completed. Do you want to proceed to $2 installation? (y/N): "
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
    "Install both [0] and [1] on the same machine (wings script runs after panel)"
    "Install panel with canary version of the script (may be broken!)"
    "Install Wings with canary version of the script (may be broken!)"
    "Install both [3] and [4] on the same machine (wings script runs after panel)"
    "Uninstall panel or wings with canary version of the script (may be broken!)"
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

# Clean up
rm -f "$LIB_PATH"
