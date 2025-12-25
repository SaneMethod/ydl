FROM lscr.io/linuxserver/openssh-server:latest
MAINTAINER ckeefer keefer@sanemethod.com

# Install yt-dlp and dependencies
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_musllinux -o /usr/local/bin/yt-dlp
RUN chmod a+rx /usr/local/bin/yt-dlp
RUN apk update
RUN apk add gcompat libstdc++
RUN apk add ffmpeg
RUN apk add python3
RUN apk add bento4
RUN apk add bento4-dev
RUN apk add git

# Install bun
COPY --from=oven/bun:alpine /usr/local/bin/bun /usr/local/bin/bun

# Install UV and Audible CLI
RUN curl -L https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-unknown-linux-musl.tar.gz -o /usr/local/bin/uv.tar.gz
RUN tar -xzf /usr/local/bin/uv.tar.gz -C /usr/local/bin/
RUN mv /usr/local/bin/uv-x86_64-unknown-linux-musl/* /usr/local/bin/
RUN chmod a+rx /usr/local/bin/uv
RUN rm /usr/local/bin/uv.tar.gz
RUN rm -rf /usr/local/bin/uv-x86_64-unknown-linux-musl
RUN uv tool install audible-cli
RUN echo 'export PATH="$PATH:/config/.local/bin"' | tee -a /etc/profile

# Copy yt-dlp config file
COPY config/config /etc/yt-dlp/config

# Setup weekly update
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
CMD ["/usr/sbin/crond", "-f", "-d", "0"]
