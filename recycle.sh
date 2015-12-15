#!/usr/bin/env sh

#This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License 
#as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

#development stage: 2. draft

FACTOR=1024
B=$FACTOR
KB=$(($B*$FACTOR))
MB=$(($KB*$FACTOR))
GB=$(($MB*$FACTOR))

MAX_SIZE=$(($GB))
COMPRESSION="TGZ"
RECYCLE_BIN=$HOME/.recycle

if [ $HOME/.recyclerc ]; then
  mkdir -p /tmp/$$
  grep -E -e '^[[:space:]]*[A-Za-z0-9_]+=[^\[\[:space:\]\]]$' $HOME/.recyclerc > /tmp/$$/.recyclerc
  . /tmp/$$/.recyclerc
  rm -R /tmp/$$

  MAX_SIZE=$max_size
  COMPRESSION=$(echo $compression|tr 'a-z' 'A-Z')
  RECYCLE_BIN=$recycle_bin

  unset max_size compression recycle_bin
fi

suffix="tar.gz"
[ COMPRESSION = "TBZ2" ] && suffix="tar.bz2"

force_yes=false

ask_user() {
  while true; do
    read -p $1 USER_ANSWER
    case $USER_ANSWER in
      [Yy]*) return 1 ;;
      [Nn]*) return -1 ;;
      *) USER_ANSWER=""
         echo "Please answer yes or no."
         ;;
    esac
  done
}

create_bin() {
  mkdir -p /tmp/$$/recycle
  echo "$1" > /tmp/$$/recycle/size
  touch > /tmp/$$/recycle/content

  opt="-x"
  [ $COMPRESSION = "TBZ2" ] && opt="-j"

  tar --create $opt --file $RECYCLE_BIN --directory /tmp/$$ size content
  rm -R /tmp/$$
}

clear_bin() {
  if [ -f $RECYCLE_BIN ]; then
    if [ $force_yes = false ]; then
      ask_user "Do you really want to delete everyting inside $RECYCLE_BIN? "
      [ $? -lt 0 ] && return 1
    fi

    size=$(tar --extract --to-stdout --file $RECYCLE_BIN size)
    rm $RECYCLE_BIN
    create_bin $size
  fi
}

list_content() {
  if [ -f $RECYCLE_BIN ]; then
    tar --extract --to-stdout --file $RECYCLE_BIN content|nl -s:
  fi
}

remove() {
  mkdir -p /tmp/$$
  file_name=$(tar --extract --file $RECYCLE_BIN content|sed "$1p"|cut -d: -f4)
  tar --extract --to-stdout --file $RECYCLE_BIN content|sed "$1d" > /tmp/$$/content
  tar --delete --file $RECYCLE_BIN $older_file
  tar --update --file $RECYCLE_BIN --directory /tmp/$$ content
  rm /tmp/$$/content
}

check_size() {
  bin_max_size=$(tar --extract --to-stdout --file $RECYCLE_BIN size)
  bin_size=$(du $RECYCLE_BIN)
  older=$(tar --extract --to-stdout --file $RECYCLE_BIN content|head -n 1|cut -d: -f1)
  total_size=$(($bin_size+$1))

  while [ $total_size -gt $bin_max_size ]; do
    if [ $force_yes = false ]; then
      ask_user "$RECYCLE_BIN is full. Do you want to delete $older to free space? "
      [ $? -lt 0 ] && return 1
    fi

    remove 1
  done
}

change_size() {
  [ ! -f $RECYCLE_BIN ] && create_bin
  mkdir -p /tmp/$$/recycle
  echo "$1" > /tmp/$$/recycle/size
  tar --update --file $RECYCLE_BIN --directory /tmp/$$/recycle size
  check_size
}

recycle() {
  [ ! -f $RECYCLE_BIN ] && create_bin
  name=$(cat /dev/urandom | env LC_CTYPE=C tr -cd 'a-f0-9' | head -c 32)

  while [ -f /tmp/$name ]; do
    name=$(cat /dev/urandom | env LC_CTYPE=C tr -cd 'a-f0-9' | head -c 32)
  done

  opt="-z"
  [ $COMPRESSION = "TGZ" ] && opt="-j"

  tar --create $opt --file /tmp/$name $1

  file_size=$(du /tmp/$name)
  datetime=$(date +'%Y-%m-%d %H-%M-%S')
  bin_max_size=$(tar --extract --to-stdout --file $RECYCLE_BIN size)
  bin_size=$(du $RECYCLE_BIN)
  older=$(tar --extract --to-stdout --file $RECYCLE_BIN content|head -n 1|cut -d: -f1)
  total_size=$(($bin_size+$file_size))

  while [ $total_size -gt $bin_max_size ]; do
    if [ $force_yes = false ]; then
      ask_user "$RECYCLE_BIN is full. Do you want to delete $older to free space? "
      [ $? -lt 0 ] && return 1
    fi

    remove_older
  done

  echo "$1:$file_size:$datetime:$name" >> content
  tar --concatenate --file $RECYCLE_BIN /tmp/$name
  tar --update --file $RECYCLE_BIN --directory /tmp/$$ content
  rm -R /tmp/$$
  rm -R $1
}

restore() {
  file_name=$(tar --extract --to-stdout --file $RECYCLE_BIN content|sed -n "$1p"|cut -d: -f4)
  tar --extract --to-stdout --file $RECYCLE_BIN $file_name|tar --extract
  remove $1
}

print_usage() {
  echo ""
  echo "recycle maintains a simple \"recycle\" bin (actually a tarball file) hidden in the user home directory"
  echo "recycle [directory or file names] -> moves directories or files to the ~/.recyle bin"
  echo "recycle [-c or --clear] -> clear the ~/.recycle bin"
}

if [ $# -eq 0 ]; then
  print_usage
  exit 0
fi

action="recycle"

while [ -n "$1" ]; do
  case $1 in
    -b|--bin) shift
              RECYCLE_BIN=$1
              ;;
    -y|--force-yes) force_yes=true ;;
    -C|--create) create_bin $MAX_SIZE ;;
    -c|--clear) clear_bin ;;
    -l|--list) list_content ;;
    -s|--size) shift
               change_size $1
               ;;
    -R|--restore) action="restore" ;;
    -r|--recycle) action="recycle" ;;
    *) 
       if [ ! -d $1 -a ! -f $1 ]; then
         echo "Don't know what $1 mean" 1>&2
       elif [ $action = "restore" ]; then
         restore $1
       elif [ $action = "recycle" ]; then
         recycle $1
       fi
       ;;
    fi
  esac
  shift
done
