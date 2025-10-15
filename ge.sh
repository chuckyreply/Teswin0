#!/bin/bash
# ====================================================
# Windows Installer via QEMU + noVNC (Full Auto Script)
# Tested on Ubuntu 22.04 at Contabo VPS (No KVM)
# ====================================================

ISO_URL="https://archive.org/download/windows-server-2012-r2/Windows_Server_2012_R2.ISO"
ISO_PATH="/root/windows.iso"
DISK_PATH="/var/lib/libvirt/images/windows.qcow2"
RAM_SIZE="4096"          # 4GB
VNC_PORT="1"             # :1 = 5901
NOVNC_PORT="6080"

# --- Banner ---
echo "==============================================="
echo "🪟 Windows Installer via QEMU + noVNC"
echo "==============================================="

# --- Update & install dependencies ---
echo "[*] Menginstall dependensi..."
apt update -y
apt install -y qemu qemu-system-x86 qemu-utils novnc websockify wget

# --- Cek ISO ---
if [ ! -f "$ISO_PATH" ]; then
    echo "[*] File ISO belum ada, mengunduh dari sumber..."
    wget -O "$ISO_PATH" "$ISO_URL"
else
    echo "[*] File ISO sudah ada. Memeriksa validitas..."
    ISO_TYPE=$(file "$ISO_PATH" | grep -i "ISO 9660")
    if [ -z "$ISO_TYPE" ]; then
        echo "[!] File ISO rusak atau tidak valid. Mengunduh ulang..."
        rm -f "$ISO_PATH"
        wget -O "$ISO_PATH" "$ISO_URL"
    else
        echo "[OK] File ISO valid."
    fi
fi

# --- Pastikan disk ada ---
if [ ! -f "$DISK_PATH" ]; then
    echo "[*] Membuat disk virtual 60GB..."
    mkdir -p /var/lib/libvirt/images
    qemu-img create -f qcow2 "$DISK_PATH" 60G
else
    echo "[OK] Disk sudah ada di $DISK_PATH"
fi

# --- Cek RAM dan disk ---
echo "📊 STATUS VPS:"
free -h | awk 'NR==2{print "RAM TOTAL:", $2, "| TERPAKAI:", $3}'
df -h / | awk 'NR==2{print "DISK ROOT:", $2, "| TERPAKAI:", $3, "| TERSISA:", $4}'
echo

# --- Cek KVM ---
if lsmod | grep -q kvm; then
    echo "[OK] KVM aktif ✅"
    KVM_OPT="-enable-kvm -cpu host"
else
    echo "[!] KVM tidak tersedia ❌ — menggunakan software mode (lebih lambat)"
    KVM_OPT="-no-kvm -cpu qemu64"
fi

# --- Jalankan noVNC & QEMU ---
IP=$(hostname -I | awk '{print $1}')
echo
echo "🚀 Menjalankan installer Windows..."
echo "🌐 Akses di browser:  http://${IP}:${NOVNC_PORT}/vnc.html"
echo "💻 Atau VNC client:   ${IP}:590${VNC_PORT}"
echo "==============================================="
echo

# Hentikan proses lama
pkill -9 qemu-system-x86_64 2>/dev/null
pkill -9 websockify 2>/dev/null

# Jalankan QEMU
nohup qemu-system-x86_64 \
  $KVM_OPT \
  -m $RAM_SIZE \
  -smp 2 \
  -drive file="$DISK_PATH",if=virtio \
  -cdrom "$ISO_PATH" \
  -boot d \
  -vnc :$VNC_PORT \
  -net nic -net user \
  -rtc base=localtime \
  -no-shutdown \
  -no-reboot \
  > /root/qemu.log 2>&1 &

sleep 5

# Jalankan noVNC
nohup websockify --web=/usr/share/novnc/ ${NOVNC_PORT} localhost:590${VNC_PORT} > /root/novnc.log 2>&1 &

sleep 3
echo "✅ QEMU dan noVNC berhasil dijalankan!"
echo "🌐 Buka: http://${IP}:${NOVNC_PORT}/vnc.html"
echo
echo "ℹ️ Jika masih 'No bootable device', jalankan ini untuk melihat log:"
echo "   cat /root/qemu.log | tail -n 30"
echo
