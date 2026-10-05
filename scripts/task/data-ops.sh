#!/usr/bin/env bash
# scripts/task/data-ops.sh — NAS storage taxonomy hygiene, audit, and permission control
set -euo pipefail

# 1. Resolve Data Root
DATA_ROOT=""
if [ -d "/srv/data" ]; then
  DATA_ROOT="/srv/data"
elif [ -d "/Volumes/data" ]; then
  DATA_ROOT="/Volumes/data"
else
  echo "Error: Neither /srv/data nor /Volumes/data found." >&2
  exit 1
fi

ACTION="${1:-audit}"

audit_storage() {
  echo "=== NAS Storage Taxonomy Audit ($DATA_ROOT) ==="
  echo ""
  
  echo "--- Category Usage Summary ---"
  for cat in media arr software books isos german devices projects appimages bin-x86 bin-aarch64 bin-script downloads p security; do
    if [ -e "$DATA_ROOT/$cat" ]; then
      du -sh "$DATA_ROOT/$cat" 2>/dev/null || true
    fi
  done
  echo ""

  echo "--- Permission & Privacy Sanity ---"
  # Check security
  if [ -d "$DATA_ROOT/security" ]; then
    sec_perm=$(stat -c "%a %U:%G" "$DATA_ROOT/security" 2>/dev/null || stat -f "%Op %Su:%Sg" "$DATA_ROOT/security" 2>/dev/null)
    echo "security/ permissions: $sec_perm"
    if [[ "$sec_perm" != *"700"* ]]; then
      echo "  [WARNING] security/ is not 0700! Run 'task data:protect:private' to fix."
    fi
  fi

  # Check p/zhuomin
  if [ -d "$DATA_ROOT/p/zhuomin" ]; then
    zm_perm=$(stat -c "%a %U:%G" "$DATA_ROOT/p/zhuomin" 2>/dev/null || stat -f "%Op %Su:%Sg" "$DATA_ROOT/p/zhuomin" 2>/dev/null)
    echo "p/zhuomin permissions: $zm_perm"
    if [[ "$zm_perm" != *"700"* ]]; then
      echo "  [WARNING] p/zhuomin is not 0700! Run 'task data:protect:private' to fix."
    fi
  fi

  # Check p/ppp
  if [ -d "$DATA_ROOT/p/ppp" ]; then
    ppp_perm=$(stat -c "%a %U:%G" "$DATA_ROOT/p/ppp" 2>/dev/null || stat -f "%Op %Su:%Sg" "$DATA_ROOT/p/ppp" 2>/dev/null)
    echo "p/ppp permissions: $ppp_perm"
    if [[ "$ppp_perm" != *"700"* ]]; then
      echo "  [WARNING] p/ppp is not 0700! Run 'task data:protect:private' to fix."
    fi
    if [ ! -f "$DATA_ROOT/p/ppp/.nomedia" ] || [ ! -f "$DATA_ROOT/p/ppp/.plexignore" ]; then
      echo "  [WARNING] p/ppp missing .nomedia or .plexignore! Run 'task data:protect:private' to fix."
    fi
  fi

  # Check downloads
  if [ -d "$DATA_ROOT/downloads" ]; then
    dl_perm=$(stat -c "%a %U:%G" "$DATA_ROOT/downloads" 2>/dev/null || stat -f "%Op %Su:%Sg" "$DATA_ROOT/downloads" 2>/dev/null)
    echo "downloads/ permissions: $dl_perm"
    dl_count=$(find "$DATA_ROOT/downloads" -maxdepth 2 -not -path "$DATA_ROOT/downloads" 2>/dev/null | wc -l)
    echo "downloads/ staging items count: $dl_count"
  fi

  # Check arr media hygiene
  echo ""
  echo "--- Media Server Hygiene (arr/) ---"
  if [ -d "$DATA_ROOT/arr" ]; then
    non_media=$(find "$DATA_ROOT/arr" -type f \( -iname "*.iso" -o -iname "*.exe" -o -iname "*.msi" -o -iname "*.dmg" -o -iname "*.zip" -o -iname "*.rar" -o -iname "*.tar.gz" -o -iname "*.epub" -o -iname "*.pdf" -o -iname "*.bin" \) 2>/dev/null | head -n 10 || true)
    if [ -n "$non_media" ]; then
      echo "  [WARNING] Found non-media files in arr/ that may cause Jellyfin/Plex probe failures:"
      echo "$non_media"
    else
      echo "  [OK] arr/ contains only media files (no stray installers, packages, or books)."
    fi
  fi

  # Check software torrents .nomedia
  if [ -d "$DATA_ROOT/software/torrents" ]; then
    if [ -f "$DATA_ROOT/software/torrents/.nomedia" ] && [ -f "$DATA_ROOT/software/torrents/.plexignore" ]; then
      echo "  [OK] software/torrents is shielded with .nomedia and .plexignore."
    else
      echo "  [WARNING] software/torrents is missing .nomedia or .plexignore."
    fi
  fi

  # Check macOS metadata
  echo ""
  echo "--- Metadata Hygiene ---"
  ds_count=$( (find "$DATA_ROOT" \( -name "._*" -o -name ".DS_Store" \) 2>/dev/null || true) | wc -l | tr -d ' ')
  if [ "$ds_count" -gt 0 ]; then
    echo "  [WARNING] Found $ds_count stray macOS metadata files (._* or .DS_Store). Run 'task data:clean:metadata' to clean."
  else
    echo "  [OK] No macOS metadata pollution found."
  fi
  echo ""
}

