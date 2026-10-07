---
name: data
description: "NAS storage taxonomy, hygiene, permissions."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['data', 'nas', 'storage', 'hygiene']
    related_skills: []
---

# data — NAS Storage Taxonomy & Hygiene

Manage `/srv/data` (mirrored to `/Volumes/data` across the fleet) folder taxonomy, permissions, media server isolation, and data hygiene.

## Tasks

| Task | Description |
|------|-------------|
| `data:audit` | Full audit of storage categories, disk usage, privacy permissions, and media server hygiene |
| `data:clean:metadata` | Scan and remove macOS artifacts (`._*`, `.DS_Store`, `@eaDir`) across the tree |
| `data:clean:downloads` | Audit downloads staging directory and remove orphaned `.aria2` control files |
| `data:protect:private` | Enforce `0700` permissions and `.nomedia` / `.plexignore` shields on private folders |
| `data:status` | Quick overview alias for `data:audit` |
| `data:index:refresh` | Trigger refresh of qmd documentation and vault indices |

## Canonical Storage Taxonomy

| Directory | Purpose | Access & Indexing Policy |
|-----------|---------|--------------------------|
| `arr/` & `media/` | Movies, TV series, media files | Indexed by Jellyfin & Plex. Strictly media files only (no installers, archives, or software) |
| `software/` | Standalone installers, software torrents (`software/torrents`) | Shielded with `.nomedia` and `.plexignore` to prevent media server probe crashes |
| `books/` | Technical papers, programming, philosophy, comics | Unindexed by media servers; indexed by document search |
| `isos/` | Linux distributions, appliance ISOs, Apple installers | Shared repository of boot images |
| `german/` | German language study (books, audio, notes) | Learning materials |
| `devices/` | Hardware firmwares, phone recovery roms, OnePlus6 tools | Unindexed |
| `bin-*` / `appimages/` | Lazily served binaries (`bin-x86`, `bin-aarch64`, `bin-script`) & AppImages | Served directly over NAS / HTTP without Nix package builds |
| `downloads/` | Active staging directory for aria2 RPC daemon | Permissions `0775 aria2:users`. Kept clean once sorted |
| `projects/` | Cloned git repos, web projects, code stashes | Active development workspaces |
| `p/zhuomin` | User's father's archives for private review | Permissions `0700 devji:users`. Intact, private |
| `p/ppp` | Private adult stash | Permissions `0700 devji:users`. Shielded with `.nomedia` and `.plexignore` |
| `p/web` | Backward-compatibility symlink to `projects/bountystash-web` | Frontend for bountystash website |
| `security/` | Credentials, certificates, recovery keys, age/sops keys | Permissions `0700 devji:users`. `id_ed25519.age` encrypted with fleet age keys |
| `storage/` | Backward-compatibility symlink pointing to `.` | Ensures legacy `/Volumes/data/storage` paths resolve |
