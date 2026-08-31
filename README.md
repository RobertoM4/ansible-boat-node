# ansible-boat-node

Repo Ansible per la gestione di un Raspberry Pi 4 di bordo (hostname `boat-node`).

## Requisiti

- Ansible sul Mac di controllo: `brew install ansible` (non incluso di default su macOS).
- Collection richieste: `ansible-galaxy collection install -r requirements.yml` (serve `community.general` per il ruolo `wifi`).
- Chiave SSH ed25519 già presente in `~/.ssh/` e installata sul Pi (via `ssh_authorized_keys` in fase di imaging).
- Connettività verso `boat-node` (vedi `inventory/hosts.yml` — l'host non è hardcoded nei task, viene risolto dalla variabile `ansible_host` in inventory).
- File `.vault_pass` in root del repo (gitignored, permessi 600) con la password di ansible-vault — serve a decifrare `group_vars/all/vault.yml`.

## Struttura

```
inventory/hosts.yml         # host boat-node, IP/hostname come variabile
group_vars/all/vars.yml     # variabili di sito (timezone, pacchetti base, reti wifi note, ...)
group_vars/all/vault.yml    # segreti cifrati con ansible-vault (PSK wifi, ...)
roles/base/                 # hardening SSH, unattended-upgrades, timezone, log2ram, journald, pacchetti
roles/wifi/                 # profili NetworkManager per le reti Wi-Fi note (hotspot, wifi di casa, ...)
roles/sensors/               # utente di servizio, regola udev GPS, logger NMEA -> SQLite, systemd unit
site.yml                    # playbook principale
requirements.yml            # collection Ansible richieste (community.general)
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

## Ruolo `wifi`

Gestisce i profili NetworkManager delle reti Wi-Fi note del nodo
(`community.general.nmcli`), così il Pi si aggancia da solo a qualunque
rete conosciuta sia visibile — utile perché la rete di sviluppo è cambiata
già due volte (hotspot del telefono, poi wifi di casa).

Le reti sono elencate in `wifi_networks` (`group_vars/all/vars.yml`); SSID
e password vivono cifrati in `group_vars/all/vault.yml`
(`ansible-vault`), mai in chiaro nel repo. Per impostarli/modificarli:

```bash
ansible-vault edit group_vars/all/vault.yml
# vault_home_wifi_ssid: "..."
# vault_home_wifi_psk: "..."
```

La password del vault stessa vive in `.vault_pass` (root del repo,
gitignored, permessi 600, referenziato da `vault_password_file` in
`ansible.cfg`) — va salvata anche altrove (password manager) perché senza
non si decifra più `vault.yml`.

## Ruolo `sensors`

Legge il GPS via NMEA e scrive posizione + qualità del fix su SQLite
(`/var/lib/boat-node/sensors.db`), tramite un servizio systemd
(`boat-node-sensors`, `Restart=always`) che gira come utente di servizio
non-root (`boatnode`).

**Prima del primo `ansible-playbook site.yml` con questo ruolo**, il dongle
GPS deve essere collegato al Pi e va ricavato il suo VID/PID USB:

```bash
udevadm info -a -n /dev/ttyUSB0 | grep -E 'idVendor|idProduct'
```

e i valori vanno impostati in `group_vars/all.yml` (sovrascrivono i
placeholder `"CHANGEME"` in `roles/sensors/defaults/main.yml`):

```yaml
gps_usb_vendor_id: "0403"
gps_usb_product_id: "6001"
```

Senza questo passaggio il playbook fallisce subito con un errore esplicito,
invece di installare in silenzio una regola udev che non farà mai match
(fissare la porta seriale a `/dev/gps` è proprio quello che evita che il
device cambi nome se colleghi un altro adattatore seriale a bordo).

Verifica via SQLite dopo l'avvio del servizio:

```bash
sqlite3 /var/lib/boat-node/sensors.db 'select * from readings order by id desc limit 10;'
journalctl -u boat-node-sensors -f
```

## Note operative

- **`host_key_checking` in `ansible.cfg`**: attualmente `False` perché la SD viene riflashata spesso durante il setup e la fingerprint SSH del Pi cambia ad ogni reinstallazione. **Quando il nodo sarà stabile in barca e raggiungibile via internet (non più in fase di reimaging continuo), rimettere `host_key_checking = True`** per non perdere la verifica dell'identità dell'host.

- **Fix Wi-Fi non ancora in Ansible.** Il primo aggancio all'hotspot iPhone falliva per due bug indipendenti: l'SSID configurato via cloud-init usava un apostrofo dritto (`'`) mentre il nome reale della rete usa quello tipografico (`'`, byte UTF-8 `e2 80 99`), e la password era rimasta una PSK esadecimale precalcolata (probabilmente impostazioni in cache dell'Imager) invece del testo in chiaro. Corretto **live** sul Pi con `nmcli connection modify` (SSID e `wifi-sec.psk`), non tramite un ruolo Ansible — la configurazione Wi-Fi del nodo è interamente fuori dal controllo di questo repo, impostata una tantum da cloud-init al primo boot. Se la SD viene riflashata di nuovo prima che il nodo sia sulla rete di bordo definitiva, questo fix va rifatto a mano (o meglio: formalizzato in un ruolo `wifi` se il Wi-Fi resta rilevante oltre la fase di sviluppo).

## Schema di cablaggio

_(da compilare — collegamenti I2C/GPIO dei sensori di bordo)_
