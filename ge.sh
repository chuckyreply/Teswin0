#!/bin/bash
# ============================================================
# Windows Server 2012 R2 Auto Installer for Contabo (KVM VPS)
# Author: GPT-5 (ChatGPT)
# Compatible: Ubuntu 20.04 / 22.04
# ============================================================

set -e

echo "============================================================"
echo "   🪟 Windows Server 2012 R2 Auto Installer for KVM VPS"
echo "============================================================"

# --- 1️⃣ Cek virtualisasi ---
virt_type=$(systemd-detect-virt)
if [ "$virt_type" != "kvm" ]; then
  echo "❌ VPS ini tidak menggunakan KVM (terdeteksi: $virt_type)"
  echo "Instalasi Windows tidak dapat dilakukan di OpenVZ / LXC."
  exit 1
fi
echo "✅ Virtualization detected: $virt_type"

# --- 2️⃣ Cek sumber daya sistem ---
echo
echo "🔍 Mengecek spesifikasi VPS..."
ram_total=$(free -h | awk '/Mem:/ {print $2}')
disk_total=$(df -h / | awk 'NR==2 {print $2}')
disk_free=$(df -h / | awk 'NR==2 {print $4}')
echo "🧠 RAM Total  : $ram_total"
echo "💾 Disk Total : $disk_total (Free: $disk_free)"

# --- 3️⃣ Instal dependensi ---
echo
echo "📦 Memasang paket yang diperlukan..."
apt update -y
apt install -y qemu-kvm libvirt-daemon-system virtinst wget net-tools

# --- 4️⃣ Siapkan direktori image ---
mkdir -p /var/lib/libvirt/images
cd /var/lib/libvirt/images

# --- 5️⃣ Unduh ISO Windows Server 2012 R2 ---
ISO_PATH="/root/windows.iso"
ISO_URL="https://software-static.download.prss.microsoft.com/pr/download/Windows_Server_2012_R2_EVAL_EN-US.ISO"

echo
if [ ! -f "$ISO_PATH" ]; then
  echo "🌐 Mengunduh Windows Server 2012 R2 (resmi Microsoft)..."
  if ! wget -O "$ISO_PATH" "$ISO_URL"; then
    echo "❌ Gagal mengunduh ISO. Periksa koneksi atau URL."
    exit 1
  fi
else
  echo "✅ File ISO sudah ada di $ISO_PATH"
fi

# --- 6️⃣ Buat virtual disk baru untuk Windows ---
echo
echo "💽 Membuat virtual disk (40GB)..."
qemu-img create -f qcow2 /var/lib/libvirt/images/windows.qcow2 40G

# --- 7️⃣ Jalankan installer Windows ---
VNC_PORT=":1"
IP_ADDR=$(hostname -I | awk '{print $1}')

echo
echo "🚀 Menjalankan installer Windows..."
echo "Gunakan aplikasi VNC Viewer untuk mengakses:"
echo "👉  $IP_ADDR:5901"
echo
echo "Tunggu 1-2 menit lalu akan muncul layar instalasi Windows."
echo "Untuk menghentikan, tekan CTRL + C di terminal ini."
echo

sleep 3

# --- Jalankan QEMU dengan Windows ISO ---
qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -cpu host \
  -smp 2 \
  -hda /var/lib/libvirt/images/windows.qcow2 \
  -cdrom "$ISO_PATH" \
  -boot d \
  -vnc $VNC_PORT \
  -device e1000,netdev=net0 \
  -netdev user,id=net0

# --- 8️⃣ Pesan selesai ---
echo
echo "✅ Instalasi Windows sedang berjalan di VNC."
echo "Gunakan VNC Viewer untuk melanjutkan proses setup Windows."