clean_metadata() {
  echo "Cleaning macOS metadata (._* and .DS_Store) in $DATA_ROOT..."
  find "$DATA_ROOT" -name "._*" -type f -delete 2>/dev/null || true
  find "$DATA_ROOT" -name ".DS_Store" -type f -delete 2>/dev/null || true
  find "$DATA_ROOT" -name "@eaDir" -type d -exec rm -rf {} + 2>/dev/null || true
  echo "Metadata cleanup complete."
}

clean_downloads() {
  echo "Checking downloads staging area in $DATA_ROOT/downloads..."
  if [ -d "$DATA_ROOT/downloads" ]; then
    # Remove empty subdirectories if any
    find "$DATA_ROOT/downloads" -mindepth 1 -type d -empty -delete 2>/dev/null || true
    # Remove orphaned .aria2 control files whose download no longer exists
    for f in "$DATA_ROOT/downloads"/*.aria2; do
      if [ -f "$f" ]; then
        target="${f%.aria2}"
        if [ ! -e "$target" ]; then
          rm -f "$f"
          echo "Removed orphaned control file: $f"
        fi
      fi
    done
    du -sh "$DATA_ROOT/downloads"
  fi
}

protect_private() {
  echo "Enforcing strict access permissions and unindexing on private data..."
  if [ -d "$DATA_ROOT/security" ]; then
    chmod 700 "$DATA_ROOT/security"
    chmod 600 "$DATA_ROOT/security"/* 2>/dev/null || true
    chmod 644 "$DATA_ROOT/security"/*.pub "$DATA_ROOT/security"/gist.nu "$DATA_ROOT/security"/README.md 2>/dev/null || true
    for subdir in secrets nasbackupsec "nixbuild keys" simplexdata "USB Copy_2024-11-24_131715"; do
      [ -d "$DATA_ROOT/security/$subdir" ] && chmod 700 "$DATA_ROOT/security/$subdir"
    done
    echo "security/ secured to 0700."
  fi

  if [ -d "$DATA_ROOT/p/zhuomin" ]; then
    chmod 700 "$DATA_ROOT/p/zhuomin"
    touch "$DATA_ROOT/p/zhuomin/.nomedia" "$DATA_ROOT/p/zhuomin/.plexignore"
    echo "p/zhuomin secured to 0700."
  fi

  if [ -d "$DATA_ROOT/p/ppp" ]; then
    chmod 700 "$DATA_ROOT/p/ppp"
    touch "$DATA_ROOT/p/ppp/.nomedia" "$DATA_ROOT/p/ppp/.plexignore"
    echo "p/ppp secured to 0700 and shielded with .nomedia / .plexignore."
  fi

  if [ -d "$DATA_ROOT/software/torrents" ]; then
    touch "$DATA_ROOT/software/torrents/.nomedia" "$DATA_ROOT/software/torrents/.plexignore"
    echo "software/torrents shielded with .nomedia / .plexignore."
  fi

  if [ -d "$DATA_ROOT/downloads" ]; then
    chmod 775 "$DATA_ROOT/downloads"
    echo "downloads/ set to 0775."
  fi
  echo "Privacy protection complete."
}

case "$ACTION" in
  audit)
    audit_storage
    ;;
  clean-metadata)
    clean_metadata
    ;;
  clean-downloads)
    clean_downloads
    ;;
  protect-private)
    protect_private
    ;;
  *)
    echo "Unknown action: $ACTION. Supported: audit, clean-metadata, clean-downloads, protect-private" >&2
    exit 1
    ;;
esac
