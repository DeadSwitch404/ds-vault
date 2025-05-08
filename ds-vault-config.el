(defvar ds/key-id "YOUR-GPG-KEY-ID")
(defvar ds/clear-db "/path/to/vault.kdbx")
(defvar ds/encrypted-db "/path/to/vault.kdbx.gpg")
(defvar ds/backup-dir "/path/to/backups/")
(defvar ds/timestamp (format-time-string "%Y%m%d-%H%M%S"))

(provide 'ds-vault-config)
