#!/bin/bash

POOLNAME="usb-1tb" ## Change this to your actual pool name
MOUNTPOINT="/mnt/datastore/$POOLNAME"
CONFIG="/etc/proxmox-backup/datastore.cfg"

# Function: Check pool/datastore status
check_status() {
    echo ""
    echo "🔍 Checking..."

    if zpool list "$POOLNAME" &>/dev/null; then
        echo "✅ Pool is imported"
        POOL_IMPORTED=true
        POOL_EXISTS=true
    elif zpool import 2>/dev/null | grep -q "$POOLNAME"; then
        echo "✅ Pool exists (not yet imported)"
        POOL_IMPORTED=false
        POOL_EXISTS=true
    else
        echo "❌ Pool does not exist (not connected or wrong name)"
        POOL_IMPORTED=false
        POOL_EXISTS=false
    fi

    if grep -q "datastore: $POOLNAME" "$CONFIG"; then
        echo "✅ PBS datastore exists"
        DATASTORE_EXISTS=true
    else
        echo "❌ PBS datastore does not exist"
        DATASTORE_EXISTS=false
    fi
}

# Function: Ensure mountpoint exists
ensure_mountpoint() {
    if [ ! -d "$MOUNTPOINT" ]; then
        mkdir -p "$MOUNTPOINT"
        echo "📁 Created mountpoint $MOUNTPOINT."
    fi
}

# Function: Add PBS datastore config
add_datastore_config() {
    if ! grep -q "datastore: $POOLNAME" "$CONFIG"; then
        echo -e "\ndatastore: $POOLNAME\n\tpath $MOUNTPOINT" >> "$CONFIG"
        echo "📝 Added datastore '$POOLNAME' to PBS config."
        return 0
    else
        return 1
    fi
}

# Function: Remove PBS datastore config block
remove_datastore_config() {
    if grep -q "datastore: $POOLNAME" "$CONFIG"; then
        awk -v ds="datastore: $POOLNAME" '
        BEGIN { skip = 0 }
        /^datastore:/ {
            if ($0 == ds) {
                skip = 1; next
            } else {
                skip = 0
            }
        }
        skip == 1 { next }
        { print }
        ' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
        echo "🗑️ Removed datastore '$POOLNAME' from PBS config."
        return 0
    else
        return 1
    fi
}

# Start with status
check_status

# Menu
echo ""
echo "ZFS USB Management Menu for '$POOLNAME'"
echo "1. Import pool and add PBS datastore"
echo "2. Export pool and remove PBS datastore"
echo "3. Show pool status"
echo "q. Quit"
read -rp "Select option: " choice

case "$choice" in
    1)
        if [ "$POOL_IMPORTED" = true ]; then
            echo "ℹ️ Pool '$POOLNAME' is already imported."
        elif [ "$POOL_EXISTS" = true ]; then
            echo "🔄 Attempting to import pool '$POOLNAME'..."
            if ! zpool import "$POOLNAME"; then
                echo "⚠️  Standard import failed. Possibly dirty pool."
                read -rp "❓ Force import with 'zpool import -f'? [y/N] " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    if zpool import -f "$POOLNAME"; then
                        echo "✅ Pool force-imported successfully."
                    else
                        echo "❌ Force import failed."
                        exit 1
                    fi
                else
                    echo "⛔ Import cancelled by user."
                    exit 1
                fi
            else
                echo "✅ Pool imported successfully."
            fi
        else
            echo "❌ Pool not available. Is the USB drive plugged in?"
            exit 1
        fi

        ensure_mountpoint
        if add_datastore_config; then
            echo "🔄 Reloading PBS service..."
            systemctl reload proxmox-backup
        else
            echo "ℹ️ Datastore already configured – no reload needed."
        fi
        ;;
    2)
        # Prevent killing own shell if inside mountpoint
        if [[ "$PWD" == "$MOUNTPOINT"* ]]; then
            echo "⚠️ You are currently inside the mountpoint ($MOUNTPOINT)."
            echo "Please 'cd' out of it before exporting."
            exit 1
        fi

        echo "🧹 Removing datastore config..."
        if remove_datastore_config; then
            echo "🔄 Reloading PBS service..."
            systemctl reload proxmox-backup
            sleep 2
        else
            echo "ℹ️ No config entry to remove – PBS remains unchanged."
        fi

        echo "📤 Unmounting $MOUNTPOINT (if mounted)..."
        umount "$MOUNTPOINT" 2>/dev/null

        echo "📤 Exporting ZFS pool '$POOLNAME'..."
        if zpool export "$POOLNAME"; then
            echo "✅ Export successful. You may now safely unplug the drive."
        else
            echo "❌ Export failed. The pool may still be in use."
        fi
        ;;
    3)
        echo ""
        zpool status "$POOLNAME" || echo "❌ Pool not imported."
        ;;
    q|Q)
        echo "Bye."
        ;;
    *)
        echo "❌ Invalid option."
        ;;
esac
