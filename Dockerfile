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
