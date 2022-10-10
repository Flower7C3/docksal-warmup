### PHP

You can execute any PHP command with `fin exec php SCRIPT_NAME`.

To enable XDEBUG:
1. configure it in IDE, eg. in [PHPStorm](https://www.jetbrains.com/help/phpstorm/configuring-xdebug.html).
2. add this to [.docksal/docksal-local.env](.docksal/docksal-local.env) file:

       XDEBUG_ENABLED=1
       PHP_IDE_CONFIG="serverName=${VIRTUAL_HOST}"

3. restart docksal with `fin start` command.
