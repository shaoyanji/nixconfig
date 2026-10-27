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

`data:status` is an alias of `data:audit`, and `data:clean:downloads` removes
orphaned `.aria2` control files — a half-download leaves one behind and aria2
will not resume around it. `data:sort` moves finished staging items into the
tree that owns their kind, so an AppImage or an OS image is never left behind
as an unknown extension; it prints a plan unless given `--apply`, and refuses
anything aria2 still holds, including a completed torrent that is seeding. A
staged directory whose payload is video moves as one set under a single
`arr/<Title (Year)>/` — a release folder keeps its own subtitles and a lecture
series keeps its parts. `--classify`
(`services.downloadsSort.classify` on frieren) is the second layer:
when extension and kind rules cannot place an item, `jev-decide` picks one label
from a fixed destination list at >= 0.8 probability — never a media title. The
rest are named for what they do.

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

Truth: `taskfiles/data.yml` — the executable contract; this page is the procedure.
