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

## Perché queste scelte

**Ansible, non configurazione manuale.** Ogni modifica al Pi passa da un ruolo in questo repo, mai da un comando digitato a mano via SSH. Il motivo non è purismo: la SD verrà riflashata più volte (test, guasti, un eventuale nodo di backup identico), e l'unico modo per non dover ricordare a memoria venti comandi sparsi è che `ansible-playbook site.yml` su una SD vergine ricostruisca tutto da solo. Se durante un debug live si tocca qualcosa a mano (è successo, vedi sotto), va riportato in un ruolo appena possibile — altrimenti il repo mente su cosa gira davvero sul nodo.

**Batteria di servizio separata dalla batteria di avviamento.** Non ancora cablato (tappa 4), ma è una decisione presa da subito: il Pi non deve mai poter scaricare la batteria che fa partire il motore. Circuito elettrico indipendente, sempre — un giorno di batteria scarica per colpa di un Raspberry Pi non è un'opzione.

**Offline-first.** Il nodo deve funzionare senza connessione per settimane: legge sensori, scrive log, fa il suo lavoro anche isolato. Internet serve solo per raggiungerlo da remoto e per gli aggiornamenti di sicurezza automatici — se manca per un mese non succede nulla di grave, si aggiorna quando torna.

**`log2ram` + `journald` in storage volatile.** Una microSD si consuma con le scritture continue, ed è l'unico "disco" che il nodo ha. Tenere i log in RAM invece che scritti di continuo sulla SD allunga la vita della scheda — importante per un dispositivo che non è comodo da raggiungere per sostituirla ogni tanto.

## Note operative

- **`host_key_checking` in `ansible.cfg`**: attualmente `False` perché la SD viene riflashata spesso durante il setup e la fingerprint SSH del Pi cambia ad ogni reinstallazione. **Quando il nodo sarà stabile in barca e raggiungibile via internet (non più in fase di reimaging continuo), rimettere `host_key_checking = True`** per non perdere la verifica dell'identità dell'host.

- **Fix Wi-Fi non ancora in Ansible.** Il primo aggancio all'hotspot iPhone falliva per due bug indipendenti: l'SSID configurato via cloud-init usava un apostrofo dritto (`'`) mentre il nome reale della rete usa quello tipografico (`'`, byte UTF-8 `e2 80 99`), e la password era rimasta una PSK esadecimale precalcolata (probabilmente impostazioni in cache dell'Imager) invece del testo in chiaro. Corretto **live** sul Pi con `nmcli connection modify` (SSID e `wifi-sec.psk`), non tramite un ruolo Ansible — la configurazione Wi-Fi del nodo è interamente fuori dal controllo di questo repo, impostata una tantum da cloud-init al primo boot. Se la SD viene riflashata di nuovo prima che il nodo sia sulla rete di bordo definitiva, questo fix va rifatto a mano (o meglio: formalizzato in un ruolo `wifi` se il Wi-Fi resta rilevante oltre la fase di sviluppo).

## Schema di cablaggio

_(da compilare — collegamenti I2C/GPIO dei sensori di bordo)_
