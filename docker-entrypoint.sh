#!/bin/sh
set -eu

# Defaults
: "${USER_NAME:=developer}"
: "${PUBLIC_KEY:=}"
: "${USER_PASSWORD:=}"
: "${SUDO_ACCESS:=no}"
: "${YOU_USER:=}"
: "${YOU_PASS:=}"
: "${YOU_SECRET:=}"
: "${YOUTUBE_COOKIES:=/config/youtube-cookies.txt}"
: "${YOUTUBE_BROWSER_PROFILE:=/config/clark-browser-profile}"

shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

read_secret() {
    variable_name="$1"
    secret_file="$2"

    if [ -f "$secret_file" ]; then
        secret_value=$(cat "$secret_file")
        export "$variable_name=$secret_value"
    fi
}

read_secret PUBLIC_KEY /run/secrets/public_key
read_secret USER_PASSWORD /run/secrets/user_password
read_secret YOU_USER /run/secrets/you_user
read_secret YOU_PASS /run/secrets/you_pass
read_secret YOU_SECRET /run/secrets/you_secret

# Make runtime credentials available to cron without placing them in crontab.
umask 077
{
  printf 'YOU_USER=%s\n' "$(shell_quote "$YOU_USER")"
  printf 'YOU_PASS=%s\n' "$(shell_quote "$YOU_PASS")"
  printf 'YOU_SECRET=%s\n' "$(shell_quote "$YOU_SECRET")"
  printf 'YOUTUBE_COOKIES=%s\n' "$(shell_quote "$YOUTUBE_COOKIES")"
  printf 'YOUTUBE_BROWSER_PROFILE=%s\n' \
    "$(shell_quote "$YOUTUBE_BROWSER_PROFILE")"
  printf 'HOME=%s\n' "$(shell_quote "/root")"
  printf 'PATH=%s\n' \
    "$(shell_quote "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin")"
} > /run/secrets/youtube-login.env

mkdir -p \
  "$(dirname "$YOUTUBE_COOKIES")" \
  "$YOUTUBE_BROWSER_PROFILE"

# Create user if not exists
if ! id "$USER_NAME" >/dev/null 2>&1; then
  # Create user with home and bash
  useradd -m -s /bin/bash "$USER_NAME"
fi

# Ensure home exists
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
mkdir -p "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"

# Install public key if provided
if [ -n "$PUBLIC_KEY" ]; then
  echo "$PUBLIC_KEY" > "$USER_HOME/.ssh/authorized_keys"
  chmod 600 "$USER_HOME/.ssh/authorized_keys"
  chown -R "$USER_NAME":"$USER_NAME" "$USER_HOME/.ssh"
fi

# Set password if provided (allow empty password only if explicitly set empty string)
if [ -n "$USER_PASSWORD" ]; then
  echo "$USER_NAME:$USER_PASSWORD" | chpasswd
fi

# Configure sudo/root access according to SUDO_ACCESS
# Accepted values (case-insensitive): "yes","no","root","passwordless","sudo"
case "$(echo "$SUDO_ACCESS" | tr '[:upper:]' '[:lower:]')" in
  yes|sudo)
    # allow use of sudo with password
    usermod -aG sudo "$USER_NAME"
    # ensure sudo package installed (already installed in image)
    ;;
  passwordless)
    # Add user to sudo and create passwordless sudoers entry
    usermod -aG sudo "$USER_NAME"
    echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90_$USER_NAME"
    chmod 440 "/etc/sudoers.d/90_$USER_NAME"
    ;;
  root)
    # Make the user root-equivalent by setting UID 0 (dangerous) — instead, give passwordless sudo
    usermod -aG sudo "$USER_NAME"
    echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90_$USER_NAME"
    chmod 440 "/etc/sudoers.d/90_$USER_NAME"
    ;;
  no|"")
    # Ensure no sudoers file lingering for this user, and remove from sudo group
    rm -f "/etc/sudoers.d/90_$USER_NAME" 2>/dev/null || true
    # remove from sudo group if present
    if id -nG "$USER_NAME" | grep -qw sudo; then
      gpasswd -d "$USER_NAME" sudo || true
    fi
    ;;
  *)
    # Unrecognized value: default to no sudo
    rm -f "/etc/sudoers.d/90_$USER_NAME" 2>/dev/null || true
    if id -nG "$USER_NAME" | grep -qw sudo; then
      gpasswd -d "$USER_NAME" sudo || true
    fi
    ;;
esac

# Allow SSH password auth only if USER_PASSWORD is set
if [ -n "$USER_PASSWORD" ]; then
  sed -i 's/^#PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
  sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
else
  sed -i 's/^#PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config || true
  sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config || true
fi

# Permit root login only if explicitly allowed (we keep default no)
# Ensure ownership
chown -R "$USER_NAME":"$USER_NAME" "$USER_HOME"

# Obtain initial cookies when no prior cookie file exists.
# Failure is non-fatal so SSH remains available for diagnosis.
if [ -n "$YOU_USER" ] && [ -n "$YOU_PASS" ] &&
   [ ! -s "$YOUTUBE_COOKIES" ]; then
  /usr/local/bin/youtube-login.sh || \
    echo "Initial YouTube login failed; the daily cron job will retry" >&2
fi

# Start sshd (container CMD may override)
exec "$@"
