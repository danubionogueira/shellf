#!/usr/bin/env sh

#This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License 
#as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

#development stage: 2. draft

base=$HOME/.passafe.gpg

load_vars() {
  if [ -f $HOME/.passaferc ]; then
    echo "found file"
    mkdir -p /tmp/passafe
    grep -E -e '^[[:space:]]*[A-Za-z0-9]+=' $HOME/.passaferc > /tmp/passafe/$$
    . /tmp/passafe/$$
    rm /tmp/passafe/$$
  fi
}

build_pattern() {
  digits="0 1 2 3 4 5 6 7 8 9"
  upper="A B C D E F G H I J K L M N O P Q R S T U V W X Y Z"
  lower="a b c d e f g h i j k l m n o p q r s t u v w x y z"
  symbols="! @ # \$ % & ( ) [ ] { } _ + - = ?"
  pattern="$digits $upper $digits $lower $digits $symbols"
  unset digits upper lower symbols
}

generate_pass() {
  length=8
  #RESULT=$(date +%s | sha256sum | base64 | head -c $lenght)
  RESULT=$(echo $pattern|tr ' ' '\n'|shuf|head -n $length|tr '\n' ' '|sed -e 's/ //g')
}

to_clipboard() {
  #copy for cygwin
  if [ -e /dev/clipboard ]; then
    echo $1 > /dev/clipboard
  fi

  #copy for X
  if [ /usr/bin/xclip ]; then
    echo $1|xclip
  fi
}

print_usage() {
  echo "passafe uses GNU implementation of PGP (gpg) to keep a simple database of passwords"
  echo "the database is actually an encrypted plain text tab separated values file"
  echo "as passafe uses gpg to decrypt files, it is important to have it installed and the key generated or imported beforehand"
  echo "take care for not creating two entries at the same time, as the database is only a plain file, if you do this, chances are that you lose one of then"
}

print_vars() {
  echo "base=$base"
  echo "key=$key"
  echo "entry=$entry"
  echo "url=$url"
  echo "login=$login"
  echo "pass=$pass"
  echo "read_only=$read_only"
  echo "force_new=$force_new"
  echo "vacuum=$vacuum"
  echo "pattern=$pattern"
  echo "length=$length"
}

read_only=false

build_pattern
load_vars

NO_BASE=1
NO_GPG=2
NO_KEY=3
NO_ENTRY=4

gpg_path="$(whereis gpg|cut -d: -f2)"

if [ -z "$gpg_path" ]; then
  echo "gpg program not found" 2>&1
  exit $NO_GPG
fi

force_new=false
vacuum=false

while [ -n "$1" ]; do
  case $1 in
    -k|--key) shift
              key=$1
              ;;
    -b|--base) shift
               base=$1
               ;;
    -e|--entry) shift
                entry=$1
                ;;
    -n|--new) shift
              entry=$1
              force_new=true
              ;;
    -l|--login) shift
                login=$1
                ;;
    -p|--password) shift
                   pass=$1
                   ;;
    -u|--url) shift
              url=$1
              ;;
    -r|--read-only) read_only=true ;;
    -V|--vacuum) vacuum=true ;;
    *) entry=$1 ;;
  esac
  shift
done

#print_vars
#exit 0

if [ -z "$base" ]; then
  echo "no base for working with passwords" 2>&1
  exit $NO_BASE
fi

if [ -z "$key" ]; then
  echo "no key for decrypting $base" 2>&1
  exit $NO_KEY
fi

if [ -z "$entry" ]; then
  echo "no entry for work in $base" 2>&1
  exit $NO_KEY
fi

if [ -s $base ]; then
  touch $base
  chmod 600 $base
  echo ""|gpg -er $key > $base
fi

#entry {tab} url {tab} login {tab} password {tab} datetime

content="$(gpg -dr $key $base)"

if [ $force_new = false ]; then
  dbentry=$(echo "$content"|grep -E -e "^$entry\t"|tail -n 1)

  if [ -n "$dbentry" ]; then
    url=$(echo $dbentry|cut -d$'\t' -f2)
    login=$(echo $dbentry|cut -d$'\t' -f3)
    pass=$(echo $dbentry|cut -d$'\t' -f4)
    datetime=$(echo $dbentry|cut -d$'\t' -f5)
  elif [ $read_only = false ]; then
    echo "$entry not found in $base, adding it to $base"
    force_new=true
  fi

  unset dbentry
fi

if [ $force_new = true ]; then
  mkdir -p /tmp/passafe
  touch /tmp/passafe/$$
  chmod 600 /tmp/passafe/$$

  if [ -z "$pass" ]; then
    generate_pass
    pass=$RESULT
  fi

  datetime="$(date +'%Y-%m-%d %H:%M:%S')"
  echo "new password for: entry -> $entry; url -> $url; login -> $login; datetime -> $datetime"

  if [ $vacuum = true ]; then
    echo "$content"|sed -E -e "/^$entry\t/d" -e "\$a$entry\t$url\t$login\t$pass\t$datetime"|gpg -er $key > /tmp/passafe/$$
  else
    echo "$content"|sed -E -e "\$a$entry\t$url\t$login\t$pass\t$datetime"|gpg -er $key > /tmp/passafe/$$
  fi

  cat /tmp/passafe/$$ > $base
  rm /tmp/passafe/$$
fi

unset content
to_clipboard $pass
unset pass

echo "password for $entry copied to clipboard: url -> $url; login -> $login"
