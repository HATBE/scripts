#!/bin/bash

#################################################################################
# Scriptname:       db-manager.sh
# Version:          1.0
# Language:         Bash 5.0.17(1)-release
# Description:      This script manages databases in docker containers
#
# Creator:          Aaron Gensetter
# Creation date:    30.03.2022
# Maintainers:      [Aaron Gensetter (a.g) 30.03.22 - now]
# Email:            admin@hatbe.ch
#
# Last change:      05.03.2022
#################################################################################

#################################################################################
# VARS
#################################################################################

# INFO: don't change any variable (if you're not 100% sure you know what you're doing!!!)

readonly PREFIX='dcms' # use lower case
readonly APP_NAME='dcms' # use lower case
readonly APP_VERSION='1.0'

# folders and files
readonly APP_FOLDER="/var/${APP_NAME}"
readonly BACKUP_FOLDER="${APP_FOLDER}/backups/"
readonly CONTAINER_BACKUP_FOLDER='/var/backups/'

# APT packages that must be installed, else, installation
readonly DEPENDENCIES=('jq' 'zip' 'unzip')

# set script killer apt package dependencies
readonly KILLER_DEPENDENCIES=('containerd.io' 'docker-ce' 'docker-ce-cli')

# JSON with the allowed tags (hard-coded to ensure hard- and software compatibility); last updated (30.03.2022)
readonly ALLOWED_TAGS='{"images":{"mongo":["4.0","3.0"],"mysql":["8","5","5.7","5.6"],"mariadb":["10.7","10.6","10.5","10.4","10.3","10.2"],"postgres":["14","13","12","11","10","9"]}}'

# names that are forbidden to use
readonly FORBIDDEN_DB_NAMES=('mysql' 'mongo' 'sql' 'mongodb' 'postgres' 'postgresql' 'mariadb' 'information_schema' 'performance_schema' 'schema' 'test' 'root' 'system' 'database' 'table' 'collection')

# usernames that are forbidden to use
readonly FORBIDDEN_USERNAMES=('mysql' 'root' 'admin')

readonly SCRIPT_NAME=$0
readonly SCRIPT_ARGS=${@}
SCRIPT_NAME_AGRS=$SCRIPT_NAME
[[ ${#@} -ge 1 ]] && SCRIPT_NAME_AGRS+=" ${SCRIPT_ARGS}" # add args if given
readonly INIT_DIR=$(pwd)

readonly LOCAL_IP=$(ip route get 8.8.8.8 | grep -oP 'src \K[^ ]+') # get local ip
readonly DASHED_LOCAL_IP=$(echo $LOCAL_IP | tr "." "-") # replace dots with dashes in ip

# format codes
readonly F_R=$(tput setaf 1) # red font color
readonly F_G=$(tput setaf 2) # green font color
readonly F_Y=$(tput setaf 3) # yellow font color
readonly F_B=$(tput setaf 4) # blue font color
readonly F_C=$(tput setaf 6) # cyan font color
readonly F_X=$(tput sgr0) # reset format

# often used "buttns/texts"
readonly EXIT_TXT="${F_R}Exit${F_X}"
readonly BACK_TXT="${F_B}Back${F_X}"

SILENT=false

#################################################################################
# FUNCTIONS
#################################################################################

# function prins a text given in a argument with a preformat that is also given in an argument
function __pmsg() { # __pmsg <type> <text>
    local MODE=$1
    shift
    $SILENT && return
    case $MODE in
        'error') echo "${F_R}[Error]:${F_X} ${@}!" >&2;; # print error format msg and redirect to stderr
        'success') echo "${F_G}[Success]:${F_X} ${@}.";; # print success format msg
        'info') echo "${F_B}[Info]:${F_X} ${@}.";; # print info format msg
        'warn') echo "${F_Y}[Warning]:${F_X} ${@}!";; # print warning format msg
        *) echo ${@};; # if type not known, just pring msg without format
    esac
}

# prints a standardized spacer
function __printSpacer() {
    echo '--------------------------------'
}

# prnit a "screen" header
function __printHeader() { # __printHeader <title> <text>
    clear
    echo "${F_B}[${F_C}${APP_NAME^^}${F_B}] - ${F_C}${1}${F_X} - ${F_B}${2}${F_X}"
    __printSpacer
}

