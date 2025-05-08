;;; ds-vault.el --- Minimal GPG-based vault for Emacs  -*- lexical-binding: t; -*-

;; Author: DeadSwitch <deadswitch404@proton.me>
;; Maintainer: DeadSwitch
;; Version: 0.1
;; Package-Requires: ()
;; Homepage: https://github.com/deadswitch404/ds-vault
;; Keywords: security, gpg, encryption, tools

;;; Commentary:

;; ds-vault is a minimalistic, command-line-style password vault for Emacs
;; users who prefer to operate close to the metal. It uses the external
;; GPG command directly, avoiding agents or modules, for full OPSEC clarity.

;; Inspired by the principles of transparency, reversibility, and offline
;; trust, ds-vault lets you seal, decrypt, verify, and back up a KeePass-compatible
;; database without leaving Emacs.

;; See README.org for setup and usage.

;;; Code:


(require 'ds-vault-config)

(defun ds/message (msg)
  (message "[+] %s" msg))

(defun ds/error (msg)
  (message "[!] %s" msg))

(defun ds/encrypt-vault ()
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

(defun ds/decrypt-vault ()
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

(defun ds/backup-vault ()
  (interactive)
  (ds/message "Starting backup process...")
  (make-directory ds/backup-dir t)
  (when (not (file-exists-p ds/encrypted-db))
    (ds/message "Database not encrypted! Encrypting now...")
    (ds/encrypt-vault))
  (let ((backup-file (expand-file-name (format "%s-%s" ds/timestamp (file-name-nondirectory ds/encrypted-db)) ds/backup-dir)))
    (copy-file ds/encrypted-db backup-file t)
    (if (file-exists-p backup-file)
        (ds/message (format "Backup successful: %s" backup-file))
      (ds/error "Backup failed!"))))

(defun ds/vault-help ()
  (interactive)
  (message "
DeadSwitch Vault Manager
Usage: M-x ds/encrypt-vault | decrypt | status | backup

Commands:
  ds/encrypt-vault   Encrypt and sign the KeePass database
  ds/decrypt-vault   Decrypt the encrypted KeePass database
  ds/vault-status    Write out the status of the database
  ds/backup-vault    Backup & encrypt the database

DeadSwitch | The Cyber Ghost
\"In silence, we rise. In the switch, we fade.\"
"))

(provide 'ds-vault)
