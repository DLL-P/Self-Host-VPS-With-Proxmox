# Passo a passo completo

Guia do provisionamento até a concessão de acesso a terceiros, usando os
scripts deste repositório. Comandos marcados **[HOST]** rodam no shell do
Proxmox; comandos marcados **[VM]** rodam dentro da VPS já criada.

## 1. Acessar o Proxmox

- Painel web: `https://IP-DO-PROXMOX:8006`.
- Shell: no painel, selecionar o node e clicar em **Shell**, ou conectar
  via SSH: `ssh root@IP-DO-PROXMOX`.

## 2. Trazer o repositório para o host **[HOST]**

```bash
apt update && apt install -y git
git clone <URL_DO_REPOSITORIO>
cd vps-host
```

## 3. Levantar os valores do ambiente **[HOST]**

```bash
pvesm status          # storages disponíveis
ip -br a              # interfaces e bridges de rede
cat /etc/network/interfaces
```

Registrar: nome do storage de disco (`VM_STORAGE`), storage de imagens
(`ISO_STORAGE`), bridge com saída para internet (`BRIDGE`), e se há um IP
público dedicado para a VM ou apenas o IP do host — isso define
`NETWORK_MODE` (ver `docs/02-rede-ip-externo.md`).

## 4. Gerar uma chave SSH **[HOST ou máquina local]**

```bash
ssh-keygen -t ed25519 -f ~/.ssh/vps_key -C "vps"
```

A chave pública (`.pub`) é usada dentro da VM via cloud-init; a chave
privada permanece com quem for acessar a VM por SSH.

## 5. Configurar `config/vm.env` **[HOST]**

```bash
cp config/vm.env.example config/vm.env
nano config/vm.env
```

| Variável | Valor |
|---|---|
| `VMID` | Um ID livre — confirmar com `qm list` |
| `VM_STORAGE` / `ISO_STORAGE` | Valores obtidos com `pvesm status` |
| `BRIDGE` | Bridge com saída para internet |
| `VM_CORES` / `VM_MEMORY_MB` / `VM_DISK_GB` | Recursos alocados à VM |
| `NETWORK_MODE` | `bridged` (IP público direto) ou `nat` (IP único no host) |
| `VM_IP` / `VM_GATEWAY` / `VM_CIDR` | Endereço da VM |
| `HOST_PUBLIC_IP` | Apenas em modo `nat`: IP público do host |
| `SSH_PUBLIC_KEY_FILE` | Caminho da chave pública gerada no passo 4 |
| `ADMIN_SSH_SOURCE_IP` | Origem autorizada para SSH administrativo |
| `SERVICE_PORTS` | Portas do serviço a ser hospedado |

## 6. Executar o provisionamento **[HOST]**

```bash
cd scripts
chmod +x *.sh
./provision.sh
```

O script cria a VM, configura NAT/port-forward quando aplicável, e
configura o firewall do Proxmox. Em caso de falha, corrigir a variável
correspondente em `config/vm.env` e executar novamente — o script recusa
recriar um VMID já existente; para refazer do zero, remover a VM com
`qm stop <VMID> && qm destroy <VMID>`.

## 7. Verificar a VM **[HOST]**

```bash
qm status <VMID>
qm agent <VMID> ping
```

## 8. Testar o acesso SSH **[máquina local]**

```bash
ssh -i ~/.ssh/vps_key <usuario>@<IP_DA_VM_OU_HOST>
```

Login sem solicitação de senha confirma que a autenticação restrita a
chave está ativa.

## 9. Instalar o serviço **[VM]**

Ver `docs/04-portas-e-servicos.md`.

## 10. Testar o acesso externo

Verificar se a porta responde a partir de fora da rede do provedor
(ferramenta de teste de porta, ou uma conexão originada de outra rede). Se
não houver resposta:

- Modo `bridged`: confirmar se o IP chegou à interface da VM (`ip a`) e se
  o provedor não faz filtragem por endereço MAC.
- Modo `nat`: confirmar as regras com `iptables -t nat -L -n -v` no host,
  e se `HOST_PUBLIC_IP` é o endereço correto.
- Revisar o firewall do Proxmox (Datacenter → node → VMID → Firewall) e o
  UFW dentro da VM (`sudo ufw status`).

## 11. Concessão de acesso a terceiros

Para uso apenas do serviço hospedado, basta informar o endereço (IP
público, ou `HOST_PUBLIC_IP` em modo NAT) e a porta, quando aplicável.

Para acesso administrativo à VM, não compartilhar a própria chave
privada. Solicitar que a outra parte gere sua própria chave e envie apenas
a pública:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
```

No host, adicionar a chave pública recebida à VM:

```bash
ssh -i ~/.ssh/vps_key <usuario>@<IP_DA_VM> \
  "echo 'CONTEUDO_DA_CHAVE_PUBLICA' >> ~/.ssh/authorized_keys"
```

Chaves privadas, senhas e tokens não devem ser enviados por canais sem
criptografia.

## 12. Checklist final

- [ ] SSH root e por senha desabilitados.
- [ ] `ADMIN_SSH_SOURCE_IP` restrito a uma origem conhecida.
- [ ] Porta do serviço testada externamente.
- [ ] Backup da VM configurado no Proxmox (Datacenter → Backup).
- [ ] Acesso entregue por canal seguro.
