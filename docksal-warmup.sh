#!/usr/bin/env bash

## Warmup Docksal configuration for project
##
## Usage: fin warmup [--self-update] [<PROJECT_NAME> <DOMAIN_NAME> <APPLICATION_STACK>]
##      --self-update — download latest version from GitHub
##      PROJECT_NAME — project directory name
##      DOMAIN_NAME — project domain name (without .docksal tld, avoid underscore)
##      APPLICATION_STACK — configuration stack: custom, php, php-nodb, node, boilerplate

if [[ -L "$BASH_SOURCE" ]]; then
    _bash_source="$(readlink "$BASH_SOURCE")"
else
    _bash_source="$BASH_SOURCE"
fi

system_programs=(curl)
custom_programs=(fin jq)
required_programs=("${custom_programs[@]}" "${system_programs[@]}")

source "$(dirname "$_bash_source")/vendor/bash-tools/_base.sh"

# WELCOME
program_title "Docksal configuration warmup"
if [[ "$1" == "--self-update" ]]; then
    display_header "Self update"
    cd "$(dirname "$_bash_source")"
    git checkout -- .
    git pull origin master
    git submodule update --init --recursive
    git submodule foreach git pull origin master
    exit
fi

function get_docker_registry_versions() {
    local registry=$1
    local replace=$2
    local versions
    versions=($(fin image registry $registry | grep -v build | grep -v edge | grep -v ide | grep -v codebase | grep -v latest | grep -v stable | grep -v '-'))
    for version in "${versions[@]}"; do
        echo "$version" | sed "s|$replace||g"
    done
}

