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

## 3. Rodar o assistente de configuração **[HOST]**

```bash
cd scripts
chmod +x *.sh
./setup.sh
```

O assistente pergunta, um item por vez, com um valor padrão sugerido
entre colchetes (basta pressionar Enter para aceitá-lo):

- Storage para o disco da VM e para a imagem cloud — listados
  automaticamente a partir de `pvesm status`, para escolher por número.
- Bridge de rede com saída para a internet — listada automaticamente.
- Recursos da VM (CPU, memória, disco).
- Modo de rede: `bridged` (IP público direto) ou `nat` (IP único no
  host) — a diferença é explicada na hora, sem precisar consultar outro
  documento (ver também `docs/02-rede-ip-externo.md`).
- Endereços de IP correspondentes ao modo escolhido, com o IP público do
  host detectado automaticamente quando possível.
- Chave SSH: se houver uma em `~/.ssh`, ela é sugerida como padrão; caso
  contrário, o assistente oferece para gerar uma nova.
- IP autorizado para acesso SSH administrativo — o IP de quem está
  rodando o assistente é detectado automaticamente como sugestão.
- Portas do serviço a ser hospedado.

Ao final, ele mostra um resumo de tudo o que foi configurado e pergunta
se deve executar o provisionamento (`provision.sh`) imediatamente.

Quem preferir editar a configuração manualmente pode pular esta etapa,
copiar `config/vm.env.example` para `config/vm.env`, preencher os valores
à mão e rodar `./provision.sh` diretamente — os comentários no arquivo
descrevem cada variável.

## 4. Verificar a VM **[HOST]**

```bash
qm status <VMID>
qm agent <VMID> ping
```

## 5. Testar o acesso SSH **[máquina local]**

```bash
ssh -i <CHAVE_PRIVADA_SSH> <usuario>@<IP_DA_VM_OU_HOST>
```

`<CHAVE_PRIVADA_SSH>` é o arquivo correspondente à chave pública informada
no assistente (existente, ou a gerada por ele — o caminho aparece no
resumo exibido ao final do `setup.sh`). Login sem solicitação de senha
confirma que a autenticação restrita a chave está ativa.

## 6. Instalar o serviço **[VM]**

Ver `docs/04-portas-e-servicos.md`.

## 7. Testar o acesso externo

Verificar se a porta responde a partir de fora da rede do provedor
(ferramenta de teste de porta, ou uma conexão originada de outra rede). Se
não houver resposta:

- Modo `bridged`: confirmar se o IP chegou à interface da VM (`ip a`) e se
  o provedor não faz filtragem por endereço MAC.
- Modo `nat`: confirmar as regras com `iptables -t nat -L -n -v` no host,
  e se `HOST_PUBLIC_IP` é o endereço correto.
- Revisar o firewall do Proxmox (Datacenter → node → VMID → Firewall) e o
  UFW dentro da VM (`sudo ufw status`).

## 8. Concessão de acesso a terceiros

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
ssh -i <CHAVE_PRIVADA_SSH> <usuario>@<IP_DA_VM> \
  "echo 'CONTEUDO_DA_CHAVE_PUBLICA' >> ~/.ssh/authorized_keys"
```

Chaves privadas, senhas e tokens não devem ser enviados por canais sem
criptografia.

## 9. Checklist final

- [ ] SSH root e por senha desabilitados.
- [ ] `ADMIN_SSH_SOURCE_IP` restrito a uma origem conhecida.
- [ ] Porta do serviço testada externamente.
- [ ] Backup da VM configurado no Proxmox (Datacenter → Backup).
- [ ] Acesso entregue por canal seguro.
