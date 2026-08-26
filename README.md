# ansible-boat-node

Repo Ansible per la gestione di un Raspberry Pi 4 di bordo (hostname `boat-node`).

## Requisiti

- Ansible sul Mac di controllo: `brew install ansible` (non incluso di default su macOS).
- Chiave SSH ed25519 già presente in `~/.ssh/` e installata sul Pi (via `ssh_authorized_keys` in fase di imaging).
- Connettività verso `boat-node` (vedi `inventory/hosts.yml` — l'host non è hardcoded nei task, viene risolto dalla variabile `ansible_host` in inventory).

## Struttura

```
inventory/hosts.yml       # host boat-node, IP/hostname come variabile
group_vars/all.yml        # variabili di sito (timezone, pacchetti base, ...)
roles/base/                # hardening SSH, unattended-upgrades, timezone, log2ram, journald, pacchetti
site.yml                   # playbook principale
ansible.cfg
```

## Uso

```bash
# controllo connettività
ansible boat_nodes -m ping

# dry-run con diff prima di applicare
ansible-playbook site.yml --check --diff

# applicazione reale
ansible-playbook site.yml
```

Tutti i task del ruolo `base` sono scritti per essere idempotenti: una seconda esecuzione di `site.yml` deve dare `changed=0` su ogni host.

## Note operative

- **`host_key_checking` in `ansible.cfg`**: attualmente `False` perché la SD viene riflashata spesso durante il setup e la fingerprint SSH del Pi cambia ad ogni reinstallazione. **Quando il nodo sarà stabile in barca e raggiungibile via internet (non più in fase di reimaging continuo), rimettere `host_key_checking = True`** per non perdere la verifica dell'identità dell'host.

## Schema di cablaggio

_(da compilare — collegamenti I2C/GPIO dei sensori di bordo)_
