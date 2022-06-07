### Databases

* `fin db cli` – connect to database from terminal or [read the docs](https://docs.docksal.io/service/db/access/), if You want to connect to database with desktop application
* migrate the database with direct access to RDS (You need to store RDS configuration in [.docksal/docksal-local.env](.docksal/docksal-local.env) config file)
    1. `fin backup-db` – backup the database from remote environment and save it in [.docksal/database/dump/](.docksal/database/dump/) directory
    2. `fin restore-db` – restore the latest file from [.docksal/database/dump/](.docksal/database/dump/) directory to database 

> If You want to automatically import database during `fin init` command put SQL files in [.docksal/database/init/](.docksal/database/init/) directory » [read more in docs](https://docs.docksal.io/service/db/import/).
