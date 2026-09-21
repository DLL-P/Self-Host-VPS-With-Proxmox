# Portas e serviços

Depois que a VM estiver criada e acessível via SSH, instale o serviço
desejado dentro dela.

## Configuração das portas

A variável `SERVICE_PORTS`, em `config/vm.env`, define quais portas ficam
acessíveis externamente. Formato: `porta/protocolo`, separadas por espaço
quando houver mais de uma.

```
SERVICE_PORTS="8080/tcp 8080/udp"
```

Consultar a documentação do serviço a ser hospedado para identificar
quais portas e protocolos ele utiliza. Após alterar `SERVICE_PORTS`:

- Rodar `scripts/03-firewall.sh` novamente, para atualizar o firewall do Proxmox.
- Em modo `nat`, rodar também `scripts/02-network-nat.sh`, para atualizar o
  redirecionamento de portas.
- Dentro da VM, ajustar o UFW manualmente, se necessário:
  `sudo ufw allow <porta>/<protocolo>`.

## Execução via Docker

Recomenda-se executar o serviço em um contêiner Docker — facilita
atualização, backup e substituição do serviço. Um modelo genérico está em
`examples/docker-compose.example.yml`.

1. Copiar os arquivos de `examples/` para a VM:
   ```bash
   scp examples/docker-compose.example.yml <usuario>@<IP_DA_VM>:~/docker-compose.yml
   scp examples/install-docker.sh <usuario>@<IP_DA_VM>:~/
   ```
2. Instalar o Docker dentro da VM:
   ```bash
   ssh <usuario>@<IP_DA_VM>
   chmod +x install-docker.sh && ./install-docker.sh
   ```
   É necessário logout/login (ou `newgrp docker`) para usar o comando sem `sudo`.
3. Editar `docker-compose.yml`, substituindo a imagem, as portas e as
   variáveis de ambiente pelas do serviço escolhido.
4. Subir o serviço:
   ```bash
   docker compose up -d
   docker compose logs -f
   ```

## Concessão de acesso

Ver `docs/05-passo-a-passo-completo.md`, seção de concessão de acesso.
