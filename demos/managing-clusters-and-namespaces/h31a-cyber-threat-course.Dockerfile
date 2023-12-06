FROM kalilinux/kali-rolling
LABEL maintainer="JCAC Course Admins <jcac-course-admins@navy.mil>"

RUN apt -y update
RUN apt-get install -y \
    hydra \
    john \
    metasploit-framework \
    nmap \
    sqlmap \
    wfuzz \
    exploitdb \
    nikto \
    commix \
    hashcat \
    # Wordlists
    wordlists \ 
    cewl \
    tcpdump \
    kali-desktop-xfce \
    dbus \
    dbus-x11 \
    net-tools
ENV VNCEXPOSE 1
ENV VNCPORT 5900
ENV VNCDISPLAY 1920x1080
ENV VNCDEPTH 16
ENV NOVNCPORT 9090
ENV TZ=America/Chicago
COPY ./kali-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN useradd -rm -d /home/kaliuser -g root -G sudo -s /bin/bash -u 1001 kaliuser
RUN apt -y install tigervnc-standalone-server
ENTRYPOINT [ "/entrypoint.sh" ]