# check for essential needed packages, if not installed, exit script
function __checkForKillerDependencies() {
    for DEPENDENCY in ${KILLER_DEPENDENCIES[@]}; do
        dpkg -s $DEPENDENCY &> /dev/null # search for dependency
         if [[ $? -ne 0 ]]; then
            __pmsg 'error' "\"${DEPENDENCY}\" was not found, please install it manually or contact an admin"
            exit 1
        fi
    done
}

# check for dependencies, if not installed, install it
function __checkForDependencies() {
    local COUNT=0
    __printHeader 'Dependencies check' 'Searching...'
    for DEPENDENCY in ${DEPENDENCIES[@]}; do
        dpkg -s $DEPENDENCY &> /dev/null # search for dependency
        if [[ $? -ne 0 ]]; then
            COUNT=$((COUNT+1))
            __pmsg 'warn' "\"${DEPENDENCY}\" not found"
            __pmsg 'info' "Installing \"${DEPENDENCY}\""
            apt install $DEPENDENCY -y &> /dev/null # install the missing package
            if [[ $? -ne 0 ]]; then
                __pmsg 'error' "Installation of \"${DEPENDENCY}\" failed"
                __pmsg 'info' 'try: sudo apt update'
                exit 1
            fi
            __pmsg 'success' "Installation of \"${DEPENDENCY}\" succeeded"
        fi
    done
    if [[ $COUNT -eq 0 ]]; then
        __pmsg 'success' 'Everithing up to date'
    else
        __pmsg 'success' "Installed \"${COUNT}\" packages"
    fi
    sleep 1 # wait, so user can read text
}

# exit script with non error
function __leaveScript() {
    clear
    __pmsg 'info' 'Leaving..'
    sleep 1 # wait, so user can read text
    clear
    exit 0
}

# give the user the choose between go back and exit the whole script
function __askBackOrExit() {
    echo
    read -p "${F_B}Back?${F_X} (y) / ${F_R}Exit?${F_X} (x): " YN
    [[ $YN =~ ^[xX]$ ]] && __leaveScript
}

# choose a random port in a standard given range, if its used, choose another one
function __getRandomUnusedPort() {
    local LOOP=true
    while $LOOP; do
        RAND_PORT=$(shuf -i 2000-65000 -n 1) # generate a random number between 2000 and 65000
        if ! [[ $(ss -tulpn | grep ":${RAND_PORT} " | wc -l) -ge 1 ]]; then
            LOOP=false
            continue
        fi
    done
}

#################################################################################
# program related functions

# initial function (called only once in the end)
function __init() {
    # check if the user has root privileges
    if [[ $UID -ne 0 ]]; then
        __pmsg 'error' 'You must be root to execute this script'
        __pmsg 'info' "Try with \"sudo ${SCRIPT_NAME_AGRS}\""
        exit 1
    fi

    clear

    # dependency check
    __checkForKillerDependencies
    __checkForDependencies

    # creata needed folders and files
    mkdir -p $BACKUP_FOLDER $BACKUP_FOLDER/tmp

    # go to init screen
    __screen0Init
}

# get the container image from container name
function __getDbImageFromName() { # __getDbImageFromName <name>
    IMAGE=$(cut -d '-' -f2 <<< $1)
}

# get the container tag from container name
function __getDbTagFromName() { # __getDbTagFromName <name>
    TAG=$(cut -d '-' -f3 <<< $1)
}

# get the db name from contaner name
function __getDbNameFromName() { # __getDbNameFromName <name>
    NAME=$(cut -d '-' -f4 <<< $1)
}

# get a port from a container from container name
function __getContainerPortFromName() { # __getContainerPortFromName <name>
    PORT=$(docker container inspect $1 | grep 'HostPort' | sort | uniq | grep -Eo '[0-9]*')
}

# output details of a container
function __outputDatabaseDetails() {
    ID=$(docker container ls -aqf "name=${CONTAINER_NAME}") # get id of container

    __printHeader 'Info' "${CONTAINER_NAME}"

    # display all the infos about the container and database
    echo -e "Cotnainer name:\t${F_C}${CONTAINER_NAME}${F_X}"
    echo -e "Database name:\t${F_C}${NAME}${F_X}"
    echo -e "Container ID:\t${F_C}${ID}${F_X}"
	  echo -e "Image:\t\t${F_C}${IMAGE}:${TAG}${F_X}"
	  echo -e "Host:\t\t${F_C}${LOCAL_IP}${F_X}"
	  echo -e "Port:\t\t${F_C}${PORT}${F_X}"
}

