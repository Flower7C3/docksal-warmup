1. on remote server
    1. `bash .docksal/commands/backup-wp-uploads` – backup uploaded files to archive
    2. `bash .docksal/commands/share-wp-uploads` – share uploaded files archive to $DOCROOT with secret hash URL
2. on local machine (via Docksal)
    1. `fin download-wp-uploads` – download the uploaded files archive from remote URL and save archive in `.docksal/services/cli/uploads/` directory (please define `REMOTE_HOST_URL` in `.docksal/docksal-local.env` file)
    2. `fin restore-wp-uploads` – restore the latest archive from `.docksal/services/cli/uploads/` directory to uploaded files
