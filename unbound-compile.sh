#!/bin/bash

# Colors for output
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

# Variables
REPO="https://github.com/NLnetLabs/unbound"
CLONE_DIR="/root/custom-unbound/unbound-master"
VERSION_FILE="/root/custom-unbound/last_compiled_version.txt"

# Ensure the clone directory exists
mkdir -p "$CLONE_DIR"

# Fetch the latest release from GitHub
echo -e "${BLUE}Fetching the latest release from GitHub...${RESET}"
latest_version=$(curl -s https://api.github.com/repos/NLnetLabs/unbound/releases/latest | jq -r '.tag_name')

# Check if the version file exists, otherwise create it
if [ ! -f "$VERSION_FILE" ]; then
    echo "0.0.0" > "$VERSION_FILE"
fi

# Read the previously compiled version
previous_version=$(cat "$VERSION_FILE")

echo -e "${YELLOW}Previously compiled version: ${RESET}$previous_version"
echo -e "${YELLOW}Latest available version: ${RESET}$latest_version"

# Compare versions
if [ "$latest_version" == "$previous_version" ]; then
    echo -e "${GREEN}You already have the latest version (${RESET}$previous_version${GREEN}) compiled. Exiting.${RESET}"
    exit 0
fi

# If a newer version is found, proceed
echo -e "${RED}New version detected! Updating to $latest_version...${RESET}"

# Clone the repository if it doesn't exist, otherwise fetch updates
if [ ! -d "$CLONE_DIR/.git" ]; then
    echo -e "${BLUE}Cloning the repository...${RESET}"
    git clone "$REPO" "$CLONE_DIR"
else
    cd "$CLONE_DIR"
    echo -e "${BLUE}Fetching updates from the repository...${RESET}"
    git fetch --tags
fi

# Check out the latest version
cd "$CLONE_DIR"
echo -e "${BLUE}Checking out the latest version (${RESET}$latest_version${BLUE})...${RESET}"
git checkout "tags/$latest_version" -b "build-$latest_version"

# Compile
echo -e "${YELLOW}Configuring and compiling...${RESET}"
export CFLAGS="-O2"
./configure --build=aarch64-linux-gnu \
    --prefix=/usr \
    --includedir=\${prefix}/include \
    --infodir=\${prefix}/share/info \
    --libdir=\${prefix}/lib/aarch64-linux-gnu \
    --mandir=\${prefix}/share/man \
    --localstatedir=/var \
    --runstatedir=/run \
    --sysconfdir=/etc \
    --with-chroot-dir= \
    --with-dnstap-socket-path=/run/dnstap.sock \
    --with-libevent \
    --with-libhiredis \
    --with-libnghttp2 \
    --with-pidfile=/run/unbound.pid \
    --with-pythonmodule \
    --with-pyunbound \
    --with-rootkey-file=/var/lib/unbound/root.key \
    --disable-dependency-tracking \
    --disable-flto \
    --disable-maintainer-mode \
    --disable-option-checking \
    --disable-rpath \
    --disable-silent-rules \
    --enable-cachedb \
    --enable-dnstap \
    --enable-subnet \
    --enable-systemd \
    --enable-tfo-client \
    --enable-tfo-server

make

# Prompt before installation
echo -e "${YELLOW}Compilation completed. Do you want to proceed with installation? (yes/no)${RESET}"
read -p "> " confirm
if [[ "$confirm" != "yes" ]]; then
    echo -e "${RED}Installation aborted. Exiting.${RESET}"
    exit 1
fi

# Install and restart Unbound
echo -e "${BLUE}Installing Unbound...${RESET}"
sudo make install

# Update the version file
echo "$latest_version" > "$VERSION_FILE"

# Restart the Unbound service
echo -e "${BLUE}Restarting the Unbound service...${RESET}"
systemctl restart unbound

echo -e "${GREEN}Unbound successfully updated to version $latest_version and restarted.${RESET}"
