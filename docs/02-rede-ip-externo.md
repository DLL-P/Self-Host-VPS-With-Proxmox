# Rede e acesso por IP externo

Há dois cenários possíveis para expor a VPS na internet. A escolha é feita
em `NETWORK_MODE`, em `config/vm.env`.

## Modo `bridged`

Aplicável quando o provedor disponibiliza um **IP público próprio para a
VM** (ex.: bloco de IPs adicionais em um servidor dedicado, ou uma bridge
ligada diretamente à interface WAN).

- A VM usa a bridge física (`vmbr0`, ligada à placa de rede WAN do host).
- `qm` configura `ipconfig0` com o IP público, gateway e máscara
  diretamente na VM, via cloud-init.
- O tráfego chega direto à VM, sem NAT — melhor para latência e mais
  simples na configuração de portas.
- Alguns provedores filtram tráfego por endereço MAC. Se for o caso,
  defina um MAC fixo na VM (`qm set <vmid> --net0
  virtio,bridge=vmbr0,macaddr=XX:XX:XX:XX:XX:XX`) e cadastre-o no painel
  do provedor.

## Modo `nat`

Aplicável quando o host Proxmox tem **um único IP público** e a VM
permanece em rede interna, com as portas do serviço redirecionadas
(DNAT/port-forward) para o IP interno da VM.

- `scripts/02-network-nat.sh` cria uma bridge interna (`vmbr1`, sem IP
  público) e configura:
  - `MASQUERADE`, para a VM ter saída à internet.
  - `DNAT` (port-forward) das portas listadas em `SERVICE_PORTS`, do IP
    público do host para o IP interno da VM.
- As conexões externas devem apontar para o **IP público do host**
  (`HOST_PUBLIC_IP`), não para o IP interno da VM.
- Para acessar SSH da VM também via NAT, é necessário adicionar uma porta
  de gerência (ex.: `2222/tcp` externo → `22/tcp` interno). Não incluído
  por padrão, para evitar expor SSH sem intenção.

## Critério de escolha

| Situação | Modo recomendado |
|---|---|
| Servidor dedicado com bloco de IPs adicionais | `bridged` |
| Host com apenas um IP público | `nat` |

## Verificação após configurar

- [ ] O IP (ou host, em modo NAT) responde a partir de fora da rede do provedor.
- [ ] A porta do serviço responde externamente.
- [ ] SSH não está aberto ao mundo (ver `03-firewall-seguranca.md`).
