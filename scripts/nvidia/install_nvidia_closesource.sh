#!/bin/bash

# dpkg -i 
# overlayroot-disable

if [ "$(id -u)" -ne "0" ];then
	echo "Need root privileges."
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive
nouveau_mod=`lsmod | grep nouveau`
nvidia_mod=`lsmod | grep nvidia`
POSTOS=`cat /proc/mounts | awk '{if ($2 == "/media/root-ro") print $1}'`

systemctl stop lightdm
if [ $1 == "post" ];then
	echo "Sync driver into disk $POSTOS ...... "
	if [ -x /usr/bin/nvidia-installer ];then
		overlayroot-chroot nvidia-installer --uninstall --no-runlevel-check --no-x-check --ui=none || true
	fi

	find /media/root-rw/overlay/ -size 0 | xargs rm -rf
	mount -o remount,rw $POSTOS /media/root-ro
	rsync -avz --progress /media/root-rw/overlay/* /media/root-ro/
	sync
	find /media/root-rw/overlay/usr/lib/ -size 0 | xargs overlayroot-chroot rm

	overlayroot-chroot rm /usr/lib/i386-linux-gnu/libGL.so.1.2.0
	overlayroot-chroot rm /usr/lib/x86_64-linux-gnu/libGL.so.1.2.0
	overlayroot-chroot rm /usr/lib/x86_64-linux-gnu/libEGL.so.1.0.0
	overlayroot-chroot rm /usr/lib/x86_64-linux-gnu/libGLESv2.so.2.0.0
	overlayroot-chroot rm /etc/X11/xorg.conf.d/20-intel.conf
	overlayroot-chroot rm /etc/X11/xorg.conf.d/20-nouveau.conf

	overlayroot-chroot rmmod -f nouveau
	overlayroot-chroot apt-get install xserver-xorg-core --reinstall -y --allow-downgrades
	overlayroot-chroot apt-get install xserver-xorg-input-all --reinstall -y --allow-downgrades
	sync
	sleep 3
	echo "Sync driver into disk ...... done"
else
	systemctl stop lightdm
	if [ -x /usr/bin/nvidia-installer ];then
		nvidia-installer --uninstall --no-runlevel-check --no-x-check --ui=none || true
	fi
	if [ -n "$nouveau_mod" ]; then
		echo "Had already used nouveau,remove it instead by nvidia "
#		rmmod -f nouveau
	fi
	if [ -n "$nvidia_mod" ]; then
		echo "Had already used nvidia,updating new nvidia driver "
		rmmod -f nvidia-drm 
		rmmod -f nvidia-modeset 
		rmmod -f nvidia
	fi
	apt install nvidia-driver -y --allow-downgrades 
	apt-get install xserver-xorg-input-all --reinstall -y --allow-downgrades
	rm /etc/X11/xorg.conf.d/20-intel.conf
	rm /etc/X11/xorg.conf.d/20-nouveau.conf
	echo "Loading kernel modules......"
	rmmod -f nouveau
	modprobe nvidia-drm
	modprobe nvidia-current-drm
	#echo "Now start desktop......"
	#systemctl restart lightdm
fi

#sudo overlayroot-chroot apt-get install nvidia-driver -y --allow-downgrades
