# Rede e acesso por IP externo

Existem dois cenários comuns para expor a VPS na internet. Escolha um em
`NETWORK_MODE` no `config/vm.env`.

## Modo `bridged` (recomendado quando disponível)

Use quando o provedor/datacenter dá um **IP público próprio para a VM**
(ex: bloco de IPs adicionais em um servidor dedicado, ou uma bridge ligada
diretamente à interface WAN).

- A VM usa a bridge física (`vmbr0`, ligada à placa de rede WAN do host).
- `qm` configura `ipconfig0` com o IP público, gateway e máscara direto na
  VM via cloud-init.
- Tráfego chega direto na VM; não há NAT no meio, o que é melhor para
  latência e simplifica a configuração de portas (basta o firewall).
- **Cuidado**: confirme com o provedor se o uso de IP adicional por MAC
  address é livre ou se precisa cadastrar o MAC da interface virtual da VM
  (alguns provedores fazem filtragem por MAC/porta). Se for o caso, defina
  um MAC fixo na VM (`qm set <vmid> --net0
  virtio,bridge=vmbr0,macaddr=XX:XX:XX:XX:XX:XX`) e cadastre-o no painel do
  provedor.

## Modo `nat` (um único IP público no host)

Use quando o host Proxmox só tem **um IP público** e a VM precisa ficar em
uma rede interna, com as portas do jogo redirecionadas (DNAT/port-forward)
do IP do host para o IP interno da VM.

- `scripts/02-network-nat.sh` cria uma bridge interna (`vmbr1`, sem IP
  público) e configura:
  - `MASQUERADE` para a VM conseguir sair para a internet.
  - `DNAT` (port-forward) das portas listadas em `GAME_PORTS` do IP público
    do host para o IP interno da VM.
- O cliente vai jogar apontando para o **IP público do host**
  (`HOST_PUBLIC_IP`), não para o IP interno da VM.
- Se quiser acessar SSH da VM também via NAT, adicione uma porta de
  gerência (ex: encaminhar `2222/tcp` externo -> `22/tcp` interno) — não
  incluído por padrão para evitar expor SSH sem querer.

## Qual escolher?

| Situação | Modo recomendado |
|---|---|
| Servidor dedicado com bloco de IPs adicionais | `bridged` |
| VPS/host com apenas 1 IP público | `nat` |
| Quer simplicidade máxima e tem IP sobrando | `bridged` |

## Checklist depois de configurar

- [ ] `ping <ip-da-vm-ou-host>` responde de fora da rede do provedor.
- [ ] A porta do jogo responde externamente (use um scanner de porta ou
      peça para o cliente testar a conexão do jogo).
- [ ] SSH **não** está aberto para o mundo (veja `03-firewall-seguranca.md`).
