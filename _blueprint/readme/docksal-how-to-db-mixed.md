### Databases

* `fin db cli` – connect to database from terminal or [read the docs](https://docs.docksal.io/service/db/access/), if You want to connect to database with desktop application
* migrate the database with direct access via SSH
    1. on remote server
        1. `bash .docksal/commands/backup-db` – backup the database to archive on remote server console
        2. `bash .docksal/commands/share-db` – share database archive at $DOCROOT with secret hash URL on remote
    2. on local machine (via Docksal)
        1. `fin download-db` – download the dump archive from remote URL and save it in `.docksal/services/db/dump/` directory (please define `REMOTE_HOST_URL` in `.docksal/docksal-local.env` file)
        2. `fin restore-db` – restore the latest file from `.docksal/services/db/dump/` directory to database 
* migrate the database with direct access to RDS
    1. `fin backup-db` – backup the database from remote environment and save it in `.docksal/services/db/dump/` directory (this command need direct access to RDS database)
    2. `fin restore-db` – restore the latest file from `.docksal/services/db/dump/` directory to database 

> If You want to automatically import database during `fin init` command put SQL files in `.docksal/services/db/init/` directory » [read more in docs](https://docs.docksal.io/service/db/import/).