# return a array of all running containers
__getListOfAllContainers() {
    local CONTAINERS=$(docker container ls | awk '{if(NR>1) print $NF}') # get all running contianers from the docker host
    CONTAINER_LST=()
    for CONTAINER_NAME in $CONTAINERS; do
        [[ $CONTAINER_NAME == $PREFIX* ]] && CONTAINER_LST+=( $CONTAINER_NAME ) # append container name to array, if the prefix isset
    done
}

# create a mysql db docker contianer
function __createMysqlContainer() {
    local LOCAL_PORT=3306
    local IMAGE='mysql'

    # create container
    docker container run \
        -d \
        --restart unless-stopped \
        --name $CONTAINER_NAME \
        -p $PORT:$LOCAL_PORT \
        -v $BACKUP_FOLDER:$CONTAINER_BACKUP_FOLDER \
        -e MYSQL_ROOT_PASSWORD=$PASSWORD \
        -e MYSQL_DATABASE=$NAME \
        -e MYSQL_USER=$USERNAME \
        -e MYSQL_PASSWORD=$PASSWORD \
        $IMAGE:$TAG \
        &> /dev/null
}

# create a mariadb docker container
function __createMariadbContainer() {
    local LOCAL_PORT=3306
    local IMAGE='mariadb'

    # create container
    docker container run \
        -d \
        --restart unless-stopped \
        --name $CONTAINER_NAME \
        -p $PORT:$LOCAL_PORT \
        -v $BACKUP_FOLDER:$CONTAINER_BACKUP_FOLDER \
        -e MARIADB_ROOT_PASSWORD=$PASSWORD \
        -e MARIADB_DATABASE=$NAME \
        -e MARIADB_USER=$USERNAME \
        -e MARIADB_PASSWORD=$PASSWORD \
        $IMAGE:$TAG \
        &> /dev/null
}

# create a postgres db docker container
function __createPostgresContainer() {
    local LOCAL_PORT=5432
    local IMAGE='postgres'

    # create container
    docker container run \
        -d \
        --restart unless-stopped \
        --name $CONTAINER_NAME \
        -p $PORT:$LOCAL_PORT \
        -v $BACKUP_FOLDER:$CONTAINER_BACKUP_FOLDER \
        -e POSTGRES_PASSWORD=$PASSWORD \
        -e POSTGRES_DB=$NAME \
        -e POSTGRES_USER=$USERNAME \
        $IMAGE:$TAG \
        &> /dev/null
}

# create a mongo db docker container
function __createMongoContainer() {
    local LOCAL_PORT=27017
    local IMAGE='mongo'

    # create container
    docker container run \
        -d \
        --restart unless-stopped \
        --name $CONTAINER_NAME \
        -p $PORT:$LOCAL_PORT \
        -v $BACKUP_FOLDER:$CONTAINER_BACKUP_FOLDER \
        -e MONGO_INITDB_DATABASE=$NAME \
        -e MONGO_INITDB_ROOT_USERNAME=$USERNAME \
        -e MONGO_INITDB_USERNAME=$USERNAME \
        -e MONGO_INITDB_ROOT_PASSWORD=$PASSWORD \
        $IMAGE:$TAG \
        &> /dev/null
}

# standardized function to get uname and pwd
function __getDbUsernameAndPassword() {
    # username
    read -p 'Enter the username of the database: ' USERNAME

    # password
    read -sp 'Enter the password of the database: ' PASSWORD; echo
}

# == export

# exports a mysql db from a docker container to a local file
function __exportMysql() { # __exportMysql <name>
    docker container exec $1 bash -c "mysqldump -u ${USERNAME} --password=${PASSWORD} $NAME --no-tablespaces > ${CONTAINER_FILE_PATH}.sql" &> /dev/null
}

# exports a mariadb db from a docker container to a local file
function __exportMariadb() { #__exportMariadb <name>
    docker container exec $1 bash -c "mysqldump -u ${USERNAME} --password=${PASSWORD} $NAME > ${CONTAINER_FILE_PATH}.sql" &> /dev/null
}

# exports a postgres db from a docker container to a local file
function __exportPostgres() { # __exportPostgres <name>
    docker container exec $1 bash -c "pg_dump -U ${USERNAME} ${NAME} > ${CONTAINER_FILE_PATH}.sql" &> /dev/null
}

