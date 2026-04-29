#!/usr/bin/env bash
set -euo pipefail

DISK_PATH="${DISK_PATH:-/data/pfsense.qcow2}"
DISK_SIZE="${DISK_SIZE:-20G}"
ISO_PATH="${ISO_PATH:-/iso/pfsense.iso}"
RAM_MB="${RAM_MB:-2048}"
CPUS="${CPUS:-2}"
LAN_ADDR="172.30.0.3"
PF_ADDR="172.30.0.254"

mkdir -p /data

if [ ! -f "$DISK_PATH" ]; then
  echo "[INFO] Creating a virtual disk in $DISK_PATH with size $DISK_SIZE"
  qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE"
fi

ip link add br-lan type bridge 2>/dev/null || true
ip link set br-lan up

LAN_DOCKER_IF="eth1"

if ip link show "${LAN_DOCKER_IF}" >/dev/null 2>&1; then
  ip addr flush dev "${LAN_DOCKER_IF}" || true
  ip link set "${LAN_DOCKER_IF}" up
  ip link set "${LAN_DOCKER_IF}" master br-lan 2>/dev/null || true
fi

ip addr flush dev br-lan || true
ip addr add "${PF_ADDR}/24" dev br-lan

ip tuntap add dev tap-lan mode tap 2>/dev/null || true
ip link set tap-lan up
ip link set tap-lan master br-lan 2>/dev/null || true

QEMU_ACCEL="-accel tcg"
QEMU_CPU="-cpu max"

if [ -e /dev/kvm ]; then
  QEMU_ACCEL="-enable-kvm"
  QEMU_CPU="-cpu host"
else
  echo "/dev/kvm not found; using TCG emulation, which is very slow but..."
fi

BOOT_ARGS="-boot order=c"

if [ "${INSTALL_ISO}" = "1" ]; then
  if [ ! -f "${ISO_PATH}" ]; then
    echo "ISO not found in ${ISO_PATH}"
    echo "Place the pfSense ISO in ./iso/ or adjust ISO_PATH."
    exit 1
  fi

  BOOT_ARGS="-boot order=d -cdrom ${ISO_PATH}"
else
  echo "Normal mode: boot from disk."
fi

export QEMU_AUDIO_DRV=none

(
  while true; do
    socat -d -d TCP4-LISTEN:11080,bind=0.0.0.0,fork,reuseaddr TCP4:${LAN_ADDR}:80
    sleep 2
  done
) &

(
  while true; do
    socat -d -d TCP4-LISTEN:11222,bind=0.0.0.0,fork,reuseaddr TCP4:${LAN_ADDR}:22
    sleep 2
  done
) &

ip link set eth0 down
sleep 1
ip link set eth0 up

exec qemu-system-x86_64 \
  ${QEMU_ACCEL} \
  ${QEMU_CPU} \
  -m "${RAM_MB}" \
  -smp "${CPUS}" \
  -machine type=q35 \
  -drive file="${DISK_PATH}",format=qcow2,if=virtio \
  ${BOOT_ARGS} \
  \
  -netdev user,id=wan \
  -device virtio-net-pci,netdev=wan,mac=52:54:00:28:00:01 \
  \
  -netdev tap,id=lan,ifname=tap-lan,script=no,downscript=no \
  -device virtio-net-pci,netdev=lan,mac=52:54:00:28:00:02 \
  \
  -vga std \
  -display vnc=0.0.0.0:0 \
  -serial mon:stdio
