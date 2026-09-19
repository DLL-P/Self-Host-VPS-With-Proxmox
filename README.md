# vps-host

Automação para transformar um servidor físico (com SSD de sistema + HD(s) de dados) em
um host de VPS baseado em **KVM/QEMU + libvirt**, para oferecer máquinas virtuais isoladas
a clientes/colegas.

Especificação padrão da primeira VPS: **1 vCPU / 2 GB RAM / 50 GB de disco**, com o disco
da VM alocado em um HD mecânico dedicado (nunca no SSD onde roda o sistema operacional do host).

> **Importante:** estes scripts foram feitos para rodar *no seu servidor físico real*
> (via SSH/terminal local), não dentro desta sessão do Claude Code — que roda numa sandbox
> isolada na nuvem, sem acesso aos discos do seu computador.

## Estrutura

```
docs/
  architecture.md      - desenho da solução (storage, rede, segurança)
  host-os-install.md   - como instalar o SO do host (SSD) e preparar o HD de dados
  runbook.md           - operações do dia a dia (criar/listar/entregar/remover VPS)
config/
  vps-defaults.env.example - specs padrão (vCPU/RAM/disco) e caminhos
scripts/
  install-host.sh   - instala KVM/libvirt, prepara o HD e a rede NAT
  harden-host.sh    - hardening básico do host (firewall, SSH, fail2ban, updates)
  create-vps.sh      - cria uma nova VPS para um cliente (cloud-init automático)
  manage-vps.sh      - lista/inicia/para/remove/redimensiona/faz port-forward de VPS's
cloud-init/
  user-data.tmpl.yaml  - template de provisionamento inicial da VPS (usuário + chave SSH)
  meta-data.tmpl.yaml
```

## Quickstart (no servidor físico, como root)

```bash
git clone <este repo> vps-host && cd vps-host
cp config/vps-defaults.env.example config/vps-defaults.env
# edite config/vps-defaults.env: aponte HDD_DEVICE para o HD correto (NÃO o SSD do sistema)

sudo ./scripts/install-host.sh          # instala KVM/libvirt e prepara HD + rede
sudo ./scripts/harden-host.sh           # firewall, fail2ban, updates automáticos

sudo ./scripts/create-vps.sh cliente1   # cria a VPS com specs padrão (1vCPU/2GB/50GB)

sudo ./scripts/manage-vps.sh list
sudo ./scripts/manage-vps.sh port-forward cliente1 22 2201        # SSH da VPS na porta 2201 do host
sudo ./scripts/manage-vps.sh port-forward cliente1 25565 25565 both  # servidor de jogo (TCP+UDP)
```

Veja `docs/host-os-install.md` antes de rodar `install-host.sh` (precisa saber qual
dispositivo é o HD e qual é o SSD do sistema) e `docs/runbook.md` para o checklist de
entrega ao cliente — **leia a seção "Acesso externo" do runbook antes de prometer
conexão externa ao cliente**: além do port-forward no host, depende do roteador de
casa e de você não estar atrás de CGNAT do provedor.