# exports a mongo db from a docker container to a local file
function __exportMongo() { # __exportMongo <name>
    docker container exec $1 bash -c "mongodump --username ${USERNAME} --password ${PASSWORD} --authenticationDatabase admin --db ${NAME} --out ${CONTAINER_BACKUP_FOLDER}" &> /dev/null
}

# == import

# imports a database file to a mysql docker container
function __importMysql() { # __importMysql <name>
    docker container exec $1 bash -c "mysql -u ${USERNAME} -p${PASSWORD} ${NAME} < ${CONTAINER_BACKUP_FOLDER}${CHOOSEN_FILE}" &> /dev/null 
}

# imports a database file to a mariadb contianer
function __importMariadb() { # __importMariadb <name>
    docker container exec $1 bash -c "mysql -u ${USERNAME} -p${PASSWORD} ${NAME} < ${CONTAINER_BACKUP_FOLDER}${CHOOSEN_FILE}" &> /dev/null
}

# imports a database file to a postgres container
function __importPostgres() { # __importPostgres <name>
    docker container exec $1 bash -c "psql -U ${USERNAME} ${NAME} < ${CONTAINER_BACKUP_FOLDER}${CHOOSEN_FILE}" &> /dev/null
}

# imports a database file to a mongo container
function __importMongo() { # __importMongo <name>
    docker container exec $1 bash -c "mongorestore --username ${USERNAME} --password ${PASSWORD} --authenticationDatabase admin --db ${NAME} ${CONTAINER_BACKUP_FOLDER}${NAME}" &> /dev/null
}

# == rename

# rename database inside container
function __renameMysql() { # __renameMysql <name>
    CONTAINER_NAME="${PREFIX}-${IMAGE}-${TAG}-${NEW_NAME}"
    OLD_NAME=$NAME
    NAME=$NEW_NAME

    __getContainerPortFromName $1 # get port from old container
    docker container exec $1 bash -c "mysqldump -u ${USERNAME} --password=${PASSWORD} $OLD_NAME --no-tablespaces > ${CONTAINER_BACKUP_FOLDER}tmp/${OLD_NAME}.sql" &> /dev/null
    docker container rm -fv $1 &> /dev/null # delete container (force delete and delete volumes)
    __createMysqlContainer # create a new container with name
    __printHeader 'Renaming' 'loading...'
    sleep 25 # wait, until container is ready
    docker container exec $CONTAINER_NAME bash -c "mysql -u ${USERNAME} --password=${PASSWORD} ${NEW_NAME} < ${CONTAINER_BACKUP_FOLDER}tmp/${OLD_NAME}.sql" &> /dev/null
    rm ${BACKUP_FOLDER}tmp/${OLD_NAME}.sql  # delete exported file
}

# rename database inside container
function __renameMariadb() { # __renameMariadb <name>
    CONTAINER_NAME="${PREFIX}-${IMAGE}-${TAG}-${NEW_NAME}"
    OLD_NAME=$NAME
    NAME=$NEW_NAME

    __getContainerPortFromName $1 # get port from old container
    docker container exec $1 bash -c "mysqldump -u ${USERNAME} --password=${PASSWORD} $OLD_NAME > ${CONTAINER_BACKUP_FOLDER}tmp/${OLD_NAME}.sql" &> /dev/null

    docker container rm -fv $1 &> /dev/null # delete container (force delete and delete volumes)

    __createMysqlContainer # create a new container with name

    __printHeader 'Renaming' 'loading...'
    sleep 25 # wait, until container is ready
    docker container exec $CONTAINER_NAME bash -c "mysql -u ${USERNAME} --password=${PASSWORD} ${NEW_NAME} < ${CONTAINER_BACKUP_FOLDER}tmp/${OLD_NAME}.sql" &> /dev/null
    rm ${BACKUP_FOLDER}tmp/${OLD_NAME}.sql  # delete exported file
}

# rename database inside container
function __renamePostgres() { # __renamePostgres <name>
    docker container exec $1 bash -c "psql -U ${USERNAME} postgres -c 'ALTER DATABASE ${NAME} RENAME TO ${NEW_NAME}'" &> /dev/null # rename postgres db
    # Rename the contianer
    docker container rename $1 ${PREFIX}-${IMAGE}-${TAG}-${NEW_NAME}
}

