#!/bin/sh
set -e

# Defaults
: "${USER_NAME:=developer}"
: "${PUBLIC_KEY:=}"
: "${USER_PASSWORD:=}"
: "${SUDO_ACCESS:=no}"

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
    if ! grep -q "^%sudo" /etc/group; then
      groupadd sudo || true
    fi
    usermod -aG sudo "$USER_NAME"
    # ensure sudo package installed (already installed in image)
    ;;
  passwordless)
    # Add user to sudo and create passwordless sudoers entry
    if ! grep -q "^%sudo" /etc/group; then
      groupadd sudo || true
    fi
    usermod -aG sudo "$USER_NAME"
    echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90_$USER_NAME"
    chmod 440 "/etc/sudoers.d/90_$USER_NAME"
    ;;
  root)
    # Make the user root-equivalent by setting UID 0 (dangerous) — instead, give passwordless sudo
    if ! grep -q "^%sudo" /etc/group; then
      groupadd sudo || true
    fi
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

# Start sshd (container CMD may override)
exec "$@"
