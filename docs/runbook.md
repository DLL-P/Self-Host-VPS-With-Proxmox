# Runbook

## Criar uma VPS para um novo cliente

```bash
sudo ./scripts/create-vps.sh cliente1
# ou com specs customizadas:
sudo ./scripts/create-vps.sh cliente2 --vcpus 2 --ram-mb 4096 --disk-gb 80
```

Anote o IP interno mostrado no final (ou rode `sudo ./scripts/manage-vps.sh ip cliente1`).

## Acesso externo — ESSENCIAL para servidor de jogo

Servidor de jogo precisa ser alcançável de fora da sua rede. Isso depende de três
camadas, nessa ordem — pule uma e o cliente não vai conseguir conectar:

### 1. Seu provedor de internet (ISP) dá IP público de verdade?

Muitos provedores residenciais usam **CGNAT** (NAT do próprio provedor), e nesse caso
**nenhum port-forward funciona**, nem no roteador nem aqui. Teste:

```bash
curl -s ifconfig.me          # IP que a internet vê
ip addr show                 # ou veja o IP WAN na página de administração do roteador
```

Se o IP do `ifconfig.me` for **diferente** do IP WAN configurado no roteador, você está
atrás de CGNAT. Alternativas nesse caso (fora do escopo destes scripts):
- Pedir ao provedor um "IP público fixo" (às vezes é um adicional pago).
- Usar um túnel reverso (ex. Tailscale Funnel, Cloudflare Tunnel, ou um mini-VPS
  barato só como relay) — exige configuração adicional dentro da VPS do cliente.

Se o IP bate, você tem IP público e pode seguir para o passo 2.

### 2. Port-forward no roteador de casa

Jogos em geral usam **TCP e UDP** (ex: Minecraft = TCP 25565; a maioria dos jogos
baseados em Source/Unreal/etc usa também UDP nas mesmas portas ou numa faixa).
No painel do seu roteador, encaminhe a porta externa desejada para o **IP do host na
LAN**, na mesma porta que você vai usar no comando abaixo — para **TCP e UDP**.

### 3. Port-forward do host para a VPS

```bash
# expõe a porta 25565 da VPS (Minecraft, por ex.) na porta 25565 do host, TCP+UDP
sudo ./scripts/manage-vps.sh port-forward cliente1 25565 25565 both

# se o jogo usar só UDP (a maioria dos FPS) ou só TCP, pode restringir:
sudo ./scripts/manage-vps.sh port-forward cliente1 27015 27015 udp
```

Isso já libera a porta no `ufw` do host e cria as regras DNAT (persistidas via
`netfilter-persistent`, sobrevivem a reboot). Depois é só apontar o roteador (passo 2)
para a mesma porta.

Para remover: `sudo ./scripts/manage-vps.sh port-unforward cliente1 25565 25565 both`
Para ver o que está exposto: `sudo ./scripts/manage-vps.sh list-forwards`

### 4. IP dinâmico? Configure DDNS

Se seu IP público muda de tempos em tempos (comum em conexão residencial), configure
um serviço de DNS dinâmico (DuckDNS, No-IP, ou o DDNS embutido no seu roteador) para
o cliente sempre usar um hostname (`cliente1.duckdns.org`) em vez do IP puro.

### 5. Testar de fora de verdade

Teste a partir de uma rede diferente da sua (ex. 4G do celular, com wifi desligado),
não de dentro da própria LAN — testar de dentro pode "funcionar" mesmo com o
port-forward errado (NAT hairpinning) e mascarar o problema.

```bash
nc -zv <seu-ip-ou-ddns> 25565      # TCP
nc -zuv <seu-ip-ou-ddns> 25565     # UDP (menos confiável de testar, teste com o próprio jogo)
```

## Entregar a VPS ao cliente

Checklist de handover:
- [ ] IP/hostname (DDNS) e porta(s) que ele vai usar
- [ ] Usuário SSH (`DEFAULT_VPS_USER`) — acesso é só por chave SSH, sem senha
- [ ] Specs contratadas (vCPU/RAM/disco) — confirme com `virsh dominfo <vps>`
- [ ] Explicar que updates/firewall internos da VPS são responsabilidade dele
- [ ] Se for servidor de jogo: qual porta o jogo usa e se é TCP/UDP/ambos

## Monitorar recursos

```bash
virt-top                       # CPU/RAM em tempo real de todas as VPS's
df -h /mnt/vps-storage         # espaço livre no HD compartilhado entre VPS's
virsh domblkinfo cliente1 vda  # uso de disco de uma VPS específica
```

## Remover uma VPS

```bash
sudo ./scripts/manage-vps.sh port-unforward cliente1 25565 25565 both
sudo ./scripts/manage-vps.sh delete cliente1
```

## Alternativa: rede em bridge (avançado)

Só considere isso se souber o que está fazendo — mexer na interface de rede física
remotamente pode derrubar seu acesso SSH ao host. Em vez de NAT+DNAT, você criaria uma
bridge (`br0`) na interface física e ligaria a VPS diretamente nela, dando IP da LAN
(ou público, se o ISP entregar múltiplos IPs via bridge) direto à VM. Recomenda-se ter
acesso físico/IPMI ao servidor antes de tentar.