# rename database inside container
function __renameMongo() { # __renameMongo <name>
    docker container exec $1 bash -c "mongodump --username=${USERNAME} --password=${PASSWORD} --authenticationDatabase admin --archive --db=${NAME} \
    | mongorestore --username=${USERNAME} --password=${PASSWORD} --authenticationDatabase admin --archive --nsFrom='${NAME}.*' --nsTo='${NEW_NAME}.*' \
    && mongo ${NAME} --username=${USERNAME} --password=${PASSWORD} --authenticationDatabase admin --eval 'db.dropDatabase()'" \
    &> /dev/null # dump db to stdout and import in new from stdout
    # Rename the contianer
    docker container rename $1 ${PREFIX}-${IMAGE}-${TAG}-${NEW_NAME}
}

#################################################################################
# SCREENS
#################################################################################

#################################################################################
# screen0 (default)

# let the user choose what he wants todo 
function __screen0Init() {
    __printHeader 'Init' 'Select an option'

    local COLUMNS=12 # limit select to one column
    select OPT in 'Create new' 'Settings' "${F_Y}About${F_X}" $EXIT_TXT; do
        case $OPT in
            'Create new') __screen1Init;;
            'Settings') __screen3Init;;
            "${F_Y}About${F_X}") __screen0About;;
            $EXIT_TXT) __leaveScript;;
            *) __pmsg 'error' 'try again';;
        esac
    done
}

# display a little about function
function __screen0About() {
    __printHeader 'About' ${APP_NAME^^}

    # https://patorjk.com/software/taag/#p=display&f=Slant&t=DCMS
    echo "${F_B}    ____  ________  ________${F_X}"
	  echo "${F_B}   / __ \/ ____/  |/  / ___/${F_X}"
	  echo "${F_B}  / / / / /   / /|_/ /\__ \ ${F_X}"
	  echo "${F_B} / /_/ / /___/ /  / /___/ / ${F_X}"
	  echo "${F_B}/_____/\____/_/  /_//____/  ${F_X}"
	  echo
	  echo "${F_B}Database Container Management System${F_X}"
	  echo
	  echo -e "Version:\t\t${F_C}${APP_VERSION}${F_X}"
	  echo -e "Original author:\t${F_C}Aaron Gensetter${F_X}"
	  echo -e "Creation date:\t\t${F_C}30.03.2022${F_X}"
	  echo -e "Maintainers:\t\t${F_C}[Aaron Gensetter]${F_X}"
	  echo -e "Email:\t\t\t${F_C}admin@hatbe.ch${F_X}"

    __askBackOrExit
    __screen0Init
}

#################################################################################
# screen1 (create new)

# display all the dbs a user can install with this script
function __screen1Init() {
    __printHeader 'Create' 'Select the type you want'

    __screen1PrepareAndInstall

    __outputDatabaseDetails
    __askBackOrExit
    __screen0Init
}

# get all data needed, install the container
function __screen1PrepareAndInstall() {
    local COLUMNS=12 # limit select to one column
    select OPT in 'mysql' 'mariadb' 'postgres' 'mongo' $BACK_TXT; do
        case $OPT in
            'mysql') __screen1Create 'mysql'; break;;
            'mariadb') __screen1Create 'mariadb'; break;;
            'postgres') __screen1Create 'postgres'; break;;
            'mongo') __screen1Create 'mongo'; break;;
            $BACK_TXT) __screen0Init;;
            *) __pmsg 'error' 'try again'; break;;
        esac
    done
}

# prepare the installation of a container
function __screen1Create() { # __screen1Create <image>
    __screen1ReadData $1

    __printHeader 'Create' "Installing \"${NAME}\""
    __pmsg 'info' "\"${IMAGE}:${TAG}\" - Preparing image.."

    case $1 in
        'mysql') __createMysqlContainer;;
        'mariadb') __createMariadbContainer;;
        'postgres') __createPostgresContainer;;
        'mongo') __createMongoContainer;;
        *) echo 'unexpected type error' && exit 1;;
    esac
}

# display all available tags for an image, let user decide which one he wants
function __screen1ReadTag() { # __screen1ReadTag <image>
    local TAGS=$(echo $ALLOWED_TAGS | jq -r ".images.${1} |. []") # filter all docker tags from the selected Image

    __printHeader 'Create' "Select a tag for \"${1}\""

    local COLUMNS=12 # limit select to one column
    select OPT in $BACK_TXT ${TAGS[@]}; do
        [[ $OPT == $BACK_TXT ]] && __screen0Init && return
        if [[ $OPT != '' ]]; then
            TAG=$OPT
            break
        else
            __pmsg 'error' 'try again'
        fi
    done
}

