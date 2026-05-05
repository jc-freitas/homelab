# 🏠 Homelab

Seja bem-vindo ao projeto do meu homelab!
Aqui é onde organizo toda a infraestrutura, serviços e automações que rodam localmente — com foco em **controle, privacidade e independência**.

> 💡 A ideia é simples: **parar de depender das Big Techs e rodar tudo em casa.**

---

## 🧭 Arquitetura

![Network Diagram](./diagram.png)

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

* **Proxmox** — virtualização principal
* **TrueNAS VM** — storage central (NFS/SMB)

### 🌐 Rede

* **OpenWrt** — roteador + firewall
* **AdGuard Home** — DNS + bloqueio de anúncios
* **WireGuard** — roteia todo o tráfego da VLAN Trusted para uma VPN

---

## 🐳 Serviços

Todos os serviços rodam via Docker:

```bash
/services
├── cloudflared     # Tunnel para acesso externo
├── evolution-api   # API personalizada
├── immich          # Fotos (Google Photos replacement)
├── n8n             # Automação
├── nextcloud       # Cloud pessoal
├── trilium         # Notas
└── vaultwarden     # Gerenciador de senhas
```

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