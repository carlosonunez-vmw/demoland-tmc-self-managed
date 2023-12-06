FROM ubuntu:jammy
LABEL maintainer="JCAC Course Admins <jcac-course-admins@navy.mil>"

RUN apt -y update

# Install some basics...
RUN apt -y install curl bash libicu-dev

# ...and install PowerShell
# Install pre-requisite packages.
RUN mkdir -p /opt/microsoft/powershell/7
RUN curl -Lo /tmp/powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/powershell-7.4.0-linux-x64.tar.gz
RUN tar -xzf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 && chmod +x /opt/microsoft/powershell/7/pwsh
RUN ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
