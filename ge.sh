#!/bin/bash
# ===============================================
# 🪟 Auto Windows Installer (QEMU + VNC)
# Compatible with Ubuntu/Debian (Contabo VPS)
# Author: ChatGPT
# ===============================================

ISO_PATH="/root/windows.iso"
DISK_PATH="/var/lib/libvirt/images/windows.qcow2"
DISK_SIZE="40G"
RAM_SIZE="4096"   # 4GB RAM
CPU_CORES="2"

# Acak port antara 5901-5999
VNC_PORT_NUM=$((RANDOM % 99 + 1))
VNC_PORT=":$VNC_PORT_NUM"
VNC_DISPLAY=$((5900 + VNC_PORT_NUM))

# --- Link ISO Windows Server 2012 R2 ---
ISO_URL="https://software-static.download.prss.microsoft.com/pr/download/Windows_Server_2012_R2_EVAL_EN-US.ISO"

# --- Cek apakah ISO sudah ada ---
if [ ! -f "$ISO_PATH" ]; then
  echo "🌐 Mengunduh Windows Server 2012 R2 ISO (~4.2GB)..."
  wget -O "$ISO_PATH" "$ISO_URL"
else
  echo "✅ File ISO sudah ada di $ISO_PATH"
fi

# --- Install dependencies ---
echo "📦 Menginstall paket yang dibutuhkan..."
apt update -y >/dev/null 2>&1
apt install -y qemu qemu-utils libvirt-daemon-system bridge-utils virtinst virt-viewer >/dev/null 2>&1

# --- Cek dukungan KVM ---
echo "🔍 Mengecek dukungan KVM..."
if [ -e /dev/kvm ]; then
  echo "✅ KVM tersedia, menggunakan akselerasi hardware"
  KVM_OPT="-enable-kvm"
else
  echo "⚠️  KVM tidak tersedia, menggunakan mode software (-no-kvm)"
  KVM_OPT="-no-kvm"
fi

# --- Buat folder untuk disk ---
mkdir -p /var/lib/libvirt/images

# --- Buat virtual disk ---
if [ ! -f "$DISK_PATH" ]; then
  echo "💽 Membuat virtual disk sebesar $DISK_SIZE..."
  qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE"
else
  echo "✅ Disk sudah ada di $DISK_PATH"
fi

# --- Tampilkan status resource ---
echo ""
echo "📊 STATUS VPS:"
echo "RAM TOTAL: $(free -h | awk '/Mem:/ {print $2}')"
echo "RAM TERPAKAI: $(free -h | awk '/Mem:/ {print $3}')"
echo "DISK ROOT: $(df -h / | awk 'NR==2 {print $2, \"used:\", $3, \"avail:\", $4}')"
echo ""

# --- Jalankan QEMU ---
echo "🚀 Menjalankan installer Windows..."
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "Gunakan aplikasi VNC Viewer untuk mengakses:"
echo "👉  ${IP_ADDR}:${VNC_DISPLAY}"
echo ""
echo "Tunggu 1-2 menit sampai layar instalasi Windows muncul."
echo "Untuk menghentikan, tekan CTRL + C di terminal ini."
echo ""

qemu-system-x86_64 \
  $KVM_OPT \
  -m "$RAM_SIZE" \
  -cpu host \
  -smp cores="$CPU_CORES" \
  -hda "$DISK_PATH" \
  -cdrom "$ISO_PATH" \
  -boot d \
  -vnc "$VNC_PORT" \
  -name "WindowsInstaller" \
  -machine type=pc,accel=tcg \
  -net nic -net user
