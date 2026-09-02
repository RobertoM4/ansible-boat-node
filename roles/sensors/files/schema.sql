-- Schema SQLite per le letture dei sensori di bordo.
--
-- Una sola tabella per tutte le sorgenti (GPS, temperatura, batteria, ...):
-- niente migrazioni quando si aggiunge un sensore, basta scrivere righe con
-- un nuovo valore di `source`.
CREATE TABLE IF NOT EXISTS readings (
    id     INTEGER PRIMARY KEY AUTOINCREMENT,
    ts     TEXT NOT NULL,   -- ISO 8601 UTC, es. 2026-08-31T10:15:32Z
    source TEXT NOT NULL,   -- es. gps_lat, gps_lon, gps_fix_quality, gps_satellites
    value  REAL NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_readings_source_ts ON readings (source, ts);

-- Eventi di allarme (drift ormeggio, e in futuro batteria/bilge): tabella
-- separata dalle letture grezze cosi' restano un log durevole anche se in
-- futuro le readings vengono ruotate/potate.
CREATE TABLE IF NOT EXISTS alerts (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    ts         TEXT NOT NULL,   -- ISO 8601 UTC
    kind       TEXT NOT NULL,   -- es. mooring_drift
    state      TEXT NOT NULL,   -- 'triggered' o 'cleared'
    detail     TEXT             -- es. "42.3m dal punto di riferimento"
);
