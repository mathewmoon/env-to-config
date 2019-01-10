#!/bin/sh

##
# Author: Mathew Moon <me@mathewmoon.net>
##

myname=$(echo $0|sed -r 's#.*/##g')
usage() {
    echo "$(cat<<EOF

    #################################################################
    # Modify a configuration file based on environment variables.   #
    # Variables starting with the given prefix will be searched for #
    # in the given config file and their values replaced. Keys not  #
    # found in the file will be created with a key matching the env #
    # variable name stripped of its matched prefix.                 #
    #################################################################

    USAGE: $myname [options]

    -c|--config	  Configuration file to parse and write to (Not compatible with -d)
    -p|--prefix   A single prefix to identify env variables from, or optionally a sed compatible regular expression of prefixes
    -d|--dir      A directory of files to work against (Not compatible with -c)
    -t|--test	    Test and print to stdout only, do not overwrite the original config file

    Examples:
      config -c ./file.conf -p 'ZOO_'
      config -c ./file.conf -p 'ZOO_|myvar_|useMe_'
      config -c ./file.conf -p 'myVar' -t >someNewConfig.conf
      config -d ./aDirectoryOfFiles -p 'myVar'


EOF
  )"
    exit
}

while [ ! -z $1 ]; do
  case $1 in
    -p|--prefix)
      shift
      PREFIX="$1"
      ;;
    -c|--config)
      shift
      CONFIG_FILE="$1"
      ;;
    -d|--dir)
      shift
      CONFIG_DIR="$1"
      ;;
    -t|--test)
      TEST=true;
      ;;
    *)
      usage
      exit 1
      ;;
  esac
  shift
done

parseConfig(){
  CONFIG_FILE=$1

  TEMP=${CONFIG_FILE}.$(date +"%s").tmp
  CONFIG=$(sed -r -e 's/(^#.*)//g' -e '/^$/d' $CONFIG_FILE|sort|uniq)

  #Create a config to edit
  echo "$CONFIG" > $TEMP

  #Get any env vars that have our desired prefix and strip the prefix
  vars=$(env |egrep $PREFIX|sed -r "s/$PREFIX//g")

  for var in $vars; do
    #Format our new lines
    val=$(echo $var|cut -d= -f2|sed 's/(^\s*)|(\s*$)//g')
    key=$(echo $var|cut -d= -f1|sed 's/(^\s*)|(\s*$)//g')
    newLine="${key} = ${val}"

    # If this key doesn't exist then put it in the config
    egrep -q "$key(\s*)?=" $TEMP || echo $newLine >> $TEMP

    #if the key exists then search and replace
    sed  -ri "s|${key}.*|$newLine|" $TEMP
  done

  #Deliver and clean up
  [ -z $TEST ] && mv $TEMP $CONFIG_FILE && cat $CONFIG_FILE && rm -f $TEMP >/dev/null 2>&1
  [ ! -z $TEST ] && cat $TEMP && rm -f $TEMP >/dev/null 2>&1
}

# Make user we have only either a file, or a directory, and a prefix
if [ -z ${CONFIG_FILE} ] && [ -z ${CONFIG_DIR} ]]; then
  usage
fi

[ -z ${PREFIX} ] && usage

if [ ! -z ${CONFIG_FILE} ] && [ ! -z ${CONFIG_DIR} ]; then
  echo "Options -c and -d are mutually exclusive"
  usage
fi

if [ ! -f $CONFIG_FILE ]; then
  echo "Config file $CONFIG_FILE does not exist."
  exit 2
fi

if [ ! -z $CONFIG_DIR ] && [ -d $CONFIG_DIR ]; then
  for f in $(find ${CONFIG_DIR} -type f); do
    parseConfig $f
  done
elif [ ! -z $CONFIG_FILE ] && [ -f $CONFIG_FILE ]; then
  parseConfig $CONFIG_FILE
else
  echo "Could not find config file or directory"
  exit 2
fi
