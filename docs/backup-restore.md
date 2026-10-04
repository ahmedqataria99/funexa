# Backup and Restore

The Backup & Restore feature provides local database protection through `.furnexa` backup packages.

## Backup

A backup includes database content plus metadata and a SHA-256 checksum. Backup history is recorded and creation is permission-protected.

## Validation and Restore

Restore validates the package extension, format, checksum, and database-version compatibility before replacement. A safety backup is created before restore, and recovery behavior is available when replacement fails. Restore confirmation and audit events are part of the workflow.

Restore is a replacement operation, not a merge. It is local-only: the implementation does not claim cloud storage, encryption, scheduled backups, or background synchronization. Audit history is handled specially so restore does not blindly replace audit records.
