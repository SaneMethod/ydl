#!/bin/sh
set -eu

ENV_FILE=/run/secrets/youtube-login.env
YOUTUBE_LOGIN_PYTHON=/opt/youtube-login-venv/bin/python

if [ ! -r "$ENV_FILE" ]; then
  echo "YouTube login environment has not been initialized" >&2
  exit 1
fi

if [ ! -x "$YOUTUBE_LOGIN_PYTHON" ]; then
  echo "YouTube login Python environment is unavailable" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

exec "$YOUTUBE_LOGIN_PYTHON" /usr/local/bin/youtube-login.py
