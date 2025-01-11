#!/bin/sh
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
. $MODPATH/utils.sh
PERSISTENT_DIR=/data/adb/bindhosts

# grab own info (version)
versionCode=$(grep versionCode $MODPATH/module.prop | sed 's/versionCode=//g' )

echo "[+] bindhosts v$versionCode "
echo "[%] customize.sh "

# Install App Section
# Prompt user to press a key
echo "[?] Press Volume Up to install the bindhosts-tile app, or Volume Down to skip."

chooseport

# Delay for 4 seconds to allow the user to press a key
sleep 4

if [ "$?" == "0" ]; then
    # User pressed Volume Up
    APK_PATH=$MODPATH/common/app-release.apk  # Path to your APK file

    echo "[%] Checking for APK at $APK_PATH..."
    if [ -f "$APK_PATH" ]; then
        echo "[+] APK found, installing as user app..."
        pm install -r "$APK_PATH" >/dev/null 2>&1

        if [ $? -eq 0 ]; then
            echo "[+] App installed successfully!"
            echo "[+] Enable root permission!"
            echo "[+] Enable Capabilities (KernelSU) : dac_override | net_bind_service | net_raw"
        else
            echo "[!] Failed to install the app."
        fi
    else
        echo "[!] APK not found at $APK_PATH. Skipping installation."
    fi
else
    # User pressed Volume Down
    echo "[!] Skipping app installation."
fi

# Continue with other operations below...

# persistence
[ ! -d $PERSISTENT_DIR ] && mkdir -p $PERSISTENT_DIR
# make our hosts file dir
mkdir -p $MODPATH/system/etc

# set permissions to bindhosts.sh
susfs_clone_perm "$MODPATH/bindhosts.sh" /bin/sh

# symlink bindhosts to manager path
# for ez termux usage
manager_paths="/data/adb/ap/bin /data/adb/ksu/bin"
for i in $manager_paths; do
	if [ -d $i ] && [ ! -f $i/bindhosts ]; then
		echo "[+] creating symlink in $i"
		ln -sf /data/adb/modules/bindhosts/bindhosts.sh $i/bindhosts
	fi
done

# check for other systemless hosts modules and disable them
# sorry I had to do this.
modulenames="hosts systemless-hosts-KernelSU-module systemless-hosts Malwack Re-Malwack cubic-adblock StevenBlock systemless_adblocker"
for i in $modulenames; do
	if [ -d /data/adb/modules/$i ] ; then
		echo "[!] confliciting module found!"
		echo "[-] disabling $i"
		touch /data/adb/modules/$i/disable
	fi
done

# warn about highly breaking modules
# just warn and tell user to uninstall it
# we would still proceed to install
# lets make the user wait for say 5 seconds
bad_module="busybox-brutal HideMyRoot"
for i in $bad_module; do
	if [ -d /data/adb/modules/$i ] ; then
		echo "[!] 🚨 possible confliciting module found!"
		echo "[!] ⚠️ $i "
		echo "[!] 📢 uninstall for a flawless operation"
		echo "[!] ‼️ you have been warned"
		sleep 5
	fi
done

# copy our old hosts file
if [ -f /data/adb/modules/bindhosts/system/etc/hosts ] ; then
	echo "[+] migrating hosts file "
	cat /data/adb/modules/bindhosts/system/etc/hosts > $MODPATH/system/etc/hosts
fi

# normal flow for persistence
# move over our files, remove after
files="blacklist.txt custom.txt sources.txt whitelist.txt"
for i in $files ; do
	if [ ! -f /data/adb/bindhosts/$i ] ; then
		cat $MODPATH/$i > $PERSISTENT_DIR/$i
	fi
	rm $MODPATH/$i
done

# if hosts file empty or just comments
# just copy real hosts file over
grep -qv "#" $MODPATH/system/etc/hosts > /dev/null 2>&1 || {
	echo "[+] creating hosts file"
	cat /system/etc/hosts > $MODPATH/system/etc/hosts
	printf "127.0.0.1 localhost\n::1 localhost\n" >> $MODPATH/system/etc/hosts
	}

# set permissions always
susfs_clone_perm "$MODPATH/system/etc/hosts" /system/etc/hosts

# EOF