# read some data that is important to create a container
function __screen1ReadData() { # __screen1ReadData <image>
    __screen1ReadTag $1

    IMAGE=$1
    
    local COUNT=0
    local LOOP=true
    local RD='' # define round
    while $LOOP; do # if something is wrong, loop
        COUNT=$((COUNT+1))

        [[ $COUNT -ge 2 ]] && RD="${F_R}[${COUNT}] ${F_X}" && sleep 1 # if something went wrong in the last try, add text to the round var
        __printHeader 'Create' 'Please enter the data for the database'
        [[ $COUNT -ge 2 ]] && __pmsg 'error' 'Something went wrong: try again' && echo # inform the user that there was an error before

        # name
        read -p "${RD}Enter a name: " NAME
        [[ ! $NAME =~ ^[a-zA-Z0-9_]{2,32}$ ]] && __pmsg 'error' 'This name is not valid' && continue  # check if string is in the right format for the docker containers
        for F_NAME in ${FORBIDDEN_DB_NAMES[@]}; do [[ $F_NAME == ${NAME,,} ]] && __pmsg 'error' 'This name is not allowed' && continue 2; done # check if he provided name is forbidden
        [[ $(docker container ls -aqf "name=${PREFIX}-${IMAGE}-${TAG}-${NAME}" | wc -l) -ne 0 ]] && __pmsg 'error' 'A container with this name already exists' && continue  # check if containername already exists

        # port
        read -p "${RD}Enter a port [auto]: " PORT
        [[ $PORT == 'auto' || $PORT == '' ]] && __getRandomUnusedPort && PORT=$RAND_PORT # if auto or empty, then get random port
        [[ ! $PORT =~ ^[0-9]{1,5}$ ]] && __pmsg 'error' 'Port is not valid' && continue # check if string is in the right format
        [[ $(ss -tulpn | grep ":${PORT} " | wc -l) -ge 1 ]] && __pmsg 'error' 'Port is already in use' && continue # check if system uses the Port
        [[ $PORT -lt 1 || $PORT -gt 65535 ]] && __pmsg 'error' 'Port is out of range (1-65535)' && continue # check if port is in a valid range

        # username
        read -p "${RD}Enter a username [DBAdmin]: "
        [[ $USERNAME == '' ]] && USERNAME='DBAdmin' # if empty, set standard
        [[ ! $USERNAME =~ ^[a-zA-Z0-9_-]{3,24}$ ]] && __pmsg 'error' 'Username not valid' && continue # check if the username is in the right format
        for F_USERNAME in ${FORBIDDEN_USERNAMES}; do [[ $F_USERNAME == ${USERNAME,,} ]] && __pmsg 'error' 'This username is not allowed' && continue 2; done # check if provided username is in the forbidden list
    
        # password
        read -sp "${RD}Enter a password: " PASSWORD; echo
        [[ $PASSWORD == '' ]] && __pmsg 'error' 'Password cant be empty' && continue # check if pw is empty

        # repeat password
        read -sp "${RD}Repeat password: " R_PASSWORD; echo
        [[ $PASSWORD != $R_PASSWORD ]] && __pmsg 'error' 'Passwords do not match' && continue # check if pws match
    
        CONTAINER_NAME="${PREFIX}-${IMAGE}-${TAG}-${NAME}"
        LOOP=false
    done
}

#################################################################################
# screen3 (settings)

