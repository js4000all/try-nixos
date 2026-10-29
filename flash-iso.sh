#!/usr/bin/env bash
set -euo pipefail

# This script intentionally accepts no target argument: the operator selects it interactively.
if (( $# != 0 )); then
  printf 'Usage: %s (select target interactively)\n' "$0" >&2
  exit 2
fi
for tool in lsblk find stat dd sudo; do
  command -v "$tool" >/dev/null || { echo "Missing command: $tool" >&2; exit 1; }
done
[[ -t 0 && -t 1 ]] || { echo 'Interactive terminal required.' >&2; exit 1; }

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
dist_dir="$repo_dir/dist"
[[ -d "$dist_dir" ]] || { echo "ISO directory not found: $dist_dir" >&2; exit 1; }
shopt -s nullglob
isos=("$dist_dir"/*.iso)
shopt -u nullglob
if (( ${#isos[@]} != 1 )); then
  printf 'Expected exactly one ISO in %s; found %s.\n' "$dist_dir" "${#isos[@]}" >&2
  exit 1
fi
iso="${isos[0]}"
[[ -f "$iso" && ! -L "$iso" ]] || { echo 'ISO must be a regular, non-symlink file.' >&2; exit 1; }
iso_size="$(stat -c '%s' -- "$iso")"
(( iso_size > 0 )) || { echo 'ISO is empty.' >&2; exit 1; }

# Upper capacity bound in GiB (not GB); override e.g. MAX_DEVICE_GIB=64 make flash.
max_device_gib="${MAX_DEVICE_GIB:-32}"
[[ "$max_device_gib" =~ ^[1-9][0-9]*$ ]] || {
  echo 'MAX_DEVICE_GIB must be a positive integer.' >&2; exit 1;
}
# Reject values large enough to overflow signed 64-bit shell arithmetic.
(( ${#max_device_gib} <= 9 )) || { echo 'MAX_DEVICE_GIB is too large.' >&2; exit 1; }
max_device_bytes=$((max_device_gib * 1024 * 1024 * 1024))

# USB-connected disks only, not partitions. RM=0 USB disks are also listed,
# since some USB flash drives report themselves as non-removable.
mapfile -t candidates < <(lsblk -bdnpr -o PATH,TYPE,TRAN,SIZE | awk -v limit="$max_device_bytes"   '$2 == "disk" && $3 == "usb" && $4 ~ /^[0-9]+$/ && $4 <= limit {print $1}')
if (( ${#candidates[@]} == 0 )); then
  printf 'No USB-connected disks at or below %s GiB found.\n' "$max_device_gib" >&2
  exit 1
fi

printf 'ISO: %s (%s bytes)\n\n' "$iso" "$iso_size"
printf 'USB-connected disk candidates (up to %s GiB; not necessarily flash drives):\n' "$max_device_gib"
printf '  %-4s %-18s %-10s %-4s %s\n' 'No.' 'Device' 'Size' 'RM' 'Model'
for i in "${!candidates[@]}"; do
  device="${candidates[$i]}"
  printf '  %-4s ' "$((i + 1))"
  lsblk -dn -o PATH,SIZE,RM,MODEL -- "$device"
done
printf '\nSelect device number (or q to quit): '
IFS= read -r selection
[[ "$selection" != q ]] || exit 0
[[ "$selection" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid selection.' >&2; exit 1; }
index=$((10#$selection - 1))
(( index < ${#candidates[@]} )) || { echo 'Selection out of range.' >&2; exit 1; }
device="${candidates[$index]}"

# Preserve the selected identity for a second inspection immediately before writing.
identity="$(lsblk -dn -o MAJ:MIN -- "$device")"

validate_target() {
  [[ -b "$device" ]] || { echo 'Target is no longer a block device.' >&2; return 1; }
  [[ "$(lsblk -dn -o TYPE -- "$device")" == disk ]] || { echo 'Not a whole disk.' >&2; return 1; }
  [[ "$(lsblk -dn -o TRAN -- "$device")" == usb ]] || { echo 'Target is no longer USB-connected.' >&2; return 1; }
  [[ "$(lsblk -dn -o MAJ:MIN -- "$device")" == "$identity" ]] || { echo 'Device identity changed.' >&2; return 1; }
  local capacity
  capacity="$(lsblk -dn -b -o SIZE -- "$device" | tr -d '[:space:]')"
  [[ "$capacity" =~ ^[0-9]+$ ]] || { echo 'Unable to determine target capacity.' >&2; return 1; }
  (( capacity <= max_device_bytes )) || { echo 'Target exceeds capacity limit.' >&2; return 1; }
  (( capacity >= iso_size )) || { echo 'Target is too small.' >&2; return 1; }
  # Refuse anything in use: mounted descendants, swap, LUKS, LVM, RAID, etc.
  if lsblk -nr -o MOUNTPOINTS -- "$device" | grep -q '[^[:space:]]'; then
    echo 'Target or its descendants are mounted/in use; unmount manually first.' >&2
    return 1
  fi
  if lsblk -nr -o TYPE -- "$device" | grep -Ev '^(disk|part)$' >/dev/null; then
    echo 'Target contains active mapped/stacked block devices; refusing.' >&2
    return 1
  fi
}
validate_target

echo
printf 'Selected target:\n'
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,RM,TYPE,MOUNTPOINTS -- "$device"
printf '\nALL DATA ON %s WILL BE DESTROYED.\n' "$device"
# Ask for elevation before the final confirmation so no password prompt occurs afterwards.
sudo -v
validate_target
printf 'Final confirmation: type exactly "WRITE %s" to proceed: ' "$device"
IFS= read -r confirmation
[[ "$confirmation" == "WRITE $device" ]] || { echo 'Cancelled.' >&2; exit 1; }
validate_target
printf 'Writing %s to %s ...\n' "$iso" "$device"
sudo dd if="$iso" of="$device" bs=4M status=progress conv=fsync
sync
echo 'Completed. Remove the USB device safely.'
