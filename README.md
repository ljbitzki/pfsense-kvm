# pfSense 2.8 virtualized with QEMU/KVM inside an Ubuntu 24 container
> [!WARNING]
> If another virtualizer or process is using the processor's virtualization flag, QEMU/KVM will not be able to run. Ensure that other virtualizers are **not running, even in the background**.

## Testing and development environment:
- Kubuntu 24.04 LTS
- AMD Ryzen 5 5600X 6-Core Processor
- 32GB of RAM DDR4
- NVMe Storage
- Docker v29.4

## Requirements:

Packages: `git`
```
sudo apt update; sudo apt install git -y
```

## Clone the repository and enter the directory:
```
git clone git@github.com:ljbitzki/pfsense-kvm.git
cd pfsense-kvm || exit 1
```

## ISO image:
> [!NOTE]
> It is necessary to have the pfSense ISO file inside the `iso/` directory, in this example, named `pfsense.iso`.

```
mkdir data/
mkdir iso/
if [[ ! -e "iso/pfsense.iso" ]]; then
    echo "It is necessary to have the pfSense ISO file inside the `iso/` directory, in this example, named `pfsense.iso`."
fi
```

## Execution:
```
docker compose build
docker compose up
```

### VNC service (for accessing the pfSense console):

Use the address `172.30.0.254:5900` to connect with your VNC client (suggested VNC client: `remmina`, but you can use another one of your preference).


Remmina Client Installation:
```
sudo apt install remmina -y
```

Use the address `172.30.0.254:5900` and the VNC protocol.

![Remmina1](/imgs/remmina1.png)

Install pfSense as you normally would, following the official Netgate documentation.
![Remmina3](/imgs/remmina2.png)

The addressing information used in this template is in the `.env-pfsense` file.

## pfSense Addressing:

| Port | Addressing |
| ------ | ------ |
| WAN | Assigned by DHCP |
| LAN | 172.30.0.3 |

## Ports redirected in QEMU/KVM:

| Source | Port | Destination | Port |
| ------ | ------: | ----------- | ----: |
| Host | `11222` | QEMU/KVM | `22` |
| Host | `11080` | QEMU/KVM | `80` |


#### To access pfSense via SSH:
```
ssh admin@172.30.0.254 -p 11222
```

## To stop the pfSense environment:
```
docker compose down
```