# show available dbs to alter
function __screen3Init() {
    __getListOfAllContainers

    __printHeader 'Settings' 'Select a database'

    if [[ ${#CONTAINER_LST[@]} -eq 0 ]]; then
        __pmsg 'warn' 'No containers found'
        __askBackOrExit
        __screen0Init
        return
    fi

    local COLUMNS=12 # limit select to one column
    select OPT in $BACK_TXT ${CONTAINER_LST[@]}; do
        [[ $OPT == '' ]] && __pmsg 'error' 'try again'
        [[ $OPT == $BACK_TXT ]] && __screen0Init && return
        __screen3Settings $OPT
    done
}

# show available settings for a docker container / db
function __screen3Settings() { # __screen3Settings <containername>
    __printHeader 'Settings' $1

    local COLUMNS=12 # limit select to one column
    select OPT in "${F_C}Infos${F_X}" 'Rename' 'Export' 'Import' "${F_R}Delete${F_X}" $BACK_TXT; do
        case $OPT in
            "${F_C}Infos${F_X}") __screen3Info $1;;
            'Rename') __screen3Rename $1;;
            'Export') __screen3Export $1;;
            'Import') __screen3Import $1;;
            "${F_R}Delete${F_X}") __screen3Delete $1;;
            $BACK_TXT) __screen3Init;;
            *) __pmsg 'error' 'try again';;
        esac
    done
}

# display infos about a db / docker contianer
function __screen3Info() { # __screen3Info <name>
    __getDbImageFromName $1
    __getDbNameFromName $1
    __getDbTagFromName $1
    __getContainerPortFromName $1

    __outputDatabaseDetails

    __askBackOrExit
    __screen3Settings $1
}

# rename a db inside a docker contaienr
function __screen3Rename() { # __screen3Rename <name>
    __getDbTagFromName $1
    __getDbNameFromName $1
    __getDbImageFromName $1

    __printHeader 'Rename' $1

    __getDbUsernameAndPassword

    local LOOP=true
    while $LOOP; do # if something is wrong, loop
        read -p 'Please enter the new name: ' NEW_NAME
        [[ ! $NEW_NAME =~ ^[a-zA-Z0-9_]{2,32}$ ]] && __pmsg 'error' 'This name is not valid' && continue  # check if string is in the right format for the docker containers
        for F_NAME in ${FORBIDDEN_DB_NAMES[@]}; do [[ $F_NAME == ${NEW_NAME,,} ]] && __pmsg 'error' 'This name is not allowed' && continue 2; done # check if he provided name is forbidden
        [[ $(docker container ls -aqf "name=${PREFIX}-${IMAGE}-${TAG}-${NEW_NAME}" | wc -l) -ne 0 ]] && __pmsg 'error' 'A container with this name already exists' && continue  # check if containername already exists
        LOOP=false
    done

    case $IMAGE in
        'mysql') __renameMysql $1;;
        'mariadb') __renameMariadb $1;;
        'postgres') __renamePostgres $1;;
        'mongo') __renameMongo $1;;
        *) echo 'unexpected type error' && exit 1;;
    esac

    if [[ $? -ne 0 ]]; then
        __pmsg 'error' 'Something went wrong in the renaming process'
        exit 1
    fi

    __pmsg 'success' 'Successfully renamed Database'

    __askBackOrExit
    __screen3Settings $1
}

# export a db from a docker container
function __screen3Export() { # __screen3Export <name>
    __printHeader 'Export' $1

    __getDbTagFromName $1
    __getDbNameFromName $1
    __getDbImageFromName $1

    DATE=$(date +%Y_%m_%d__%H_%M_%S_%N)
    FILE="${PREFIX}-${IMAGE}-${TAG}-${NAME}-${DASHED_LOCAL_IP}-${DATE}"
    BACKUP_FILE_PATH="${BACKUP_FOLDER}${FILE}"
    CONTAINER_FILE_PATH="${CONTAINER_BACKUP_FOLDER}${FILE}"

    __getDbUsernameAndPassword

    __printHeader 'Export' 'Dumping...'

    case $IMAGE in
        'mysql') __exportMysql $1;;
        'mariadb') __exportMariadb $1;;
        'postgres') __exportPostgres $1;;
        'mongo') __exportMongo $1;;
        *) echo 'unexpected type error' && exit 1;;
    esac

    if [[ $? -ne 0 ]]; then
        # if the dump failed
        # if not mongo
        [[ $IMAGE != 'mongo' && -f "${BACKUP_FILE_PATH}.sql" ]] && rm "${BACKUP_FILE_PATH}.sql"
        # if mongo
        [[ $IMAGE == 'mongo' && -d "${BACKUP_FOLDER}${NAME}" ]] && rm -R "${BACKUP_FOLDER}${NAME}"
        
        __pmsg 'error' 'There was an error while dumping the database'
        __pmsg 'info' 'Please check the username and password compination'
    
        __askBackOrExit
        __screen3Settings $1
    fi

    cd $BACKUP_FOLDER

    # zip dbs
    if [[ $IMAGE == 'mongo' ]]; then
        zip --password $PASSWORD -r "${FILE}.zip" "${NAME}" &> /dev/null
        rm -R "${NAME}"
    else
        zip --password $PASSWORD -r "${FILE}.zip" "${FILE}.sql" &> /dev/null
        rm "${FILE}.sql"
    fi

    __printHeader 'Export' 'Success'
    __pmsg 'success' "Export of \"${F_C}${1}${F_X}\" was successfull"
    __pmsg 'info' "File location: \"${F_B}${BACKUP_FOLDER}${F_C}${FILE}.zip${F_X}\""
    __pmsg 'info' 'The password of the ZIP file is the DB password'

    __askBackOrExit
    __screen3Init
}

