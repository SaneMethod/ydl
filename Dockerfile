FROM lscr.io/linuxserver/openssh-server:latest
MAINTAINER ckeefer keefer@sanemethod.com

# Install yt-dlp and dependencies
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
RUN chmod a+rx /usr/local/bin/yt-dlp
RUN apk add ffmpeg
RUN apk add python3

# Setup weekly update
COPY cron/update /etc/cron.d/update
RUN chmod 0644 /etc/cron.d/update
RUN crontab /etc/cron.d/update

# Update motd
COPY motd/welcome /etc/motd

# Ensure cron is running, see:
# https://stackoverflow.com/questions/37458287/how-to-run-a-cron-job-inside-a-docker-container
CMD ["/usr/sbin/crond", "-f", "-d", "0"]

# Ensure yt-dlp is updated on container start
ENTRYPOINT yt-dlp -U
