# Sledgehammer USB Creation Guide

## Overview
Sledgehammer is a purpose-built NixOS live USB for headless fleet provisioning. It includes:
- SOPS for secret decryption
- SSH (key-only auth, no passwords)
- Git, Age, and NixOS installation tools
- Disko for declarative disk partitioning

This guide walks through creating a bootable Sledgehammer USB from your NixOS flake config.

## Prerequisites
- NixOS system with flake support enabled (x86_64-linux only, as Sledgehammer targets x86_64)
- USB drive ≥8GB (all data will be permanently erased)
- Local clone of this repository
- SSH key pair for authentication (your public key needs to be authorized for SSH access to the live USB)

## ⚠️ Critical Safety Warnings
1. **ALL DATA ON THE USB DRIVE WILL BE PERMANENTLY ERASED.** Backup any important files first.
2. Double-check the USB device path (e.g., `/dev/sdX`) before running any destructive commands. Using the wrong device can destroy your system's data.
3. Disable Secure Boot on target machines before booting from the USB.
4. The Sledgehammer config hardcodes `/dev/sdb` as the default USB device. You **must** update this to your actual USB path before partitioning.

---

## Step 1: Identify Your USB Device
Insert your USB drive, then list block devices to find its path:
```bash
lsblk
```

Look for a device with no mounted partitions (e.g., `/dev/sdb`, `/dev/sdc`). **NEVER use `/dev/sda` (usually your system disk).** Note the exact path.

Example output:
```
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda      8:0    0 238.5G  0 disk 
├─sda1   8:1    0   512M  0 part /boot
└─sda2   8:2    0 238G  0 part /
sdc      8:32   1  14.9G  0 disk   # This is your USB (note path: /dev/sdc)
```

---

## Step 2: Update USB Device Path in Config
The Sledgehammer config hardcodes the USB device as `/dev/sdb`. Update this to your actual USB path:

1. Open the Sledgehammer configuration:
```bash
nano hosts/sledgehammer/configuration.nix
```

2. Find line 12 (disko import):
```nix
(import ./disko.nix {device = "/dev/sdb";})
```

3. Replace `/dev/sdb` with your USB device path (e.g., `/dev/sdc`)

4. Save and exit.

*Optional: Revert this change after creating the USB to avoid accidental misformatting later.*

---

## Step 3: Partition USB with Disko
Disko will create a GPT partition table with:
- 1MB BIOS boot partition (type EF02)
- 512MB EFI System Partition (ESP, vfat)
- Remaining space as f2fs root partition (optimized for flash media longevity)

Run the partitioning command (uses your updated config from Step 2):
```bash
sudo nix run github:nix-community/disko -- \
  --mode disko \
  --flake .#sledgehammer
```

⚠️ **Confirm the USB device path one last time** when prompted. This will erase all data on the USB.

---

## Step 4: Mount Partitions for Installation
After Disko finishes, mount the new partitions to `/mnt`:
```bash
# Replace /dev/sdX with your USB device (e.g., /dev/sdc)
# 3rd partition = f2fs root, 2nd partition = ESP
sudo mount /dev/sdX3 /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/sdX2 /mnt/boot
```

Verify partition numbers with:
```bash
lsblk /dev/sdX
```

---

## Step 5: Install NixOS to USB
Run the NixOS installer using your flake config:
```bash
sudo nixos-install \
  --flake .#sledgehammer \
  --root /mnt
```

During installation:
1. The system will build the Sledgehammer configuration
2. You'll be prompted to set a root password (can be left blank if using SSH key-only auth)
3. The SSH host key will be generated automatically (used for SOPS decryption)

*Optional: Use `--no-root-password` to skip password setup entirely (SSH is key-only anyway).*

---

## Step 6: Unmount and Finalize
After installation completes:
```bash
sudo umount /mnt/boot
sudo umount /mnt
sudo sync  # Ensure all data is written to USB
```

Remove the USB drive from your system.

---

## Step 7: Boot from Sledgehammer USB
1. Insert USB into target machine
2. Power on and enter boot menu (usually F12, F2, or Del during startup)
3. Disable Secure Boot in BIOS/UEFI settings
4. Select USB drive as boot device
5. Wait for NixOS to boot (headless, no display output by design)

---

## Step 8: Access the Live USB
SSH into the running USB (headless operation):
```bash
ssh root@<usb-ip-address>
```

*Note: Your SSH public key must be authorized via SOPS secrets in `modules/secrets.yaml`. The USB uses the host SSH key for SOPS decryption.*

---

## Included Tools
Sledgehammer comes pre-installed with:
- **Secrets**: `sops`, `age`, `ssh-to-age`, `yq`
- **Version Control**: `git`, `openssh`
- **Networking**: `curl`, `wget`, `iproute2`, `inetutils`
- **Nix Tooling**: `nix-output-monitor`, `nvd`, `nixpkgs-fmt`
- **Diagnostics**: `htop`, `jq`, `pciutils`, `usbutils`, `lm_sensors`

---

## Troubleshooting
- **USB won't boot**: Verify Secure Boot is disabled, try both UEFI and Legacy boot modes
- **Can't SSH to USB**: Check USB IP via router/admin panel, verify SSH public key is in SOPS secrets
- **Partition errors**: Re-run Disko after confirming correct USB device path
- **Build failures**: Ensure flake inputs are up-to-date with `nix flake update`

---

## Cleanup (Optional)
If you modified `hosts/sledgehammer/configuration.nix` in Step 2, revert the device path:
```bash
sed -i 's|device = "/dev/sdX"|device = "/dev/sdb"|' hosts/sledgehammer/configuration.nix
```
*Replace `/dev/sdX` with the path you used during creation.*

---

## Technical Notes
- Uses GRUB with `efiInstallAsRemovable = true` for cross-machine booting
- f2fs filesystem for better flash media longevity (reduces write wear)
- No graphical environment, tty-only for minimal resource usage
- SOPS configured to use host SSH key for secret decryption
