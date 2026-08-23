# 🏠 Homelab

Seja bem-vindo ao projeto do meu homelab!
Aqui é onde organizo toda a infraestrutura, serviços e automações que rodam localmente com foco em **controle, privacidade e independência**.

> 💡 A ideia é simples: **parar de depender das Big Techs e rodar tudo em casa.**

---

## 🧭 Arquitetura

![Network Diagram](../diagram.png)

Minha rede é segmentada em VLANs para isolamento e segurança:

| Rede           | Subnet       | Função                      |
| -------------- | ------------ | --------------------------- |
| Management     | 10.0.1.0/24  | Acesso administrativo       |
| Infrastructure | 10.0.10.0/24 | DNS, proxy, storage         |
| Services       | 10.0.20.0/24 | Aplicações                  |
| Trusted        | 10.0.30.0/24 | Dispositivos pessoais       |
| IoT            | 10.0.40.0/24 | Dispositivos IOT            |

---

## 🧱 Stack Principal

### 🖥️ Host

* **Proxmox** - virtualização principal
* **TrueNAS VM** - storage central (NFS/SMB)

### 🌐 Rede

* **OpenWrt** - roteador + firewall
* **AdGuard Home** - DNS + bloqueio de anúncios
* **WireGuard** - roteia todo o tráfego da VLAN Trusted para uma VPN

---

## 🐳 Serviços

Todos os serviços rodam via Docker, distribuídos em três hosts:

### Servidor — `10.0.10.3`

| Serviço | Função |
| --- | --- |
| `evolution-api` | API Código Aberto para o WhatsApp |
| `gitea` | Git auto-hospedado |
| `homeassistant` | Automação residencial |
| `homebox` | Controle de inventário |
| `homepage` | Dashboard |
| `immich` | Fotos (substituto do Google Photos) |
| `jellyfin` | Servidor de mídia |
| `monitoring` | Prometheus + Grafana |
| `n8n` | Automação |
| `nextcloud` | Cloud pessoal |
| `redis-shared` | Instância Redis compartilhada |
| `rsshub` | Gerador de feeds RSS |
| `searxng` | Metabuscador |
| `trilium` | Notas |

### Roteador — `10.0.10.1` (OpenWrt)

| Serviço | Função |
| --- | --- |
| `caddy` | Proxy reverso — `docker-compose.router.yml` |
| `cloudflared` | Tunnel para acesso externo — `docker-compose.router.yml` |
| `vaultwarden` | Gerenciador de senhas |

Ficam no roteador para que o acesso externo e o cofre sobrevivam a um reboot
do servidor.

### Estação de trabalho

| Serviço | Função |
| --- | --- |
| `immich-ml-remote` | Machine learning do Immich, tirado do servidor |

> Scripts de recuperação específicos de cada host, contornos de ordem de boot
> e relatos de incidente **não** ficam neste repositório — estão num outro,
> privado.

---

## 🚀 Objetivos

* [x] Infraestrutura local completa
* [x] Substituir serviços cloud
* [x] Automação de deploy
* [ ] Melhorar observabilidade (Prometheus/Grafana)

---

> "Se você não está pagando pelo produto, você é o produto."

---

## 📜 Licença

Este projeto está licenciado sob a Licença MIT.
Sinta-se à vontade para utilizar este repositório como base para o seu próprio homelab.
