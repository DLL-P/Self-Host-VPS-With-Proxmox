# Arquitetura

## Camadas

```
Cliente (SSH / porta exposta)
        │
        ▼ port-forward (iptables DNAT no host)
        │
┌───────────────────────────────────────────┐
│ Host físico (Debian/Ubuntu Server)          │
│  - SO do host mora no SSD (/, boot)         │
│  - KVM + libvirt (hypervisor)               │
│  - Rede NAT libvirt: virbr-vps (isolada)    │
│                                              │
│   ┌────────────────────────────────────┐   │
│   │ VPS "cliente1" (VM KVM)             │   │
│   │  - 1 vCPU / 2 GB RAM                │   │
│   │  - disco: /mnt/vps-storage/... (HD) │   │
│   │  - IP interno: 192.168.150.x        │   │
│   └────────────────────────────────────┘   │
│                                              │
│  Disco de dados: HD mecânico dedicado       │
│  montado em /mnt/vps-storage                │
└───────────────────────────────────────────┘
```

## Por que KVM/libvirt e não Docker/LXC

O cliente recebe uma **VPS de verdade**: kernel próprio, root completo, pode instalar
o que quiser (inclusive Docker dentro da VPS), reiniciar sem afetar o host, e o host
não compartilha namespace de processos/kernel com a VM. É o mesmo modelo usado por
provedores como DigitalOcean/Vultr/Linode.

## Storage: SSD vs HD

- O **SO do host** (Debian/Ubuntu) fica no SSD do sistema — não mexemos nele.
- Um **HD mecânico** separado é formatado e montado em `/mnt/vps-storage`; é lá que
  fica o storage pool do libvirt (`vps-pool`) com as imagens `.qcow2` das VPS's.
- `scripts/install-host.sh` nunca formata um disco sem confirmação explícita — ele
  verifica que o `HDD_DEVICE` informado não é o disco de boot antes de tocar nele.
- Cada VPS usa uma imagem qcow2 com **backing file** na imagem base (cloud image),
  economizando espaço no HD e permitindo criar várias VPS's rapidamente.

## Rede: NAT + port-forward (em vez de bridge)

Optamos por uma rede NAT isolada do libvirt (`virbr-vps`, ex. `192.168.150.0/24`) em vez
de fazer bridge na interface física do host, porque:

- Bridge exige mexer na configuração de rede principal do host — se for feito remotamente
  por SSH e algo der errado, você pode perder acesso ao servidor.
- NAT + DNAT (`iptables`/`nftables`) expõe só as portas que você escolher, e não altera
  a interface de rede do host.

Fluxo de exposição de uma porta (ex. SSH da VPS):
1. VPS recebe IP fixo interno via reserva DHCP do libvirt (baseado no MAC da VM).
2. `manage-vps.sh port-forward <vps> <porta-interna> <porta-host>` cria a regra DNAT.
3. Você configura o **roteador de casa/escritório** para encaminhar a porta externa
   (WAN) para `<porta-host>` no IP LAN do servidor. Isso é feito na interface do seu
   roteador — fora do alcance destes scripts.

Se no futuro você tiver IP público dedicado ou quiser bridge real, veja a seção
"Alternativa: rede em bridge" no `runbook.md`.

## Segurança / isolamento

- CPU e RAM são isolados pelo KVM (hard limits: a VM nunca usa mais que o alocado).
- Disco: cada VPS tem um tamanho virtual fixo (`--disk size=50` GB); ela não consegue
  crescer além disso.
- Opcional (comentado nos scripts): `virsh blkiotune` para limitar I/O em disco por VM,
  importante porque um HD mecânico é um recurso compartilhado entre todas as VPS's nele.
- `harden-host.sh` cobre o host: firewall (ufw/nftables), fail2ban no SSH, updates
  automáticos de segurança, desabilita login root por senha.
- Dentro da VPS, a segurança (updates, firewall interno, usuários) é responsabilidade
  de quem administra a VPS (você entrega como um servidor limpo, com só o essencial).
