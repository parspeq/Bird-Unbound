#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=== Starting APT HTTPS-Only Configuration ==="

# 1. Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: Please run this script with sudo." >&2
    exit 1
fi

# 2. Install apt-transport-https on older systems if needed
if [ ! -f /usr/lib/apt/methods/https ]; then
    echo "📦 Installing apt-transport-https for native HTTPS support..."
    apt-get update && apt-get install -y apt-transport-https
fi

# 3. Create a timestamped backup of the APT sources directory
BACKUP_DIR="/etc/apt/backup_sources_$(date +%F_%H-%M-%S)"
echo "🗄️  Creating a configuration backup in: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
[ -f /etc/apt/sources.list ] && cp /etc/apt/sources.list "$BACKUP_DIR/"
[ -d /etc/apt/sources.list.d ] && cp -r /etc/apt/sources.list.d "$BACKUP_DIR/"

# 4. Migrate main sources.list file to HTTPS
if [ -f /etc/apt/sources.list ]; then
    echo "🔧 Modifying /etc/apt/sources.list..."
    # Replace http:// with https:// unless it's localhost or 127.0.0.1
    sed -i -E 's|http://(?!127\.|localhost)([^[:space:]]+)|https://\1|g' /etc/apt/sources.list
fi

# 5. Migrate any third-party lists in sources.list.d to HTTPS
if [ -d /etc/apt/sources.list.d ]; then
    echo "🔧 Modifying files in /etc/apt/sources.list.d/..."
    find /etc/apt/sources.list.d/ -type f -name "*.list" -exec sed -i -E 's|http://(?!127\.|localhost)([^[:space:]]+)|https://\1|g' {} +
    
    # Modern distributions also use the .sources (DEB822) format
    find /etc/apt/sources.list.d/ -type f -name "*.sources" -exec sed -i -E 's|URIs: http://|URIs: https://|g' {} +
fi

# 6. Block unintentional HTTP fallback behavior in APT config
echo "🛡️  Enforcing security block rules against unencrypted HTTP connections..."
cat << 'EOF' > /etc/apt/apt.conf.d/99force-https
// Disables the default HTTP transport execution pathway 
Acquire::http::Proxy "false";
Acquire::BlockHTTP "true";
EOF

# 7. Validate the changes
echo "🔄 Refreshing the package database via HTTPS..."
if apt-get update; then
    echo "✅ Success! Your machine is now strictly using HTTPS for package management."
else
    echo "⚠️  Warning: 'apt update' encountered a problem. Some mirrors may not support HTTPS."
    echo "You can restore your original files from: $BACKUP_DIR"
fi