function __screen3Import() { # __screen3Import <name>
    __getDbNameFromName $1
    __getDbImageFromName $1

    __printHeader 'Import' $1

    __pmsg 'info' "The standard path is \"${BACKUP_FOLDER}\""

    local LOOP=true
    while $LOOP; do # if something is wrong, loop
        read -p "Enter the folder path in which the file is [auto]: " PATH_TO_FILE
        [[ $PATH_TO_FILE == '' ]] && PATH_TO_FILE=$BACKUP_FOLDER
        [[ ! -d $PATH_TO_FILE ]] && __pmsg 'error' 'This directory does not exist' && __printSpacer && continue

        LOOP=false
    done

    FILES_IN_FOLDER=$(ls -p $PATH_TO_FILE | grep -v '/' ) # get a list of all files in the selected folder
    CHOOSEN_FILE=''

    local COLUMNS=12 # limit select to one column
    select OPT in $FILES_IN_FOLDER; do
       CHOOSEN_FILE=$OPT
       break
    done

    # if file is a zip file, unzip it
    if [[ $CHOOSEN_FILE == *.zip ]]; then
        __pmsg 'info' 'ZIP-file detected'
        local LOOP=true
        while $LOOP; do
            read -sp 'Please enter the password of the ZIP file (enter, if none): ' ZIP_PASSWORD; echo
            unzip -o -P $ZIP_PASSWORD "${PATH_TO_FILE}${CHOOSEN_FILE}" &> /dev/null
            [[ $? -ne 0 ]] && __pmsg 'error' 'Please check the Password' && __printSpacer && continue
            if [[ $IMAGE != 'mongo' ]]; then
                # if no mongo (because mongo is a folder)
                CHOOSEN_FILE=${CHOOSEN_FILE/.zip/'.sql'} # replace .zip with .sql
            fi
            LOOP=false
        done
    fi

    # if not zipped (anymore), go ahead
    __printHeader 'Import' 'Enter DB info...'
    __getDbUsernameAndPassword

    __printHeader 'Import' 'Importing...'
    case $IMAGE in
        'mysql') if [[ $CHOOSEN_FILE == *.sql ]]; then __importMysql $1; else echo "wrong file format" && exit 1; fi;;
        'mariadb') if [[ $CHOOSEN_FILE == *.sql ]]; then __importMariadb $1; else echo "wrong file format" && exit 1; fi;;
        'postgres') if [[ $CHOOSEN_FILE == *.sql ]]; then __importPostgres $1; else echo "wrong file format" && exit 1; fi;;
        'mongo') __importMongo $1;;
        *) echo 'unexpected type error' && exit 1;;
    esac

    __pmsg 'success' 'Import was successfull'

    __askBackOrExit
    __screen0Init
}

# delete a docker contaienr
function __screen3Delete() { # __screen3Delete <name>
    __printHeader 'Delete' $1

    read -p "Do you want to delete ${F_C}\"$1\"${F_X}? (y/n): " YN

    if [[ $YN =~ ^[yYjJ]$ ]]; then
        docker container rm -fv $1 > /dev/null # delete container (force delete and delete volumes)
        if [[ $? -ne 0 ]]; then
            __pmsg 'error' 'something went wrong in the delete process'
        else
            __pmsg 'success' "Deleted \"$1\""
        fi
        sleep 2 # sleep, so user can read the text
    elif [[ $YN =~ ^[nN]$ ]]; then
        # if user explicit says no, go back one page
        __screen3Settings $1
    fi
    # if container was deleted or nothing was choosen, go to settings init
    __screen3Init
}

#################################################################################
# SCRIPT
#################################################################################

__init
exit 0
