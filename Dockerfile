FROM kalilinux/kali-rolling:latest
RUN apt-get update && \
    apt-get -y upgrade
# apt-get install -yq kali-linux-headless

RUN DEBIAN_FRONTEND=noninteractive apt-get -yq install \
    sudo \
    openssh-server \
    python2 \
    python3 \
    dialog \
    firefox-esr \
    inetutils-ping \
    htop \
    vim \
    neovim \
    tmux \
    zsh \
    curl \
    git \
    net-tools \
    tigervnc-standalone-server \
    tigervnc-xorg-extension \
    tigervnc-viewer \
    novnc \
    dbus-x11 \
    xterm \
    x11-xserver-utils

RUN DEBIAN_FRONTEND=noninteractive apt-get -yq install \
    xfce4-goodies \
    kali-desktop-xfce && \
    apt-get -y full-upgrade

# Install VS Code
RUN apt-get update && \
    apt-get install -yq wget gpg && \
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && \
    install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/ && \
    sh -c 'echo "deb [arch=arm64,armhf,amd64 signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list' && \
    apt-get update && \
    apt-get install -yq code

# Install Go 1.25.1
RUN wget -q https://golang.org/dl/go1.25.1.linux-amd64.tar.gz -O /tmp/go1.25.1.linux-amd64.tar.gz && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf /tmp/go1.25.1.linux-amd64.tar.gz && \
    rm /tmp/go1.25.1.linux-amd64.tar.gz
RUN apt-get -y autoremove && \
    apt-get clean all && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -m -c "kali" -s /bin/bash -d /home/kali kali && \
    sed -i "s/#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/g" /etc/ssh/sshd_config && \
    sed -i "s/off/remote/g" /usr/share/novnc/app/ui.js && \
    echo "kali ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir /run/dbus && \
    touch /usr/share/novnc/index.htm && \
    mkdir -p /home/kali/.vnc && \
    chown -R kali:kali /home/kali/.vnc

COPY startup.sh /startup.sh
RUN chmod +x /startup.sh && chown kali:kali /startup.sh
COPY bootstrap-dotfiles.sh /usr/local/bin/bootstrap-dotfiles.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/bootstrap-dotfiles.sh /usr/local/bin/entrypoint.sh \
    && chown kali:kali /usr/local/bin/bootstrap-dotfiles.sh /usr/local/bin/entrypoint.sh

USER kali
WORKDIR /home/kali
ENV PASSWORD=kalilinux
ENV SHELL=/bin/bash
ENV PATH=/usr/local/go/bin:$PATH
ENV GOPATH=/home/kali/go
ENV GOROOT=/usr/local/go

# Create Go workspace directory
RUN mkdir -p /home/kali/go/{bin,src,pkg}
# for vnc web client
EXPOSE 8080
# for vscode server
EXPOSE 8088
ENTRYPOINT ["/bin/zsh", "/usr/local/bin/entrypoint.sh"]
