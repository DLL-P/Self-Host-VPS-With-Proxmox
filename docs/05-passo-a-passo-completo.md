# Passo a passo completo: criar a VPS e entregar ao cliente

Guia do zero até entregar o acesso ao cliente, usando os scripts deste
repositório. Rode os comandos marcados **[HOST]** dentro do shell do
Proxmox, e os marcados **[VM]** dentro da VPS já criada.

## 1. Acessar o Proxmox

- Painel web: `https://IP-DO-SEU-PROXMOX:8006` (usuário `root`, ou o que
  você configurou).
- Shell: no painel web, clique no node (nome do servidor) na coluna
  esquerda -> botão **Shell**. Ou via SSH direto: `ssh root@IP-DO-PROXMOX`.

Todos os comandos abaixo marcados **[HOST]** rodam nesse shell.

## 2. Trazer o repositório para o host **[HOST]**

```bash
apt update && apt install -y git   # se o git não estiver instalado
git clone https://github.com/DLL-P/vps-host.git
cd vps-host
```

Se o repositório for privado, use um token de acesso pessoal no lugar da
senha, ou `git clone` via SSH com uma chave configurada no GitHub.

## 3. Descobrir os valores do seu ambiente **[HOST]**

Antes de editar a configuração, colete estes dados do seu Proxmox:

```bash
pvesm status          # nomes dos storages disponíveis (ex: local-lvm, local)
ip -br a              # interfaces e bridges de rede (ex: vmbr0)
cat /etc/network/interfaces   # confirma qual bridge tem a interface WAN
```

Anote:
- Nome do storage de disco (`VM_STORAGE`, normalmente `local-lvm`).
- Nome do storage para ISOs/imagens (`ISO_STORAGE`, normalmente `local`).
- Nome da bridge com saída para internet (`BRIDGE`, normalmente `vmbr0`).
- Se você tem **um IP público só** (do próprio host) ou **um IP público
  extra disponível** para dar à VM — isso decide `NETWORK_MODE`
  (veja `docs/02-rede-ip-externo.md`).

## 4. Gerar uma chave SSH (se ainda não tiver) **[HOST ou sua máquina]**

```bash
ssh-keygen -t ed25519 -f ~/.ssh/vps_cliente -C "vps-cliente"
```

Isso cria `~/.ssh/vps_cliente` (privada) e `~/.ssh/vps_cliente.pub`
(pública). A **pública** vai para dentro da VM (via cloud-init); a
**privada** fica com quem vai acessar a VM por SSH (você e/ou o cliente).

## 5. Configurar `config/vm.env` **[HOST]**

```bash
cp config/vm.env.example config/vm.env
nano config/vm.env
```

Preencha com base no que você levantou no passo 3:

| Variável | O que colocar |
|---|---|
| `VMID` | Um ID livre (ex: `9000`) — confira com `qm list` que não está em uso |
| `VM_STORAGE` / `ISO_STORAGE` | Valores do `pvesm status` |
| `BRIDGE` | Bridge com saída internet (ex: `vmbr0`) |
| `VM_CORES` / `VM_MEMORY_MB` / `VM_DISK_GB` | Recursos para o jogo (Minecraft leve: 2 vCPU/4GB já roda; ajuste conforme o jogo) |
| `NETWORK_MODE` | `bridged` se a VM vai ter IP público próprio, `nat` se só o host tem IP público |
| `VM_IP` / `VM_GATEWAY` / `VM_CIDR` | IP público da VM (bridged) ou IP interno tipo `10.10.10.10` (nat) |
| `HOST_PUBLIC_IP` | Só em modo `nat`: o IP público do próprio host |
| `SSH_PUBLIC_KEY_FILE` | Caminho da chave pública gerada no passo 4 (ex: `~/.ssh/vps_cliente.pub`) |
| `ADMIN_SSH_SOURCE_IP` | Seu IP fixo, se tiver (ex: `189.x.x.x/32`). Se não tiver IP fixo, deixe `0.0.0.0/0` por enquanto e restrinja depois |
| `GAME_PORTS` | Portas do jogo (ex: `25565/tcp` para Minecraft Java) — veja tabela em `docs/04-servidor-de-jogos.md` |

Salve (`Ctrl+O`, `Enter`, `Ctrl+X` no nano).

## 6. Rodar o provisionamento **[HOST]**

```bash
cd scripts
chmod +x *.sh
./provision.sh
```

Isso vai, na ordem:
1. Baixar a imagem cloud do Debian 12 (só na primeira vez).
2. Criar a VM com o VMID configurado, cloud-init com usuário `cliente`,
   SSH só por chave, UFW e fail2ban já habilitados.
3. Se `NETWORK_MODE=nat`, criar a bridge interna e as regras de
   NAT/port-forward.
4. Configurar o firewall do Proxmox (bloqueia tudo, libera SSH restrito e
   as portas do jogo).
5. Ligar a VM.

