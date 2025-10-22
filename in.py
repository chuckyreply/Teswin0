#!/usr/bin/env python3
import os
import subprocess
import time

VNC_PORT = 5900
NOVNC_PORT = 6080

# ===============================
# CEK SISTEM
# ===============================
print("📊 Mengecek sistem VPS...\n")
os.system("uname -a")
cpu_info = os.popen("nproc").read().strip()
ram_info = os.popen("free -g | awk '/Mem/ {print $2}'").read().strip()
disk_info = os.popen("df -h / | awk 'NR==2 {print $2}'").read().strip()

print(f"\n🧠 CPU Cores: {cpu_info}")
print(f"💾 RAM Total: {ram_info} GB")
print(f"📀 Disk Total: {disk_info}")

# ===============================
# BERSIHKAN PROSES LAMA
# ===============================
print("\n🧹 Membersihkan proses QEMU/noVNC lama...")
os.system("pkill -9 qemu-system-x86_64 2>/dev/null || true")
os.system("pkill -9 websockify 2>/dev/null || true")

# ===============================
# PILIH WINDOWS
# ===============================
versions = {
    "1": ("Windows Server 2016", "windows2016.iso", "https://go.microsoft.com/fwlink/p/?LinkID=2195174&clcid=0x409"),
    "2": ("Windows Server 2019", "windows2019.iso", "https://go.microsoft.com/fwlink/p/?LinkID=2195167&clcid=0x409"),
    "3": ("Windows Server 2022", "windows2022.iso", "https://go.microsoft.com/fwlink/p/?LinkID=2195280&clcid=0x409"),
}

print("\n📦 Pilih versi Windows:")
for k, v in versions.items():
    print(f"[{k}] {v[0]}")
choice = input("Pilih (1-3): ").strip()
if choice not in versions:
    exit("❌ Pilihan tidak valid.")

version, iso_file, iso_link = versions[choice]

# ===============================
# KONFIGURASI VM
# ===============================
cpu_vm = input(f"Jumlah CPU [2]: ").strip() or "2"
ram_vm = input(f"RAM (GB) [4]: ").strip() or "4"
disk_vm = input(f"Disk (GB) [30]: ").strip() or "30"

# ===============================
# INSTALL DEPENDENSI
# ===============================
print("\n📦 Menginstall dependensi utama...")
os.system("apt update -y && apt install -y qemu-system-x86 novnc websockify wget genisoimage curl lsof")

# ===============================
# UNDUH FILE ISO
# ===============================
if not os.path.exists(iso_file):
    print(f"\n🌐 Mengunduh {version} dari Microsoft...")
    os.system(f"wget -O {iso_file} '{iso_link}'")
if not os.path.exists("virtio-win.iso"):
    print("\n🌐 Mengunduh VirtIO Driver ISO...")
    os.system("wget -O virtio-win.iso 'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso'")

# ===============================
# CEK KVM
# ===============================
print("\n🔍 Mengecek dukungan KVM...")
kvm_enabled = os.path.exists("/dev/kvm")
kvm_flag = "-enable-kvm -cpu host" if kvm_enabled else "-cpu qemu64"
print("✅ KVM aktif" if kvm_enabled else "⚠️  KVM tidak aktif, menggunakan mode software.")

# ===============================
# BUAT DISK
# ===============================
disk_file = f"{version.replace(' ', '_').lower()}_{disk_vm}g.qcow2"
if not os.path.exists(disk_file):
    print(f"\n💽 Membuat disk virtual {disk_vm}GB...")
    os.system(f"qemu-img create -f qcow2 {disk_file} {disk_vm}G")

# ===============================
# BUAT AUTOSETUP
# ===============================
print("\n⚙️ Membuat file autounattend.xml...")
autounattend = """<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
            publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <AutoLogon>
                <Password>
                    <Value>Admin@2210</Value>
                    <PlainText>true</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <Username>Administrator</Username>
            </AutoLogon>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>Admin@2210</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <RegisteredOwner>Admin</RegisteredOwner>
            <TimeZone>SE Asia Standard Time</TimeZone>
        </component>
    </settings>
</unattend>
"""
open("autounattend.xml", "w").write(autounattend)
os.system("genisoimage -o autounattend.iso autounattend.xml > /dev/null 2>&1")

# ===============================
# JALANKAN VM
# ===============================
print(f"\n🚀 Menjalankan {version} di QEMU...")
cmd = (
    f"nohup qemu-system-x86_64 {kvm_flag} "
    f"-m {ram_vm}G -smp {cpu_vm} "
    f"-drive file={disk_file},if=virtio "
    f"-cdrom {iso_file} "
    f"-drive file=virtio-win.iso,media=cdrom "
    f"-drive file=autounattend.iso,media=cdrom "
    f"-boot order=d -vga std "
    f"-net nic -net user,hostfwd=tcp::3389-:3389 "
    f"-vnc 0.0.0.0:{VNC_PORT-5900} > vm.log 2>&1 &"
)
os.system(cmd)
time.sleep(4)

# ===============================
# JALANKAN NOVNC
# ===============================
print("\n🌐 Menjalankan noVNC...")
os.system(f"nohup websockify --web=/usr/share/novnc {NOVNC_PORT} localhost:{VNC_PORT} > novnc.log 2>&1 &")
time.sleep(2)

# ===============================
# PEMBUKAAN PORT 6080
# ===============================
print("\n🛠️ Membuka port 6080 (noVNC)...")

def run(cmd):
    os.system(cmd + " >/dev/null 2>&1")

if os.system("command -v ufw >/dev/null 2>&1") == 0:
    print("[+] UFW terdeteksi — membuka port...")
    run(f"ufw allow {NOVNC_PORT}/tcp")
    run("ufw reload")
elif os.system("systemctl is-active --quiet firewalld") == 0:
    print("[+] Firewalld terdeteksi — membuka port...")
    run(f"firewall-cmd --add-port={NOVNC_PORT}/tcp --permanent")
    run("firewall-cmd --reload")
elif os.system("command -v nft >/dev/null 2>&1") == 0:
    print("[+] nftables terdeteksi — menambahkan aturan sementara...")
    run(f"nft add rule inet filter input tcp dport {NOVNC_PORT} accept")
elif os.system("command -v iptables >/dev/null 2>&1") == 0:
    print("[+] iptables klasik terdeteksi — membuka port...")
    run(f"iptables -I INPUT -p tcp --dport {NOVNC_PORT} -j ACCEPT")
    if os.system("command -v netfilter-persistent >/dev/null 2>&1") == 0:
        run("netfilter-persistent save")
else:
    print("[!] Tidak ada firewall aktif, port kemungkinan sudah terbuka.")

print(f"[*] Verifikasi port {NOVNC_PORT}...")
os.system(f"ss -tuln | grep :{NOVNC_PORT} || echo '[!] Port belum terlihat aktif.'")

# ===============================
# INFORMASI AKHIR
# ===============================
vps_ip = os.popen("hostname -I | awk '{print $1}'").read().strip()
print("\n✅ Instalasi Windows dimulai di background.")
print(f"🪟 Versi: {version}")
print(f"🔑 Password: Admin@2210")
print(f"🌐 Akses noVNC: http://{vps_ip}:{NOVNC_PORT}/vnc.html")
print(f"🖥️  Akses RDP: {vps_ip}:3389")
print("\n🛑 Hentikan VM:")
print("   pkill -9 qemu-system-x86_64 && pkill -9 websockify")
