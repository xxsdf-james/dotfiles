#!/usr/bin/env bash
# System layer: installs the files of each component folder into /etc (docs/philosophy.md, layers).
#
# A component is a folder beside this script:
#   files/      mirrors real paths: files/etc/X is installed as /etc/X (root-owned, 0644, 0755 if executable)
#   manifest    shell variables:
#                 ROLES          roles that get it, e.g. "personal" or "personal work"
#                 OS             "any", or IDs matched against ID/ID_LIKE in /etc/os-release, e.g. "fedora"
#                 CHECK          optional: succeeds when the running state is right (e.g. service enabled)
#                 AFTER_APPLY    optional: run after files changed (or CHECK failed)
#                 BEFORE_REMOVE  optional: run before the files are deleted
#                 AFTER_REMOVE   optional: run after the files are deleted
# Only files plus commands: anything that isn't a file doesn't belong in this layer.
#
# Usage:
#   install.sh --role personal                    show what would change (needs no root)
#   pkexec install.sh --role personal --yes       apply every component for this role and OS
#   pkexec install.sh --remove killswitch         take a component out again
# On a restore, take the role from chezmoi:
#   pkexec ~/.local/share/chezmoi/system/install.sh --role "$(chezmoi execute-template '{{ .role }}')" --yes
#
# --root DIR installs under DIR instead of / (for tests); commands and checks are then skipped.
set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"
mode=diff role="" root=/ only=()

usage() { sed -n '/^# Usage:/,/^# --root/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
while (($#)); do
  case $1 in
    --role) role=${2:?}; shift 2 ;;
    --root) root=${2:?}; shift 2 ;;
    --yes) mode=apply; shift ;;
    --remove) mode=remove; shift ;;
    -h|--help) usage ;;
    -*) echo "unknown option: $1" >&2; usage ;;
    *) only+=("$1"); shift ;;
  esac
done
root=${root%/}
if [[ $mode == remove && ${#only[@]} -eq 0 ]]; then
  echo "--remove needs component names, e.g. --remove killswitch" >&2; exit 2
fi
if [[ $mode != remove && -z $role ]]; then
  echo "--role is required (personal or work)" >&2; exit 2
fi
if [[ $mode != diff && -z $root && $EUID -ne 0 ]]; then
  echo "run with pkexec to change /etc" >&2; exit 1
fi

# OS IDs of the target system, e.g. "bluefin fedora"
os_ids=$(. "$root/etc/os-release" && echo "$ID ${ID_LIKE:-}")

run() {  # run a manifest command, unless testing under --root
  [[ -n $1 ]] || return 0
  if [[ -n $root ]]; then echo "    (skipped under --root: $1)"; else echo "    \$ $1"; sh -c "$1"; fi
}

wanted() {  # does this component apply to this role and OS?
  local r o
  for r in $ROLES; do [[ $r == "$role" ]] && break; done
  [[ $r == "$role" ]] || return 1
  [[ $OS == any ]] && return 0
  for o in $OS; do [[ " $os_ids " == *" $o "* ]] && return 0; done
  return 1
}

want_mode() { [[ -x $1 ]] && echo 755 || echo 644; }

# Prints what differs between files/ and the target; returns 1 if anything does.
compare() {
  local dir=$1 src rel dst clean=0
  while IFS= read -r -d '' src; do
    rel=${src#"$dir/files"}; dst=$root$rel
    if [[ ! -e $dst ]]; then
      echo "    new:      $rel"; clean=1
    elif ! cmp -s "$src" "$dst"; then
      echo "    changed:  $rel"; diff -u --label "$rel (now)" --label "$rel (repo)" "$dst" "$src" | sed 's/^/      /' || true; clean=1
    elif [[ $(stat -c %a "$dst") != "$(want_mode "$src")" ]]; then
      echo "    mode:     $rel ($(stat -c %a "$dst") → $(want_mode "$src"))"; clean=1
    fi
  done < <(find "$dir/files" -type f -print0 | sort -z)
  return $clean
}

installed_any() {
  local dir=$1 src
  while IFS= read -r -d '' src; do [[ -e $root${src#"$dir/files"} ]] && return 0; done \
    < <(find "$dir/files" -type f -print0)
  return 1
}

status=0 pending=0
for dir in "$here"/*/; do
  dir=${dir%/}; name=$(basename "$dir")
  [[ -f $dir/manifest ]] || continue
  if ((${#only[@]})) && [[ " ${only[*]} " != *" $name "* ]]; then continue; fi
  ROLES="" OS=any CHECK="" AFTER_APPLY="" BEFORE_REMOVE="" AFTER_REMOVE=""
  . "$dir/manifest"

  if [[ $mode == remove ]]; then
    echo "==> $name: removing"
    if ! installed_any "$dir"; then echo "    not installed"; continue; fi
    run "$BEFORE_REMOVE"
    while IFS= read -r -d '' src; do
      dst=$root${src#"$dir/files"}
      [[ -e $dst ]] && rm -f -- "$dst" && echo "    removed:  ${src#"$dir/files"}"
    done < <(find "$dir/files" -type f -print0 | sort -z)
    run "$AFTER_REMOVE"
    continue
  fi

  if ! wanted; then
    if installed_any "$dir"; then
      echo "==> $name: installed, but not meant for role=$role on '$os_ids'. Take it out with --remove $name"
      status=1
    else
      echo "==> $name: not for role=$role on '$os_ids', skipped"
    fi
    continue
  fi

  echo "==> $name"
  files_ok=1; state_ok=1
  compare "$dir" || files_ok=0
  if [[ -z $root && -n $CHECK ]] && ! sh -c "$CHECK" 2>/dev/null; then
    echo "    state:    check failed: $CHECK"; state_ok=0
  fi
  if ((files_ok && state_ok)); then echo "    up to date"; continue; fi
  [[ $mode == diff ]] && status=1 pending=1

  if [[ $mode == apply ]]; then
    while IFS= read -r -d '' src; do
      dst=$root${src#"$dir/files"}
      if [[ -n $root ]]; then
        install -D -m "$(want_mode "$src")" "$src" "$dst"
      else
        install -D -o root -g root -m "$(want_mode "$src")" "$src" "$dst"
        command -v restorecon >/dev/null && restorecon -F "$dst"
      fi
    done < <(find "$dir/files" -type f -print0 | sort -z)
    echo "    files installed"
    run "$AFTER_APPLY"
  fi
done

if ((pending)); then
  echo "Differences found. Apply with: pkexec $0 --role $role --yes"
fi
exit $status
