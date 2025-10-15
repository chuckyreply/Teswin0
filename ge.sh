#!/bin/bash
# ===============================================
#  Windows ISO Installer for Contabo KVM VPS
#  Author: ChatGPT (GPT-5)
#  Tested on Ubuntu 22.04 (KVM)
# ===============================================

set -e

echo "==============================================="
echo "     Windows ISO Auto Installer for KVM VPS"
echo "==============================================="

# --- Cek apakah menggunakan KVM ---
virt_type=$(systemd-detect-virt)
if [ "$virt_type" != "kvm" ]; then
  echo "❌ VPS ini tidak berbasis KVM. Windows tidak bisa diinstal."
  echo "Virtualization detected: $virt_type"
  exit 1
fi
echo "✅ Virtualization: $virt_type (OK)"

# --- Cek RAM dan Disk ---
echo
echo "🔍 Mengecek sumber daya sistem..."
ram_total=$(free -h | awk '/Mem:/ {print $2}')
disk_total=$(df -h / | awk 'NR==2 {print $2}')
disk_free=$(df -h / | awk 'NR==2 {print $4}')
echo "💾 Total Disk: $disk_total (Free: $disk_free)"
echo "🧠 Total RAM: $ram_total"

# --- Pastikan paket yang dibutuhkan terinstal ---
echo
echo "📦 Memasang dependensi yang diperlukan..."
apt update -y
apt install -y qemu-kvm libvirt-daemon-system virtinst wget

# --- Buat direktori untuk image ---
mkdir -p /var/lib/libvirt/images
cd /var/lib/libvirt/images

# --- Unduh Windows ISO (Server 2022 Eval) ---
ISO_PATH="/root/windows.iso"
if [ ! -f "$ISO_PATH" ]; then
  echo
  echo "🌐 Mengunduh Windows Server 2022 ISO (~5GB)..."
  wget -O "$ISO_PATH" "https://software-download.microsoft.com/pr/Windows_Server_2022_EVAL_x64FRE_en-us.iso"
else
  echo "✅ File ISO sudah ada di $ISO_PATH"
fi

# --- Buat disk baru untuk Windows (40GB default) ---
echo
echo "💽 Membuat disk baru untuk Windows (40GB)..."
qemu-img create -f qcow2 /var/lib/libvirt/images/windows.qcow2 40G

# --- Jalankan QEMU (VNC port 5901) ---
echo
echo "🚀 Menjalankan installer Windows..."
echo "Gunakan VNC Viewer dan konek ke: $(hostname -I | awk '{print $1}'):5901"
echo "Tunggu 1-2 menit lalu buka di VNC untuk mulai instalasi."
echo
echo "📡 Command QEMU:"

echo "qemu-system-x86_64 -enable-kvm -m 4096 -cpu host -hda /var/lib/libvirt/images/windows.qcow2 -cdrom $ISO_PATH -boot d -vnc :1"

sleep 3

# Jalankan installer Windows
qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -cpu host \
  -hda /var/lib/libvirt/images/windows.qcow2 \
  -cdrom "$ISO_PATH" \
  -boot d \
  -vnc :1
