#!/usr/bin/env bash
# Credits: https://github.com/Jornack/kali-docker-vnc-novnc/blob/master/entrypoint.sh
VNCPWD="${VNCPWD?Please define VNCPWD in the env.}"
mkdir -p /root/.vnc/
echo $VNCPWD | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd

# Set password for VNC as user kaliuser
su kaliuser -c "mkdir -p /home/kaliuser/.vnc/"
su kaliuser -c "echo $VNCPWD | vncpasswd -f > /home/kaliuser/.vnc/passwd"
su kaliuser -c "chmod 600 /home/kaliuser/.vnc/passwd"

# Start VNC server as user kaliuser
su kaliuser -c "vncserver :0 -rfbport $VNCPORT -geometry $VNCDISPLAY -depth $VNCDEPTH -localhost no \
  > /dev/null 2>&1 &"

# Start noVNC server as user kaliuser

su kaliuser -c "/usr/share/novnc/utils/launch.sh --listen $NOVNCPORT --vnc localhost:$VNCPORT \
  > /dev/null 2>&1 &"

echo "#!/bin/sh

autocutsel -fork
xrdb "$HOME/.Xresources"
xsetroot -solid grey
#x-terminal-emulator -geometry 80x24+10+10 -ls -title "$VNCDESKTOP Desktop" &
#x-window-manager &
# Fix to make GNOME work
export XKL_XMODMAP_DISABLE=1
/etc/X11/Xsession" > /home/kaliuser/.vnc/xstartup

chmod 777 /home/kaliuser/.vnc/xstartup

echo "Launch your web browser and open http://localhost:9020/vnc.html"

# Start shell
/bin/bash && su - kaliuser
