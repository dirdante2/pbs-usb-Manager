# ZFS USB Pool Manager for Proxmox Backup Server (PBS)
This script provides a reliable and interactive way to manage a portable ZFS pool on a USB drive with Proxmox Backup Server (PBS). It ensures that the pool and its associated datastore can be imported/exported cleanly, and the PBS configuration is updated dynamically – with minimal user interaction and maximum safety.

## 📌 Purpose
Managing portable ZFS pools across multiple PBS systems can lead to dirty imports, datastore config errors, or service conflicts if not done properly. This script handles:

- Safe pool import/export
- Datastore configuration
- PBS service reloads
- User prompts for force-import when needed

All wrapped in a clean Bash menu for manual use.

## ✅ Features
- ✅ Detect if the ZFS pool is available, imported, or missing
- ✅ Automatically import the pool and configure the PBS datastore
- ✅ Optionally force import if the pool was not cleanly exported
- ✅ Automatically create the mount point directory
- ✅ Automatically remove the datastore entry and export the pool
- ✅ Forcefully kill processes accessing the pool mount path (for clean export)
- ✅ PBS service reload instead of full restart
- ✅ Clean status output before actions
- ✅ Minimal dependencies (`bash`, `zpool`, `awk`, `grep`, `fuser`, `systemctl`)

## 💡 Usage
chmod +x usb-zfs-menu.sh
./usb-zfs-menu.sh


## 🛠️ Configuration
Update the following variables inside the script if needed:
POOLNAME="usb-1tb"
MOUNTPOINT="/mnt/datastore/usb-1tb"
CONFIG="/etc/proxmox-backup/datastore.cfg"

## ⚠️ Important Notes
Always use the export option before physically unplugging the USB drive.
The script uses fuser to kill processes accessing the mountpoint before export.
This script is intended to run on the PBS host as root.

## 📂 License
MIT License – feel free to adapt, improve, and share.
