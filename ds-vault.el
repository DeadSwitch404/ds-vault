;;
;; DeadSwitch Vault Manager - The Hardened KeepassXC Database
;;

(require 'ds-vault-config)

(unless ds/key-id
  (ds/error "GPG key ID not set!"))

(defun ds/message (msg)
  (message "[+] %s" msg))

(defun ds/error (msg)
  (message "[!] %s" msg))

(defun ds/vault-encrypt ()
  "Encrypt the vault with GPG."
  (interactive)
  (if (not (file-exists-p ds/encrypted-db))
      (progn
        (ds/message "Securing the password vault...")
        (if (eq 0 (call-process "gpg" nil nil nil
                                "--encrypt" "--sign"
                                "--local-user" ds/key-id
                                "--recipient" ds/key-id
                                "-o" ds/encrypted-db
                                ds/clear-db))
            (progn
              (ds/message (format "The vault is sealed: %s" ds/encrypted-db))
              (ds/message "Verifying the seal...")
              (let ((output (shell-command-to-string
                             (format "gpg --decrypt %s 2>&1" ds/encrypted-db))))
                (if (string-match "Good signature from" output)
                    (progn
                      (ds/message (format "Signature verified: signed by %s" ds/key-id))
                      (ds/message "Purging the unencrypted vault...")
                      (delete-file ds/clear-db)
                      (ds/message "Encryption complete."))
                  (ds/error "Signature verification failed!"))))
          (ds/error "Encryption failed!")))
    (ds/error "Encrypted vault already exists. Abort.")))

(defun ds/vault-decrypt ()
  "Decrypt the vault with GPG."
  (interactive)
  (if (and (file-exists-p ds/encrypted-db)
           (not (file-exists-p ds/clear-db)))
      (progn
        (ds/message "Unlocking the vault...")
        (if (eq 0 (call-process "gpg" nil nil nil
                                "--decrypt"
                                "-o" ds/clear-db
                                ds/encrypted-db))
            (progn
              (ds/message (format "Vault unlocked: %s" ds/clear-db))
              (ds/message "Shredding the encrypted seal...")
              (delete-file ds/encrypted-db)
              (ds/message "Decryption complete."))
          (ds/error "Decryption failed!")))
    (ds/error "Cannot decrypt. Either vault is open or encrypted file missing.")))

(defun ds/vault-status ()
  "Query the vault status. It's ENCRYPTED or PLAIN TEXT."
  (interactive)
  (cond
   ((and (file-exists-p ds/encrypted-db)
         (not (file-exists-p ds/clear-db)))
    (ds/message (format "Database is ENCRYPTED (Last modified: %s)"
                        (format-time-string "%F %T" (nth 5 (file-attributes ds/encrypted-db))))))
   ((and (file-exists-p ds/clear-db)
         (not (file-exists-p ds/encrypted-db)))
    (ds/message (format "Database is PLAIN TEXT (Last modified: %s)"
                        (format-time-string "%F %T" (nth 5 (file-attributes ds/clear-db))))))
   ((and (file-exists-p ds/encrypted-db)
         (file-exists-p ds/clear-db))
    (ds/error "Insecure state: both encrypted and decrypted vault exist!"))
   (t
    (ds/error "No vault files found."))))

(defun ds/vault-backup ()
  "Create a time stamped backup file to the backup dir."
  (interactive)
  (ds/message "Starting backup process...")
  (make-directory ds/backup-dir t)
  (when (not (file-exists-p ds/encrypted-db))
    (ds/message "Database not encrypted! Encrypting now...")
    (ds/vault-encrypt))
  (let ((backup-file (expand-file-name (format "%s-%s" ds/timestamp (file-name-nondirectory ds/encrypted-db)) ds/backup-dir)))
    (copy-file ds/encrypted-db backup-file t)
    (if (file-exists-p backup-file)
        (ds/message (format "Backup successful: %s" backup-file))
      (ds/error "Backup failed!"))))

(defun ds/vault-help ()
  "General help text."
  (interactive)
  (message "
DeadSwitch Vault Manager
Usage: M-x ds/vault-encrypt | -decrypt | -status | -backup

Commands:
  ds/vault-encrypt   Encrypt and sign the KeePass database
  ds/vault-decrypt   Decrypt the encrypted KeePass database
  ds/vault-status    Write out the status of the database
  ds/vault-backup    Backup & encrypt the database
"))

(ds/message "ds-vault loaded. Type M-x ds/vault-help for commands.")

(provide 'ds-vault)
