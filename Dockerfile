FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update
RUN apt-get install -y --no-install-recommends \
    openssh-server \
    curl \
    sudo \
    ca-certificates \
    gnupg2 \
    ffmpeg \
    python3 \
    unzip

RUN curl -L -o /tmp/bento4.zip https://www.bok.net/Bento4/binaries/Bento4-SDK-1-6-0-641.x86_64-unknown-linux.zip
RUN unzip /tmp/bento4.zip -d bento4
RUN mv bento4/Bento4-SDK-1-6-0-641.x86_64-unknown-linux/bin/* /usr/local/bin
RUN rm -r bento4
RUN chmod +x /usr/local/bin/*

# Create ssh directories and default sshd config
RUN mkdir -p /var/run/sshd /root/.ssh

# Copy entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose SSH port
EXPOSE 22

# Use a small sshd config tweak to allow password auth (will be controlled by env)
RUN sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config \
    && sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config || true

# Install yt-dlp and dependencies
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -o /usr/local/bin/yt-dlp
RUN chmod a+rx /usr/local/bin/yt-dlp

# Install deno
# Install latest Deno (official install script). Installs to /root/.deno by default.
RUN curl -fsSL https://deno.land/install.sh | sh \
 && ln -s /root/.deno/bin/deno /usr/local/bin/deno

# Copy yt-dlp config file
COPY config/config /etc/yt-dlp/config

# Setup weekly update
RUN apt-get -y --no-install-recommends install cron
COPY cron/update /etc/cron.d/update
RUN chmod 0644 /etc/cron.d/update
RUN crontab /etc/cron.d/update

# Update motd
COPY motd/welcome /etc/motd

# Include useful scripts
COPY etc/ydl.sh ~/ydl.sh
COPY etc/myip.sh ~/myip.sh

# Ensure cron is running, see:
# https://stackoverflow.com/questions/37458287/how-to-run-a-cron-job-inside-a-docker-container
CMD ["/usr/sbin/sshd","-D"]
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
