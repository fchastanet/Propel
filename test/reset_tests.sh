#!/usr/bin/env bash
# Reset Propel tests fixtures
# 2011 - William Durand <william.durand1@gmail.com>

if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
    echo "Usage: $0 Platform Host HostRootPassword"
    echo "Platform - the platform to use (mysql, sqllite, ...)"
    echo "Host - hostname of the given platform"
    echo "HostRootPassword - the root password for the given platform"
    echo "eg: $0 mysql mysql root"
fi

CURRENT_DIR=$( cd "$( readlink -e "${BASH_SOURCE[0]%/*}" )" && pwd )
ROOT_DIR=$( cd "$( readlink -e "${BASH_SOURCE[0]%/*}/.." )" && pwd )
FIXTURES_DIR="${CURRENT_DIR}/fixtures"

PLATFORM="$1"
HOST="$2"
HOST_ROOT_PASSWORD="$3"

if [[ "$PLATFORM" != "mysql" ]]; then
    echo "only mysql platform is supported for the moment"
    exit 1
fi

# create dbs
if [[ "$PLATFORM" = "mysql" ]]; then
    mysql -h${HOST} -uroot -p${HOST_ROOT_PASSWORD} < "${CURRENT_DIR}/createTestDatabases.mysql.sql" || exit 1
fi

# create build.properties from template
declare -a buildPropertiesFiles

mapfile -t buildPropertiesFiles < <(find "${CURRENT_DIR}" -name "build.${PLATFORM}.template.properties" -printf "%h\n")
if [[ ${#buildPropertiesFiles[@]} != 0 ]]; then
    for dir in "${buildPropertiesFiles[@]}"; do
        echo "configure files "${dir}/build.properties" and "${dir}/runtime-conf.xml""
        cp "${dir}/build.${PLATFORM}.template.properties" "${dir}/build.properties" || exit 1
        sed -i \
            -e "s/propel.database.url = mysql:host=mysql/propel.database.url = mysql:host=${HOST}/g" \
            -e "s/propel.database.password = root/propel.database.password = ${HOST_ROOT_PASSWORD}/g" \
            "${dir}/build.properties" || exit 1
        if [[ -f "${dir}/runtime-conf.${PLATFORM}.template.xml" ]]; then
            cp "${dir}/runtime-conf.${PLATFORM}.template.xml" "${dir}/runtime-conf.xml" || exit 1
            sed -i \
                -e "s/<dsn>mysql:host=mysql/<dsn>mysql:host=${HOST}/g" \
                -e "s#<password>root</password>#<password>${HOST_ROOT_PASSWORD}</password>#g" \
                "${dir}/runtime-conf.xml" || exit 1
        fi
    done
fi


function rebuild
{
    local dir=$1

    if [[ -d "${FIXTURES_DIR}/$dir/build" ]] ; then
        rm -rf "${FIXTURES_DIR}/$dir/build"
    fi

    ${ROOT_DIR}/generator/bin/propel-gen ${FIXTURES_DIR}/$dir main >/dev/null
    ${ROOT_DIR}/generator/bin/propel-gen ${FIXTURES_DIR}/$dir insert-sql >/dev/null
}

DIRS=`ls ${FIXTURES_DIR}`

for dir in $DIRS ; do
    echo "[ rebuild ${FIXTURES_DIR}/$dir ]"
    rebuild $dir
done

# Special case for reverse fixtures

REVERSE_DIRS=`ls ${FIXTURES_DIR}/reverse`

for dir in $REVERSE_DIRS ; do
    if [ -f "${FIXTURES_DIR}/reverse/$dir/build.properties" ] ; then
        echo "[ ${FIXTURES_DIR}/reverse/$dir ]"
        ${ROOT_DIR}/generator/bin/propel-gen ${FIXTURES_DIR}/reverse/$dir insert-sql > /dev/null
    fi
done

echo "you can now run unit tests by launching this command :"
echo "phpunit ${CURRENT_DIR}"