function get_nodejs_versions() {
    local versions
    versions=($(curl -s https://nodejs.org/dist/index.json | jq -r '.[].version'))
    for version in "${versions[@]}"; do
        if [[ "$version" == *.0.0 ]]; then
            echo "${version/.0.0/}"
        fi
    done
}

function copy_file() {
    local src_file_name=$1
    local dst_file_name=${2:-$src_file_name}
    local source_file_path="${docksal_example_dir}${src_file_name}"
    local destination_file_path=".docksal/${dst_file_name}"
    mkdir -p "$(dirname "$destination_file_path")"
    cp "$source_file_path" "$destination_file_path"
    display_info "Copied file from ${COLOR_INFO_H}${src_file_name}${COLOR_INFO} to ${COLOR_INFO_H}${dst_file_name}${COLOR_INFO}"
}

function append_file() {
    local src_file_name=$1
    local dst_file_name=$2
    local source_file_path="${docksal_example_dir}${src_file_name}"
    local destination_file_path=".docksal/${dst_file_name}"
    cat "$source_file_path" >>"$destination_file_path"
    echo "" >>"$destination_file_path"
    display_info "Added file from ${COLOR_INFO_H}${src_file_name}${COLOR_INFO} to ${COLOR_INFO_H}${dst_file_name}${COLOR_INFO}"
}
function replace_in_file() {
    local file_path=".docksal/$1"
    local text_from="$2"
    local text_to="$3"
    if [[ ! -f $file_path ]]; then
        touch $file_path
    fi
    sed -i '' -e "s/"$text_from"/"$text_to"/g" $file_path
    display_info "Replaced in file ${COLOR_INFO_H}${file_path}${COLOR_INFO} from ${COLOR_INFO_H}${text_from}${COLOR_INFO} to ${COLOR_INFO_H}${text_to}${COLOR_INFO}"
}

# VALIDATE
is_system_ok=true
for cmd in "${required_programs[@]}"; do
    if ! hash "$cmd" 2>/dev/null; then
        is_system_ok=false
    fi
done
if [[ "$is_system_ok" == "false" ]]; then
    display_error "Please install missing programs"
    for cmd in "${required_programs[@]}"; do
        if ! hash "$cmd" 2>/dev/null; then
            display_info "$DISPLAY_LINE_PREPEND_TAB" "%s" "$cmd"
            is_system_ok=false
        fi
    done
    exit
fi

# CONFIG
docksal_example_dir="$(realpath $(dirname "$_bash_source")/_blueprint/)/"
_project_name="example_$(date "+%Y%m%d_%H%M%S")"
_application_stack="custom"
_application_stacks="custom php php-nodb node boilerplate"
_db_import="yes"
_db_backup_mode="no"
_java_version="no"
_java_versions="no 8"
_www_docroot="web"
_symfony_config="no"
_drupal_config="no"
_drupal_config_backup_restore="no"
_drupal_files_backup_restore="no"
_wordpress_config="no"
_wordpress_uploads_backup_restore="no"

# VARIABLES
display_header "Configure ${COLOR_LOG_H}project${COLOR_LOG} properties"
prompt_variable_not_null project_name "Project name (lowercase alphanumeric, underscore, and hyphen)" "$_project_name" 1 "$@"
_domain_name=${project_name}
if [[ "$project_name" == "." ]]; then
    confirm_or_exit "Really want to configure Docksal in ${COLOR_QUESTION_B}$(pwd)${COLOR_QUESTION} directory?"
    _domain_name="$(basename $(pwd))"
fi
if [[ "$(printf "%s/" $(pwd) | grep "/Desktop/")" ]]; then
    display_error "Please do not create Docker projects on DESKTOP, because it may cause mounting problems."
    exit 2
fi
_domain_name=$(echo "$_domain_name" | sed 's/_/-/g')
prompt_variable_not domain_name "Domain name (without .docksal.site tld, avoid underscore)" "$_domain_name" "." 2 "$@"
domain_name=$(echo "$domain_name" | sed 's/_/-/g')
domain_name="${domain_name}.docksal.site"
domain_url="http://${domain_name}"

display_info "Configure application containers (read more on ${COLOR_INFO_H}https://docs.docksal.io/stack/images-versions/${COLOR_INFO})"
prompt_variable_fixed application_stack "Application stack" "$_application_stack" "$_application_stacks" 3 "$@"
if [[ "$application_stack" == "node" ]]; then
    _db_version="no"
fi

if [[ "$application_stack" == "boilerplate" ]]; then
    display_header "fin project create"
    fin project create
    exit
else
    _http_server_versions=""
    _php_versions=""
    _db_versions=""
    _nodejs_versions=""
    while true; do
        display_line ""
        display_header "Define ${COLOR_LOG_H}containers${COLOR_LOG} configuration"
        http_server_version="no"
        if [[ "$application_stack" == "custom" || "$application_stack" == "php" || "$application_stack" == "php-nodb" ]]; then
            display_info "Configure ${COLOR_INFO_H}web${COLOR_INFO} container"
            if [[ "$_http_server_versions" == "" ]]; then
                display_log "Fetch Docksal web images versions from registry (read more on ${COLOR_LOG_H}https://hub.docker.com/r/docksal/web/${COLOR_LOG})"
                _apache_versions_arr=($(get_docker_registry_versions docksal/apache docksal/))
                _nginx_versions_arr=($(get_docker_registry_versions docksal/nginx docksal/))
                _http_server_version="${_apache_versions_arr[${#_apache_versions_arr[@]} - 1]}"
                _http_server_versions="no ${_apache_versions_arr[@]} ${_nginx_versions_arr[@]}"
            fi
            prompt_variable_fixed http_server_version "HTTP server version" "$_http_server_version" "$_http_server_versions"
        fi
        php_version="no"
        if [[ "$application_stack" == "custom" || "$application_stack" == "php" || "$application_stack" == "php-nodb" ]]; then
            display_info "Configure ${COLOR_INFO_H}PHP${COLOR_INFO} version on ${COLOR_INFO_H}cli${COLOR_INFO} container"
            if [[ "$_php_versions" == "" ]]; then
                display_log "Fetch Docksal cli images versions from registry (read more on ${COLOR_LOG_H}https://hub.docker.com/r/docksal/cli/${COLOR_LOG})"
                _php_versions_arr=($(get_docker_registry_versions docksal/cli docksal/cli:))
                _php_version="${_php_versions_arr[${#_php_versions_arr[@]} - 1]}"
                _php_versions="no ${_php_versions_arr[@]}"

            fi
            prompt_variable_fixed php_version "PHP version" "$_php_version" "$_php_versions"
        fi
        nodejs_version="no"
        if [[ "$application_stack" == "custom" || "$application_stack" == "php" || "$application_stack" == "php-nodb" || "$application_stack" == "node" ]]; then
            display_info "Configure ${COLOR_INFO_H}Node.js${COLOR_INFO} version on ${COLOR_INFO_H}cli${COLOR_INFO} container"
            if [[ "$_nodejs_versions" == "" ]]; then
                display_log "Fetch Node.js versions from registry (read more on ${COLOR_LOG_H}https://nodejs.org/en/download/releases/${COLOR_LOG})"
                _nodejs_versions_arr=($(get_nodejs_versions))
                _nodejs_version="${_nodejs_versions_arr[0]}"
                _nodejs_versions="${_nodejs_versions_arr[@]}"
            fi
            prompt_variable_fixed nodejs_version "Node version" "$_nodejs_version" "$_nodejs_versions"
        fi
        java_version="no"
        if [[ "$application_stack" == "custom" || "$application_stack" == "php" || "$application_stack" == "php-nodb" || "$application_stack" == "node" ]]; then
            display_info "Configure ${COLOR_INFO_H}JAVA${COLOR_INFO} version on ${COLOR_INFO_H}cli${COLOR_INFO} container"
            prompt_variable_fixed java_version "JAVA version" "$_java_version" "$_java_versions"
        fi
        prompt_variable www_docroot "WWW docroot (place where will be index file)" "$_www_docroot"
        db_version="no"
        db_import="no"
        if [[ "$application_stack" == "custom" || "$application_stack" == "php" || "$application_stack" == "node" ]]; then
            display_info "Configure ${COLOR_INFO_H}db${COLOR_INFO} container"
            if [[ "$_db_versions" == "" ]]; then
                display_log "Fetch Docksal db images versions from registry (read more on ${COLOR_LOG_H}https://hub.docker.com/r/docksal/db/${COLOR_LOG})"
                _mysql_versions_arr=($(get_docker_registry_versions docksal/mysql docksal/))
                _mariadb_versions_arr=($(get_docker_registry_versions docksal/mariadb docksal/))
                _db_version="mariadb:10.5"
                _db_versions="no ${_mysql_versions_arr[@]} ${_mariadb_versions_arr[@]}"
            fi
            prompt_variable_fixed db_version "DB version" "$_db_version" "$_db_versions"
        fi
        docksal_stack=""
        if [[ "$http_server_version" != "no" && "$php_version" != "no" && "$db_version" != "no" ]]; then
            docksal_stack="default"
        elif [[ "$http_server_version" != "no" && "$php_version" != "no" && "$db_version" == "no" ]]; then
            docksal_stack="default-nodb"
        elif [[ "$http_server_version" == "no" && "$php_version" == "no" && "$db_version" == "no" && "$nodejs_version" != "no" ]]; then
            docksal_stack="node"
        fi
        if [[ "$docksal_stack" == "" ]]; then
            _http_server_version="$http_server_version"
            _php_version="$php_version"
            _nodejs_version="$nodejs_version"
            _java_version="$java_version"
            _db_version="$db_version"
            set -- "${@:1:2}"
            display_error "Docksal stack not set. Please fix versions!"
            display_info "Possible configurations: ${COLOR_INFO_H}Apache+PHP+MySQL${COLOR_INFO} or ${COLOR_INFO_H}Apache+PHP+Node+MySQL${COLOR_INFO} or ${COLOR_INFO_H}Apache+PHP+Node${COLOR_INFO} or ${COLOR_INFO_H}Node${COLOR_INFO}."
        else
            display_info "Docksal stack set to ${COLOR_INFO_H}$docksal_stack${COLOR_INFO}."
            break
        fi
    done

    if [[ "$php_version" != "no" ]]; then
        display_line ""
        display_header "Enable ${COLOR_LOG_H}PHP addons${COLOR_LOG}"
        prompt_variable_fixed symfony_config "Init example Symfony Framework configuration and commands?" "$_symfony_config" "yes no"
        prompt_variable_fixed drupal_config "Init example Docksal Drupal configuration and commands?" "$_drupal_config" "yes no"
        if [[ "$drupal_config" == "yes" ]]; then
            prompt_variable_fixed drupal_config_backup_restore "Add Docksal commands for Drupal config backup and restore?" "$_drupal_config_backup_restore" "yes no"
            prompt_variable_fixed drupal_files_backup_restore "Add Docksal commands for Drupal files backup and restore?" "$_drupal_files_backup_restore" "yes no"
        fi
        prompt_variable_fixed wordpress_config "Init example Wordpress configuration?" "$_wordpress_config" "yes no"
        if [[ "$wordpress_config" == "yes" ]]; then
            prompt_variable_fixed wordpress_uploads_backup_restore "Add Docksal commands for Wordpress uploads backup and restore?" "$_wordpress_uploads_backup_restore" "yes no"
        fi
    else
        symfony_config="no"
        drupal_config="no"
        wordpress_config="no"
    fi
    if [[ "$db_version" != "no" ]]; then
        display_line ""
        display_header "Enable ${COLOR_LOG_H}DB addons${COLOR_LOG}"
        prompt_variable_fixed db_import "Create default database file" "$_db_import" "yes no"
        prompt_variable_fixed db_backup_mode "Choose mysqldump method: connect via 'ssh' to remote host, execute mysqldump and scp to local; execute mysqldump via 'fin' on remote database and save as local file; dump directly on remote and share as 'http' deep link?" "$_db_backup_mode" "ssh fin http no"
    else
        db_import="no"
        db_backup_mode="skip"
    fi
fi
# PROGRAM
confirm_or_exit "Save above options as Docksal configuration?"

if [[ "$project_name" != "." ]]; then
    display_info "Create ${COLOR_INFO_H}$project_name${COLOR_INFO} project directory"
    mkdir -p "$project_name"
    cd "$project_name"
else
    project_name="$(basename $(pwd))"
fi
project_path=$(realpath .)
(
    trap "rm -rf \"$project_path\"/.docksal/;exit 2" SIGINT
    (
        if [[ -d .docksal ]]; then
            display_error "Docksal configuration already exists! We need to remove it first."
            confirm_or_exit "Continue?"
            fin project remove -f
            rm -rf .docksal
        fi
    )
    (
        display_header "Create basic configuration"
        fin config generate --docroot="$www_docroot" --stack=${docksal_stack}
        (
            copy_file "docksal.gitignore" ".gitignore"
            copy_file "docroot.gitignore" "../$www_docroot/.gitignore"
        )
        (
            display_info "Set ${COLOR_INFO_H}${domain_name}${COLOR_INFO} as hostname"
            fin config set VIRTUAL_HOST="${domain_name}"
        )
        (
            display_info "Setup web image ${COLOR_INFO_H}${docksal_web_image}${COLOR_INFO}"
            docksal_web_image="docksal/${http_server_version}"
            fin config set WEB_IMAGE="$docksal_web_image"
        )
        (
            display_info "Setup cli image ${COLOR_INFO_H}${docksal_cli_image}${COLOR_INFO}"
            docksal_cli_image="docksal/cli:${php_version}"
            fin config set CLI_IMAGE="$docksal_cli_image"
        )
        (
            if [[ "$nodejs_version" != "no" ]]; then
                display_info "Installed ${COLOR_INFO_H}.nvmrc${COLOR_INFO} file. Read more on ${COLOR_INFO_H}https://github.com/creationix/nvm#nvmrc"
                echo ${nodejs_version} >.nvmrc
            fi
        )
        (
            if [[ "$db_version" != "no" ]]; then
                display_info "Setup db image ${COLOR_INFO_H}${docksal_db_image}${COLOR_INFO}"
                docksal_db_image="docksal/${db_version}"
                fin config set DB_IMAGE="$docksal_db_image"
            fi
        )
        (
            if [[ "$db_import" == "yes" || "$java_version" != "no" ]]; then
                echo "services:" >>.docksal/docksal.yml
            fi
        )
    )

    (
        display_header "Add custom commands"
        copy_file "commands/init"
        append_file "commands/init-step-reset-up" "commands/init"
        if [[ "$nodejs_version" != "no" ]]; then
            append_file "commands/node/init" "commands/init"
        fi
        append_file "commands/init-step-ssl" "commands/init"
        append_file "commands/init-step-prepare-site" "commands/init"
        copy_file "commands/_base.sh"
        copy_file "commands/prepare-site"
        if [[ "$db_backup_mode" != "no" ]]; then
            copy_file "commands/data/backup-data" "commands/backup-data"
            copy_file "commands/data/download-data" "commands/download-data"
            copy_file "commands/data/restore-data" "commands/restore-data"
            if [[ "$db_backup_mode" == "http" ]] || [[ "$drupal_files_backup_restore" == "yes" ]] || [[ "$wordpress_uploads_backup_restore" == "yes" ]]; then
                copy_file "commands/data/share-data" "commands/share-data"
            fi
        fi
        if [[ "$nodejs_version" != "no" ]]; then
            copy_file "commands/node/gulp" "commands/gulp"
            copy_file "commands/node/npm" "commands/npm"
        fi
        if [[ "$symfony_config" != "no" ]]; then
            copy_file "commands/symfony/console2" "commands/console2"
            copy_file "commands/symfony/console" "commands/console"
        fi
        if [[ "$db_version" != "no" ]]; then
            if [[ "$db_backup_mode" == "http" ]]; then
                copy_file "commands/db/backup-db-via-http" "commands/backup-db-on-remote"
                copy_file "commands/db/share-db-via-http" "commands/share-db-on-remote"
                copy_file "commands/db/download-db-via-http" "commands/download-db-from-remote"
            elif [[ "$db_backup_mode" == "ssh" ]]; then
                copy_file "commands/db/backup-db-via-ssh" "commands/backup-db"
            elif [[ "$db_backup_mode" == "fin" ]]; then
                copy_file "commands/db/backup-db-via-docksal" "commands/backup-db"
            fi
            copy_file "commands/db/restore-db" "commands/restore-db"
            if [[ "$db_backup_mode" == "http" ]]; then
                append_file "commands/db/backup-data-on-remote" "commands/backup-data"
                append_file "commands/db/share-data-on-remote" "commands/share-data"
                append_file "commands/db/download-data-on-remote" "commands/download-data"
            elif [[ "$db_backup_mode" == "ssh" ]]; then
                append_file "commands/db/backup-data" "commands/backup-data"
            elif [[ "$db_backup_mode" == "fin" ]]; then
                append_file "commands/db/backup-data" "commands/backup-data"
            fi
            append_file "commands/db/restore-data" "commands/restore-data"
            if [[ "$db_backup_mode" != "no" ]]; then
                append_file "commands/db/_base" "commands/_base.sh"
                if [[ "$db_backup_mode" == "http" ]]; then
                    append_file "commands/db/_base-backup-via-http" "commands/_base.sh"
                fi
            fi
            (
                display_info "Create ${COLOR_INFO_H}.docksal/services/db/database/dump/${COLOR_INFO} directory"
                mkdir -p .docksal/services/db/database/dump/
                echo "services/db/database/dump/dump*.sql" >>.docksal/.gitignore
            )
        fi
        if [[ "$drupal_config" == "yes" ]]; then
            copy_file "commands/drupal/dru-admin" "commands/dru-admin"
            copy_file "services/cli/drupal/settings.local.php" "services/cli/settings.local.php"
            if [[ "$drupal_config_backup_restore" == "yes" ]]; then
                copy_file "commands/drupal/backup-dru-config" "commands/backup-dru-config"
                copy_file "commands/drupal/restore-dru-config" "commands/restore-dru-config"
            fi
            if [[ "$drupal_files_backup_restore" == "yes" ]]; then
                copy_file "commands/drupal/backup-dru-files" "commands/backup-dru-files"
                copy_file "commands/drupal/share-dru-files" "commands/share-dru-files"
                copy_file "commands/drupal/download-dru-files" "commands/download-dru-files"
                copy_file "commands/drupal/restore-dru-files" "commands/restore-dru-files"
                append_file "commands/drupal/backup-data" "commands/backup-data"
                append_file "commands/drupal/share-data" "commands/share-data"
                append_file "commands/drupal/download-data" "commands/download-data"
                append_file "commands/drupal/restore-data" "commands/restore-data"
                append_file "commands/drupal/_base" "commands/_base.sh"
                (
                    display_info "Create ${COLOR_INFO_H}.docksal/services/cli/files/${COLOR_INFO} directory"
                    mkdir -p .docksal/services/cli/files/
                    echo "services/cli/files/files*.zip" >>.docksal/.gitignore
                )
            fi
        fi
        if [[ "$wordpress_config" == "yes" ]]; then
            copy_file "services/cli/wordpress/wp-config.php" "services/cli/wp-config.php"
            if [[ "$wordpress_uploads_backup_restore" == "yes" ]]; then
                copy_file "commands/wordpress/backup-wp-uploads" "commands/backup-wp-uploads"
                copy_file "commands/wordpress/share-wp-uploads" "commands/share-wp-uploads"
                copy_file "commands/wordpress/download-wp-uploads" "commands/download-wp-uploads"
                copy_file "commands/wordpress/restore-wp-uploads" "commands/restore-wp-uploads"
                append_file "commands/wordpress/backup-data" "commands/backup-data"
                append_file "commands/wordpress/share-data" "commands/share-data"
                append_file "commands/wordpress/download-data" "commands/download-data"
                append_file "commands/wordpress/restore-data" "commands/restore-data"
                append_file "commands/wordpress/_base" "commands/_base.sh"
                (
                    display_info "Create ${COLOR_INFO_H}.docksal/services/cli/uploads/${COLOR_INFO} directory"
                    mkdir -p .docksal/services/cli/uploads/
                    echo "services/cli/uploads/uploads*.zip" >>.docksal/.gitignore
                )
            fi
        fi
        if [[ "$nodejs_version" != "no" ]]; then
            append_file "commands/node/prepare-site" "commands/prepare-site"
        fi
        if [[ "$symfony_config" != "no" ]]; then
            append_file "commands/symfony/prepare-site" "commands/prepare-site"
        fi
        if [[ "$drupal_config" == "yes" ]]; then
            append_file "commands/drupal/prepare-site" "commands/prepare-site"
        fi
        if [[ "$wordpress_config" == "yes" ]]; then
            append_file "commands/wordpress/prepare-site" "commands/prepare-site"
        fi
    )
    (
        display_header "Prepare custom config"
        if [[ "$db_import" == "yes" ]]; then
            display_info "Import custom db into ${COLOR_INFO_H}db${COLOR_INFO} container"
            copy_file "services/db/database/init/init-example.sql"
            cat ${docksal_example_dir}docksal.yml/db-custom-data.yml >>.docksal/docksal.yml
            (
                display_info "Create ${COLOR_INFO_H}.docksal/services/db/database/init/${COLOR_INFO} directory"
                mkdir -p .docksal/services/db/database/init/
                echo "services/db/database/init/init*.sql" >>.docksal/.gitignore
            )
        fi
        if [[ "$java_version" != "no" ]]; then
            display_info "Add ${COLOR_INFO_H}JAVA${COLOR_INFO} to ${COLOR_INFO_H}cli${COLOR_INFO} container"
            mkdir -p .docksal/services/cli/
            copy_file "services/cli/Dockerfile-with-java" "services/cli/Dockerfile"
            replace_in_file .docksal/services/cli/Dockerfile "FROM \(.*\)" "FROM $(echo "$docksal_cli_image" | sed 's/\//\\\//g')"
            cat ${docksal_example_dir}docksal.yml/cli-with-java.yml >>.docksal/docksal.yml
        fi
        if [[ "$symfony_config" != "no" ]]; then
            display_info "Add ${COLOR_INFO_H}Symfony parameters${COLOR_INFO} to ${COLOR_INFO_H}cli${COLOR_INFO} container"
            mkdir -p .docksal/services/cli/
            copy_file "services/cli/symfony/parameters.yaml" "services/cli/parameters.yaml"
            (
                symfony_secret=$(date +%s%N | shasum | base64 | head -c 32)
                replace_in_file .docksal/services/cli/parameters.yaml "random_secret_string" "${symfony_secret}"
            )
            (
                symfony_base_url=$(printf ${domain_url} | sed 's:/:\\/:g')
                replace_in_file .docksal/services/cli/parameters.yaml "example_domain_name" "${symfony_base_url}"
            )
            copy_file "services/cli/symfony/docksal.htaccess" "../${www_docroot}/.htaccess.docksal"
            copy_file "services/cli/symfony/app_docksal.php" "../${www_docroot}/app_docksal.php"
        fi
    )
    (
        display_header "Prepare readme file"
        append_file "readme/docksal-setup.md" "../README.md"
        append_file "readme/docksal-setup-project.md" "../README.md"
        if [[ "$nodejs_version" != "no" ]]; then
            append_file "readme/docksal-setup-node.md" "../README.md"
        fi
        append_file "readme/docksal-setup-docksal.md" "../README.md"
        append_file "readme/docksal-setup-init.md" "../README.md"
        append_file "readme/docksal-how-to.md" "../README.md"
        if [[ "$db_version" != "no" ]]; then
            if [[ "$db_backup_mode" == "ssh" ]]; then
                append_file "readme/docksal-how-to-db-via-ssh.md" "../README.md"
            elif [[ "$db_backup_mode" == "http" ]]; then
                append_file "readme/docksal-how-to-db-via-http.md" "../README.md"
            elif [[ "$db_backup_mode" == "fin" ]]; then
                append_file "readme/docksal-how-to-db-via-fin.md" "../README.md"
            fi
        fi
        if [[ "$nodejs_version" != "no" ]]; then
            append_file "readme/docksal-how-to-node.md" "../README.md"
        fi
        if [[ "$symfony_config" != "no" ]]; then
            append_file "readme/docksal-how-to-symfony.md" "../README.md"
        fi
        if [[ "$drupal_config" == "yes" ]]; then
            append_file "readme/docksal-how-to-drupal.md" "../README.md"
            if [[ "$drupal_files_backup_restore" == "yes" ]]; then
                append_file "readme/docksal-how-to-drupal-files.md" "../README.md"
            fi
        fi
        if [[ "$wordpress_config" == "yes" ]]; then
            append_file "readme/docksal-how-to-wordpress.md" "../README.md"
            if [[ "$wordpress_uploads_backup_restore" == "yes" ]]; then
                append_file "readme/docksal-how-to-wordpress-uploads.md" "../README.md"
            fi
        fi
        replace_in_file '../README.md' 'PROJECT_NAME' "$(printf ${project_name} | sed 's:/:\\/:g')"
        replace_in_file '../README.md' 'VIRTUAL_HOST' "$(printf ${domain_url} | sed 's:/:\\/:g')"
    )
    display_success "Docksal configuration is ready."
    trap - SIGINT
)

if [[ $(type "git" 2>/dev/null) ]]; then
    confirm_or_exit "Save Docksal configuration to git?"
    if [[ ! -d .git ]]; then
        git init
    fi
    git add .
    git commit -m "Docksal configuration initialize"
fi

confirm_or_exit "Initialize Docker project?" "You can init project manually with ${COLOR_INFO_H}fin init${COLOR_INFO} command in ${COLOR_INFO_H}${project_path}${COLOR_INFO} directory."

display_info "Initialize Docker project (executing ${COLOR_INFO_H}fin init${COLOR_INFO} command in ${COLOR_INFO_H}${project_path}${COLOR_INFO} directory.)"
if [[ $(type "yes") ]]; then
    yes | fin init
else
    fin init
fi
color_reset

print_new_line
