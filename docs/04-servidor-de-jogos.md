# Instalando o servidor de jogos

Depois que a VM estiver criada e acessível via SSH, instale o servidor do
jogo desejado dentro dela. Recomenda-se rodar o servidor de jogos em
**Docker**, o que facilita atualização, backup e troca de jogo no futuro.

## Portas comuns por jogo

Configure `GAME_PORTS` em `config/vm.env` com as portas do jogo escolhido
**antes** de rodar `provision.sh` (ou rode `scripts/03-firewall.sh` de novo
depois de mudar `GAME_PORTS`, e ajuste o UFW dentro da VM manualmente com
`sudo ufw allow <porta>/<protocolo>`).

| Jogo | Portas |
|---|---|
| Minecraft Java | `25565/tcp` |
| Minecraft Bedrock | `19132/udp` |
| CS2 / CS:GO | `27015/tcp` `27015/udp` |
| Rust | `28015/tcp` `28015/udp` `28016/tcp` |
| Valheim | `2456/udp` `2457/udp` `2458/udp` |
| ARK: Survival Evolved | `7777/udp` `7778/udp` `27015/udp` |
| Terraria | `7777/tcp` |
| Palworld | `8211/udp` |

## Exemplo pronto: Minecraft via Docker

1. Copie a pasta `examples/minecraft/` para a VM:
   ```bash
   scp -r examples/minecraft cliente@<IP_DA_VM>:~/minecraft
   ```
2. Instale o Docker dentro da VM:
   ```bash
   ssh cliente@<IP_DA_VM>
   cd ~/minecraft
   chmod +x install-docker.sh && ./install-docker.sh
   ```
   (faça logout/login para o grupo `docker` valer)
3. Suba o servidor:
   ```bash
   cd ~/minecraft
   docker compose up -d
   docker compose logs -f   # acompanhar a inicialização
   ```
4. O jogo já deve estar acessível em `<IP_DA_VM>:25565` (bridged) ou
   `<HOST_PUBLIC_IP>:25565` (nat).

## Outros jogos

A maioria dos servidores de jogos populares tem uma imagem Docker mantida
pela comunidade (ex: `itzg/minecraft-server`, `didstopia/valheim-server`,
imagens no Docker Hub para Rust/ARK via `cm2network`, etc). O padrão é o
mesmo:

1. Ajustar `GAME_PORTS` em `config/vm.env` para as portas do jogo.
2. Rodar `scripts/03-firewall.sh` (e `02-network-nat.sh` se estiver em modo
   NAT) para liberar as novas portas.
3. Criar um `docker-compose.yml` próprio baseado no exemplo do Minecraft,
   trocando a imagem e as portas.

## Entregando o acesso ao cliente

Repasse ao cliente:

- IP/porta para conectar no jogo.
- Usuário/chave SSH, caso ele também precise administrar a VM (opcional).
- Deixe claro que a chave SSH é a única forma de login administrativo
  (não há senha configurada).
