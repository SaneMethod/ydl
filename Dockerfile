FROM debian:stable-slim
LABEL maintainer="ckeefer keefer@sanemethod.com"

ARG DEBIAN_FRONTEND=noninteractive

# Install necessary packages to match linuxserver/openssh-server
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    curl \
    sudo \
    ca-certificates \
    gnupg2 \
    cron \
    ffmpeg \
    python3 \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Set up environment variables to match linuxserver/openssh-server parameters
ENV PUID=1000 \
    PGID=1000 \
    TZ=Etc/UTC \
    USER_NAME=linuxserver.io \
    PUBLIC_KEY="" \
    PUBLIC_KEY_FILE=/config/.ssh/authorized_keys \
    PUBLIC_KEY_DIR=/config/.ssh/keys \
    PUBLIC_KEY_URL="" \
    SUDO_ACCESS=false \
    PASSWORD_ACCESS=false \
    USER_PASSWORD="" \
    USER_PASSWORD_FILE=""

# Create necessary directories
RUN mkdir -p /config /var/run/sshd /run/sshd

# Add entrypoint script to handle PUBLIC_KEY
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Configure SSH
RUN sed -i 's/^#*Port .*/Port 2222/' /etc/ssh/sshd_config \
    && grep -q '^Port 2222' /etc/ssh/sshd_config || echo "Port 2222" >> /etc/ssh/sshd_config \
    && sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && grep -q '^PermitRootLogin no' /etc/ssh/sshd_config || echo "PermitRootLogin no" >> /etc/ssh/sshd_config

# Install bento4
RUN curl -L -o /tmp/bento4.zip https://www.bok.net/Bento4/binaries/Bento4-SDK-1-6-0-641.x86_64-unknown-linux.zip \
    && unzip /tmp/bento4.zip -d /tmp/bento4 \
    && mv /tmp/bento4/Bento4-SDK-1-6-0-641.x86_64-unknown-linux/bin/* /usr/local/bin/ \
    && rm -rf /tmp/bento4 /tmp/bento4.zip \
    && chmod +x /usr/local/bin/*

EXPOSE 2222

# Install yt-dlp and dependencies
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -o /usr/bin/yt-dlp
RUN chmod a+rx /usr/bin/yt-dlp

# Install deno
RUN curl -fsSL https://deno.land/install.sh | DENO_INSTALL=/usr/local sh \
    && chmod a+rx /usr/local/bin/deno

# Install UV
RUN curl -L https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-unknown-linux-gnu.tar.gz -o /usr/bin/uv.tar.gz
RUN tar -xzf /usr/bin/uv.tar.gz -C /usr/bin/
RUN mv /usr/bin/uv-x86_64-unknown-linux-gnu/uv /usr/bin/
RUN chmod a+rx /usr/bin/uv
RUN rm /usr/bin/uv.tar.gz
RUN rm -rf /usr/bin/uv-x86_64-unknown-linux-gnu
RUN echo 'export PATH="$PATH:/config/.local/bin"' | tee -a /etc/profile

# Copy yt-dlp config file
COPY config/config /etc/yt-dlp/config

# Setup weekly update
COPY cron/update /etc/cron.d/update
RUN chmod 0644 /etc/cron.d/update
RUN crontab /etc/cron.d/update

# Update motd
COPY motd/welcome /etc/motd

# Ensure cron is running, see:
# https://stackoverflow.com/questions/37458287/how-to-run-a-cron-job-inside-a-docker-container
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sh", "-c", "cron && /usr/sbin/sshd -D"]
