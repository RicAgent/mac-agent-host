#!/usr/bin/env bash
# drive-access.sh — decide, per external volume, what the 'agents' user may do with it.
#   sudo bash install/drive-access.sh "/Volumes/Name" shared|readonly|private [user]
#   sudo bash install/drive-access.sh --list
# shared   : macOS default for external drives ("ignore ownership"): every user has full read/write.
# readonly : ownership enforced + ACL denying every write for the user (new files inherit the rule).
# private  : ownership enforced + ACL denying even listing the volume root: nothing below is reachable.
# exFAT / FAT / NTFS volumes have no permissions at all: they are always 'shared' while mounted.
set -euo pipefail
U=agents
if [[ ${1:-} == --list ]]; then
  printf '%-28s %-22s %-10s %s\n' VOLUME FILESYSTEM OWNERSHIP ACL
  for v in /Volumes/*; do
    [[ -d $v && $v != /Volumes/Macintosh* ]] || continue
    info=$(diskutil info "$v" 2>/dev/null || true)
    fs=$(awk -F': *' '/File System Personality/{print $2}' <<<"$info")
    own=$(awk -F': *' '/Owners/{print $2}' <<<"$info")
    acl=$(ls -led "$v" 2>/dev/null | awk 'NR>1{printf "%s; ", $0}')
    printf '%-28s %-22s %-10s %s\n' "$(basename "$v")" "${fs:-?}" "${own:-?}" "${acl:-none}"
  done
  exit 0
fi
VOL=${1:?volume path}; MODE=${2:?shared|readonly|private}; U=${3:-$U}
[[ -d $VOL ]] || { echo "no such volume: $VOL"; exit 1; }
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }
id "$U" >/dev/null
FS=$(diskutil info "$VOL" | awk -F': *' '/File System Personality/{print $2}')
case $FS in
  *APFS*|*HFS*|*"Mac OS Extended"*) ;;
  *) echo "WARN: $VOL is $FS: no permissions on this filesystem, it stays fully shared while mounted. Eject it to make it private."; exit 2;;
esac
chmod -N "$VOL" 2>/dev/null || true        # drop any ACL we set earlier (volume root only)
case $MODE in
  shared)
    diskutil disableOwnership "$VOL" >/dev/null
    echo "$VOL: shared (ignore ownership ON, no ACL)";;
  readonly)
    diskutil enableOwnership "$VOL" >/dev/null
    chmod +a "$U deny write,append,delete,delete_child,add_file,add_subdirectory,writeattr,writeextattr,chown,writesecurity,file_inherit,directory_inherit" "$VOL"
    echo "$VOL: read-only for $U (ownership ON + inherited deny-write ACL). Existing files rely on their own permissions: spot-check with"
    echo "   sudo -u $U touch '$VOL/some-existing-folder/x'   (must fail)";;
  private)
    diskutil enableOwnership "$VOL" >/dev/null
    chmod +a "$U deny list,search,read,readattr,readextattr,readsecurity,write,append,delete,delete_child,add_file,add_subdirectory,writeattr,writeextattr,chown,writesecurity" "$VOL"
    echo "$VOL: private (ownership ON + deny-all ACL on the volume root for $U). Check: sudo -u $U ls '$VOL'  (must fail)";;
  *) echo "mode must be shared|readonly|private"; exit 1;;
esac
ls -led "$VOL"
