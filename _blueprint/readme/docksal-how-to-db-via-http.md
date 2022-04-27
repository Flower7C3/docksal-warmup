### Databases

* `fin db cli` – connect to database from terminal or [read the docs](https://docs.docksal.io/service/db/access/), if You want to connect to database with desktop application
* migrate the database over HTTP with direct access via SSH
    1. on remote server
        1. `bash .docksal/commands/backup-db-on-remote` – backup the database to archive on remote server console
        2. `bash .docksal/commands/share-db-on-remote` – share database archive at `$DOCROOT` with secret hash URL on remote
    2. on local machine (via Docksal)
        1. `fin download-db-from-remote` – download the dump archive from remote URL and save it in `.docksal/services/db/database/dump/` directory (please define `REMOTE_HOST_URL` in `.docksal/docksal-local.env` file)
        2. `fin restore-db` – restore the latest file from `.docksal/services/db/database/dump/` directory to database 

> If You want to automatically import database during `fin init` command put SQL files in `.docksal/services/db/database/init/` directory » [read more in docs](https://docs.docksal.io/service/db/import/).