Acompanhe a saída — se algo falhar (ex: storage errado), corrija a
variável em `config/vm.env` e rode `./provision.sh` de novo (o script
recusa recriar um VMID já existente; se precisar refazer do zero, apague a
VM antes com `qm stop <VMID> && qm destroy <VMID>`).

## 7. Verificar se a VM subiu **[HOST]**

```bash
qm status <VMID>
qm agent <VMID> ping        # confirma que o guest agent está respondendo
```

No painel web, o node -> VMID deve aparecer "running" com um gráfico de
rede/CPU ativo.

## 8. Testar o acesso SSH **[sua máquina]**

```bash
ssh -i ~/.ssh/vps_cliente cliente@<IP_DA_VM_OU_HOST_PUBLICO>
```

Se conectar sem pedir senha, o hardening básico está funcionando (login
root e por senha estão desabilitados).

## 9. Instalar o servidor de jogos **[VM]**

Exemplo com Minecraft (veja `docs/04-servidor-de-jogos.md` para outros
jogos):

```bash
# na sua máquina, copie o exemplo para dentro da VM:
scp -i ~/.ssh/vps_cliente -r examples/minecraft cliente@<IP_DA_VM>:~/minecraft

# entre na VM:
ssh -i ~/.ssh/vps_cliente cliente@<IP_DA_VM>
cd ~/minecraft
chmod +x install-docker.sh && ./install-docker.sh
# faça logout/login (ou rode: newgrp docker) para usar docker sem sudo
docker compose up -d
docker compose logs -f   # Ctrl+C para sair do log quando o server terminar de subir
```

## 10. Testar o acesso externo **[sua máquina, fora da rede do provedor]**

- Teste a porta de fora com um site tipo `https://www.yougetsignal.com/tools/open-ports/`
  ou peça pra alguém de outra rede tentar conectar.
- Abra o próprio jogo (cliente Minecraft, etc) e tente conectar usando o
  IP público (e a porta, se for diferente da padrão).

Se não conectar:
- Modo `bridged`: confira se o IP realmente chegou na interface da VM
  (`ip a` dentro da VM) e se o provedor não filtra por MAC (veja
  `docs/02-rede-ip-externo.md`).
- Modo `nat`: confira as regras com `iptables -t nat -L -n -v` no host e
  se `HOST_PUBLIC_IP` é realmente o IP que o cliente vai usar.
- Confira o firewall do Proxmox no painel: Datacenter -> node -> VMID ->
  Firewall, e o UFW dentro da VM (`sudo ufw status`).

## 11. Compartilhar o acesso com o cliente

### O que o cliente precisa para jogar (a maioria dos casos)
Basta passar:
- **Endereço do servidor**: o IP público (modo `bridged`) ou o
  `HOST_PUBLIC_IP` (modo `nat`).
- **Porta**, se o jogo pedir (ex: Minecraft geralmente só pede o IP, a
  porta 25565 é padrão; outros jogos podem exigir informar a porta).

Exemplo de mensagem para o cliente:
> Servidor de Minecraft: `SEU_IP_PUBLICO` (porta padrão 25565, não precisa
> informar). Já pode conectar!

### Se o cliente também quiser administrar a VM (opcional)

Não compartilhe sua própria chave privada. Em vez disso, gere uma chave
específica para ele:

```bash
# o cliente gera a própria chave na máquina dele:
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "cliente"
# ele te manda o CONTEÚDO do arquivo .pub (não o privado) por um canal
# confiável (mensagem, email)
```

No host Proxmox, adicione a chave pública dele na VM:

```bash
ssh -i ~/.ssh/vps_cliente cliente@<IP_DA_VM> \
  "echo 'CONTEUDO_DA_CHAVE_PUBLICA_DO_CLIENTE' >> ~/.ssh/authorized_keys"
```

Agora ele acessa com a própria chave: `ssh cliente@<IP_DA_VM>`.

**Nunca envie chaves privadas, senhas ou tokens por canais não seguros**
(grupos de WhatsApp públicos, e-mail sem criptografia). Prefira mensagem
direta e, se possível, um gerenciador de senhas com compartilhamento
seguro.

### Se quiser dar autonomia sem acesso SSH direto

Para o cliente reiniciar/atualizar o próprio servidor de jogo sem acesso
root, considere no futuro um painel como
[Pterodactyl](https://pterodactyl.io/) rodando na VM — isso está fora do
escopo deste provisionamento inicial, mas pode ser adicionado depois sem
recriar a VM.

## 12. Checklist final antes de entregar

- [ ] SSH root e por senha desabilitados (confirmado no passo 8).
- [ ] `ADMIN_SSH_SOURCE_IP` restrito ao seu IP (ajuste e rode
      `scripts/03-firewall.sh` de novo se ainda estiver `0.0.0.0/0`).
- [ ] Porta do jogo testada de fora da rede do provedor (passo 10).
- [ ] Backup da VM configurado no Proxmox (Datacenter -> Backup).
- [ ] Cliente recebeu IP/porta (e chave SSH, se aplicável) por canal seguro.
