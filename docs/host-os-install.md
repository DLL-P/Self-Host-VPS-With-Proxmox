# Instalando o SO do host

Estes passos são feitos *no computador físico* (pen drive de boot + monitor/teclado, ou
IPMI/KVM-over-IP se o servidor tiver). Não podem ser feitos por esta sessão do Claude Code.

## 1. Pré-requisitos de hardware

- CPU com virtualização habilitada na BIOS/UEFI: **Intel VT-x** ou **AMD-V**
  (às vezes chamado de "SVM Mode"). Sem isso o KVM não funciona.
- Pelo menos 2 discos visíveis no BIOS: o **SSD** (onde vai o sistema) e um ou mais
  **HDs** (onde vão ficar as VPS's). Anote o modelo/tamanho de cada um — vai precisar
  identificar o device Linux certo (ex. `/dev/sda` vs `/dev/sdb`) mais adiante.

## 2. Instalar o SO

Recomendado: **Debian 12 (bookworm)**, instalação "Server" mínima (sem ambiente gráfico).
Ubuntu Server 24.04 LTS também funciona (os scripts detectam e ajustam pacotes).

Durante a instalação:
- Particione **apenas o SSD** (ext4, LVM opcional). Não selecione o(s) HD(s) — deixe-os
  intocados; eles serão preparados depois pelo `install-host.sh`.
- Instale o servidor **OpenSSH** quando o instalador perguntar (para administração remota).
- Não selecione "ambiente desktop"/GNOME — só "SSH server" e utilitários padrão.
- Configure uma senha forte para o seu usuário e, se possível, já copie sua chave pública
  SSH (`~/.ssh/authorized_keys`) para não depender de senha depois.

## 3. Primeiro acesso

```bash
ssh seu-usuario@<ip-do-servidor>
sudo -i
```

Confirme que a virtualização está disponível:

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo     # deve ser > 0
ls /dev/kvm                             # deve existir depois de instalar o qemu-kvm
```

## 4. Identificar o SSD (sistema) e o HD (dados)

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL
```

- O disco que aparece montado em `/` (e possivelmente `/boot`) é o **SSD do sistema** —
  nunca aponte os scripts deste repo para ele.
- O(s) outro(s) disco(s), sem partições montadas em `/`, são candidatos a **HD de dados**.
  Confirme o modelo/tamanho batendo com o que você anotou na BIOS.

Guarde o device do HD escolhido (ex. `/dev/sdb`) — ele vai em
`config/vps-defaults.env` como `HDD_DEVICE`.

⚠️ **Esse disco será formatado do zero pelo `install-host.sh`.** Se ele tiver dados
importantes, faça backup antes ou escolha outro disco.

## 5. Rede do host

Configure o host com **IP fixo (ou reserva DHCP no roteador)** — se o IP dele mudar,
os port-forwards configurados no roteador param de funcionar.

Depois disso, siga para `README.md` (Quickstart) para rodar `install-host.sh`.
