#!/usr/bin/env sh

#This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License 
#as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

#development stage: 3. prototype

#error codes
NO_DEP=1
BAD_ARGS=2
NO_RULES=3

stderr() {
  echo "$@" 1>&2
}

check_prg() {
  IFS=:
  for path in $PATH; do
    [ ! -x $path/$1 ] && return 0
  done

  return 1
}

check_deps() {
  prg_list="test echo getent basename mkdir cp mv rm rmdir ls touch cat tail chmod hostname date wc bc cut grep sed tar"
  miss=false

  for prg in $prg_list; do
    check_prg $prg

    if [ $? -gt 0 ]; then
      stderr "missing program $prg"
      miss=true
    fi
  done

  [ $miss = true ] && exit $NO_DEP
}

check_deps

unset NO_DEP path_list check_prg check_deps IFS prg_list miss

#file format: tarball->targets->user&root&rules->specific_files_for_each_kind

exit_on_error=false
verbose=0
date_format="%Y%m%d"
time_format="%H%M%S"
default_interpreter="#!/usr/bin/env sh"

if [ -n "$USER" ]; then
  entry="$(getent passwd $USER)"
  if [ -n "$entry" ]; then
    default_interpreter="$(echo $entry | cut -d: -f7)"
    default_interpreter="#!/usr/bin/env $(basename $default_interpreter)"
  fi
fi

#the above options can be overriden by the config file
load_vars() {
  if [ -f $1 ]; then
    if [ ! -f /tmp/$$/nomad.conf ]; then
      mkdir -p /tmp/$$
      grep -E -e '^[^#].+=.+$' -f $1 > /tmp/$$/nomad.conf
    fi

    source /tmp/$$/nomad.conf
  fi
}

load_vars $HOME/.config/nomad/nomad.conf

PROGRAM="nomad"
VERSION="0.1"
EXIT_ON_ERROR=$exit_on_error
VERBOSE=$verbose
VERBOSE_MAX=3

ESC_HOME=$(echo $HOME|sed -e 's/\//\\\//g')

print_verbose() {
  if [ $VERBOSE -ge $1 ]; then
    shift
    echo "$@"
  fi
}

print_rules() {
  echo ""
  echo "Put your rules for each target in ~/.config/nomad/\$target"
  echo ""
  echo "~/.config/nomad/rules/\$target/script_pre -> script executed pre unpack (if unpacking)"
  echo "~/.config/nomad/rules/\$target/files -> files to be copied both for pack or unpack"
  echo "~/.config/nomad/rules/\$target/script_post -> script executed post unpack (if unpacking)"
}

create_skel() {
  print_verbose 2 "echo \"#!/usr/bin/env sh\" >> $1"
  echo $default_interpreter >> $1
  print_verbose 2 "echo "" >> $1"
  echo "" >> $1
  print_verbose 2 "echo "" >> $1"
  echo "" >> $1
}

action_new() {
  p_target=$HOME/.config/nomad/rules/$1
  
  mkdir -p $p_target
  
  if [ ! -e $p_target/pre ]; then
    print_verbose 1 "creating file for pre script"
    
    if [ -s $HOME/.config/nomad/skel ]; then
      print_verbose 2 "cp $HOME/.config/nomad/skel $p_target/pre"
      cp $HOME/.config/nomad/skel $p_target/pre
    else
      create_skel $p_target/pre
    fi
  fi

  if [ ! -e $p_target/files ]; then
    print_verbose 1 "creating file for files"
    print_verbose 2 "touch $p_target/files"
    touch $p_target/files
  fi

  if [ ! -e $p_target/post ]; then
    print_verbose 1 "creating file for post script"
    
    if [ -s $HOME/.config/nomad/skel ]; then
      print_verbose 2 "cp $HOME/.config/nomad/skel $p_target/post"
      cp $HOME/.config/nomad/skel $p_target/post
    else
      create_skel $p_target/post
    fi
  fi
}

action_strip() {
  p_target=$HOME/.config/nomad/rules/$1
  
  if [ -f $p_target/pre ]; then
    if [ ! -s $p_target/pre ] || [ -z "$(tail -n +2 $p_target/pre|grep -v '^\$')" ]; then
      print_verbose 1 "removing pre script file"
      print_verbose 2 "rm $p_target/pre"
      rm $p_target/pre
    fi
  fi
  
  if [ -f $p_target/files ] && [ ! -s $p_target/files ]; then
    print_verbose 1 "removing files file"
    print_verbose 2 "rm $p_target/files"
    rm $p_target/files
  fi
 
  if [ -f $p_target/post ]; then
    if [ ! -s $p_target/post ] || [ -z "$(tail -n +2 $p_target/post|grep -v '^\$')" ]; then
      print_verbose 1 "removing post script file"
      print_verbose 2 "rm $p_target/post"
      rm $p_target/post
    fi
  fi
  
  if [ -z "$(ls $p_target)" ]; then
    print_verbose 1 "removing target dir $p_target"
    print_verbose 2 "rmdir $p_target" 
    rmdir $p_target
  fi
}

print_pack_targets() {
  echo ""
  echo "TARGETS in $HOME/.config/nomad/rules:"
  echo ""
  echo "$([ -d $HOME/.config/nomad/rules ] && ls $HOME/.config/nomad/rules)"
}

print_unpack_targets() {
  echo ""
  echo "TARGETS in $1:"
  echo ""
  echo "$(tar --list --file $1|sed -e '/^\.\/$/d' -e 's/^.\///' -e 's/\.tar\.gz//g' -e 's/\.tar\.bz2//g'|grep -v 'MANIFEST')"
}

print_usage() {
  echo ""
  echo "nomad ACTION [[[FILE1] [TARGET1 [TARGET2 [TARGETN]]]|[ALL]] [[FILE2] [TARGET1 [TARGET2 [TARGETN]]]|[ALL]]]"
  echo ""
  echo "ACTION"
  echo "  -h|--help) prints this help and exit (default)"
  echo "  -l|--list) list targets that have rules"
  echo "  -n|--new) create rules directory structure for target under ~/.config/nomad/\$target"
  echo "  -s|--strip) deletes zero length rules files"
  echo "  -p|--pack) create package for targets"
  echo "  -u|--unpack) extracts the contents of a backup file"
  echo "  -m|--merge) merge specific targets from various backup files"
  echo "  -o|--output) output filename"
  echo "  -bz2|--bzip2) use bzip2 compression (along with tar) (default)"
  echo "  -gz|--gzip) use bzip2 compression (along with tar)"
  echo "  --no-files) do not coppy files"
  echo "  --no-user-files) do not copy files under user home"
  echo "  --no-root-files) do not copy files over user home"
  echo "  --no-pre) do not execute pre scripts"
  echo "  --no-post) do not execute post scripts"
  echo "  --exit-on-error) makes the program exit on any error (otherwise the program just skips the current target)"
  echo "  -v|--verbose) increase or set verbosity level for the current package (0-2, default 0)"
  echo "  --override-rules) overrides the user rules with the rules found in the package (when unpacking)"
  echo "  -H|--user-home) directory to be used for unpack the user files, instead of the current user home"
  echo "  -b|--backup) make backups before overwriting files (when unpacking)"
  echo ""
  print_pack_targets
  echo ""
  echo "Targets will be executed one at a time in a queue model, so, order matters"
  echo ""
  echo "FILE - file contaning all files previously collected with --pack action"
}

default_vars() {
  override=false
  backup=false

  load_vars $HOME/.config/nomad/nomad.conf

  action=""
  compression="TBZ2"
  pre=true
  files=true
  user_files=true
  root_files=true
  post=true
  rules=true
  all=false
  backuped_files=""
  output=""
  input=""
  targets=""
  targets_count=0
  user_home=$HOME
  VERBOSE=$verbose
}

print_vars() {
  echo ""
  echo "action=$action"
  echo "compression=$compression"
  echo "output=$output"
  echo "input=$input"
  echo "targets=$targets"
  echo "targets_count=$targets_count"
  echo "EXIT_ON_ERROR=$EXIT_ON_ERROR"
  echo "VERBOSE=$VERBOSE"

  echo "pre=$pre"
  echo "files=$files"
  echo "user_files=$user_files"
  echo "root_files=$root_files"
  echo "post=$post"
  echo "rules=$rules"
  echo "all=$all"
  echo "override=$override"
  echo "user_home=$user_home"
  echo "backup=$backup"
  echo "backuped_files=$backuped_files"
}

process_action() {
  if [ -z "$action" ]; then
    if [ -n "$input" ]; then
      echo "unknown action for file $input"
    else
      echo "unknown action"
    fi
    
    [ $EXIT_ON_ERROR = true ] && exit $BAD_ARGS
  elif [ $action = "usage" ]; then
    print_usage
    exit 0
  elif [ $action = "list" ]; then
    if [ -z "$input" ]; then
      print_pack_targets
    else
      print_unpack_targets $input
    fi
  else
    if [ $root_files = false -a $user_files = false ]; then
      files=false
    fi

    if [ $all = true ]; then
      if [ $action = "pack" -o $action = "new" -o $action = "strip" ]; then
        targets=$([ -d $HOME/.config/nomad/rules ] && ls $HOME/.config/nomad/rules)
      elif [ $action = "merge2" ]; then
        targets=$([ -d /tmp/nomad/$$ ] && ls /tmp/nomad/$$|grep -v 'MANIFEST'|sed -e 's/\.tar\.gz//' -e 's/\.tar\.bz2//')
      elif [ -n "$input" ]; then
        targets=$(tar --list --file $input|sed -e '/^\.\/$/d' -e 's/^.\///' -e 's/\.tar\.gz//g' -e 's/\.tar\.bz2//g'|grep -v 'MANIFEST')
      fi
    fi

    targets=$(echo $targets|sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    targets_count=$(echo $targets|wc -w)

    if [ $VERBOSE -ge 3 ]; then
      print_vars
      return 0
    fi

    if [ $targets_count -lt 1 ]; then
      if [ $action = "strip" ]; then
        stderr "no target to strip"
      elif [ $action = "new" ]; then
        stderr "no target to create the rules"
      elif [ $action = "pack" ]; then
        stderr "no target to pack"
      elif [ $action = "unpack" ]; then
        stderr "no target to unpack from file $input"
      fi

      [ $EXIT_ON_ERROR = true ] && exit $BAD_ARGS
      return $BAD_ARGS
    fi

    suffix="tar.bz2"

    if [ "$compression" = "TGZ" ]; then
      suffix="tar.gzip"
    fi

    if [ $action = "pack" -o $action = "unpack" -o $action = "merge1" ]; then
      print_verbose 1 "creating temp dir"
      print_verbose 2 "mkdir -p /tmp/nomad/$$"
      mkdir -p /tmp/nomad/$$
    fi

    if [ $action = "pack" -o $action = "merge2" ]; then
      print_verbose 1 "creating manifest file"
      print_verbose 2 "echo -e \"PROGRAM=$PROGRAM\nVERSION=$VERSION\" > /tmp/nomad/$$/$target/MANIFEST"
      echo -e "PROGRAM=$PROGRAM\nVERSION=$VERSION" > /tmp/nomad/$$/MANIFEST
      
    fi

    if [ $action = "unpack" -o $action = "merge1" ] && [ $all = true ]; then
      print_verbose 1 "decompressing file $input"
      print_verbose 2 "tar --extract --auto-compress --directory /tmp/nomad/$$ --file $input"
      tar --extract --auto-compress --directory /tmp/nomad/$$ --file $input
    fi

    targets_files=""

    for target in $targets; do  
      if [ $action = "new" ]; then
        action_new $target
      elif [ $action = "strip" ]; then
        action_strip $target
      elif [ $action = "pack" ]; then
        if [ ! -d $HOME/.config/nomad/rules/$target ]; then
          stderr "could not find rules for target $target"
          [ $EXIT_ON_ERROR = true ] && exit $NO_RULES
        else
          print_verbose 1 "creating temp dir for $target"
          print_verbose 2 "mkdir -p /tmp/nomad/$$/$target"
          mkdir -p /tmp/nomad/$$/$target

          if [ $pre = true -o $files = true -o $post = true ]; then
            print_verbose 1 "creating temp rules dir"
            print_verbose 2 "mkdir -p /tmp/nomad/$$/$target/rules"
            mkdir -p /tmp/nomad/$$/$target/rules
          fi

          rules_names=""

          if [ $pre = true ] && [ -f $HOME/.config/nomad/rules/$target/pre ] && [ -z "$(tail -n +2 $HOME/.config/nomad/rules/$target/pre|grep -v '^\$')" ]; then
            print_verbose 1 "copying pre script"
            print_verbose 2 "cp $HOME/.config/nomad/rules/$target/pre /tmp/nomad/$$/$target/rules"
            cp $HOME/.config/nomad/rules/$target/pre /tmp/nomad/$$/$target/rules
            rules_names="$rules_names pre"
          fi

          if [ $files = true ] && [ -s $HOME/.config/nomad/rules/$target/files ]; then
            files_list="$(cat $HOME/.config/nomad/rules/$target/files)"
            files_root=""
            files_user=""

            for file in $files_list; do
              #[ ... -a if file name starts with ~ or $HOME or whatever is the name of home dir ]
              if [ $user_files = true -a -n "$(echo $file|grep -e \"^$HOME\" -e '^$HOME' -e '^~')" ]; then
                #subtitutes an absolute file name by a relative
                file_name="$(echo $file|sed -e 's/^~\/*//' -e 's/^$ESC_HOME\/*//')"
                files_user="$files_user $file_name"
                print_verbose 1 "adding user file $file"
                print_verbose 2 "echo \"\$HOME/$file_name\" >> /tmp/nomad/$$/$target/rules/files"
                echo "\$HOME/$file_name" >> /tmp/nomad/$$/$target/rules/files
              elif [ $root_files = true ]; then
                files_root="$files_root $file"
                print_verbose 1 "adding root file $file"
                print_verbose 2 "echo \"$file\" >> /tmp/nomad/$$/$target/rules/files"
                echo "$file" >> /tmp/nomad/$$/$target/rules/files
              fi
            done

            files_user="$(echo $files_user|sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            files_root="$(echo $files_root|sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

            if [ -n "$files_user" ]; then
              print_verbose 1 "creating user file"
              print_verbose 2 "tar --create --auto-compress --file /tmp/nomad/$$/$target/user.$suffix --directory $HOME $files_user"
              tar --create --auto-compress --file /tmp/nomad/$$/$target/user.$suffix --directory $HOME $files_user
            fi

            if [ -n "$files_root" ]; then
              print_verbose 1 "creating root file"
              print_verbose 2 "tar --create --auto-compress --file /tmp/nomad/$$/$target/root.$suffix --directory $HOME $files_root"
              tar --create --auto-compress --file /tmp/nomad/$$/$target/root.$suffix --directory / $files_root
            fi
            
            [ -f /tmp/nomad/$$/$target/rules/files ] && rules_names="$rules_names files"
          fi

          if [ $post = true ] && [ -f $HOME/.config/nomad/rules/$target/post ] && [ "$(tail -n +2 $HOME/.config/nomad/rules/$target/post|grep -v '^\$')" ]; then
            print_verbose 1 "copying post script"
            print_verbose 2 "cp $HOME/.config/nomad/rules/$target/post /tmp/nomad/$$/$target/rules"
            cp $HOME/.config/nomad/rules/$target/post /tmp/nomad/$$/$target/rules
            rules_names="$rules_names post"
          fi

          if [ $pre = true -o $files = true -o $post = true ]; then
            rules_names="$(echo $rules_names|sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            print_verbose 1 "creating rules file"
            print_verbose 2 "tar --create --auto-compress --file /tmp/nomad/$$/$target/rules.$suffix --directory /tmp/nomad/$$/$target/rules ."
            tar --create --auto-compress --file /tmp/nomad/$$/$target/rules.$suffix --directory /tmp/nomad/$$/$target/rules $rules_names

            print_verbose 1 "removing copied rules files and scripts"
            print_verbose 2 "rm -R /tmp/nomad/$$/$target/rules"
            rm -R /tmp/nomad/$$/$target/rules
          fi

          files_names=""

          [ -f /tmp/nomad/$$/$target/rules.$suffix ] && files_names="$files_names rules.$suffix"
          [ -f /tmp/nomad/$$/$target/user.$suffix ] && files_names="$files_names user.$suffix"
          [ -f /tmp/nomad/$$/$target/root.$suffix ] && files_names="$files_names root.$suffix"

          files_names="$(echo $files_names|sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

          print_verbose 1 "creating target file for $target"
          print_verbose 2 "tar --create --auto-compress --file /tmp/nomad/$$/$target.$suffix --directory /tmp/nomad/$$/$target $files_names"
          tar --create --auto-compress --file /tmp/nomad/$$/$target.$suffix --directory /tmp/nomad/$$/$target $files_names
          targets_files="$targets_files $target.$suffix"

          print_verbose 1 "removing temp dir for target $target"
          print_verbose 2 "rm -R /tmp/nomad/$$/$target"
          rm -R /tmp/nomad/$$/$target
        fi
      elif [ $action = "unpack" ]; then
        if [ $all = true ]; then
          target_file=$(ls /tmp/nomad/$$/$target*)
        else
          target_file=$(tar --list --file $input|grep '^$target')
        fi

        if [ -z $target_file ]; then
          stderr "no target $target in file $input"
          [ $ERROR_ON_EXIT = true ] && exit $BAD_ARGS
        fi

        print_verbose 1 "creating tem dir for target $target"
        print_verbose 2 "mkdir -p /tmp/nomad/$$/$target"
        mkdir -p /tmp/nomad/$$/$target

        if [ $all = true ]; then
          print_verbose 1 "decompressing target file $target_file"
          print_verbose 2 "tar --extract --auto-compress --directory /tmp/nomad/$$/$target --file $target_file"
          tar --extract --auto-compress --directory /tmp/nomad/$$/$target --file $target_file
        else
          print_verbose 1 "decompressing target file $target_file"
          print_verbose 2 "tar --extract --auto-compress --directory /tmp/nomad/$$/$target --file $input $target_file"
          tar --extract --auto-compress --directory /tmp/nomad/$$/$target --file $input $target_file
        fi

        if [ $rules = true ]; then
          file_rules=$(ls /tmp/nomad/$$/$target/rules*)

          if [ -n "$file_rules" ]; then
            print_verbose 1 "creating temp dir for rules"
            print_verbose 2 "mkdir -p /tmp/nomad/$$/$target/rules"
            mkdir -p /tmp/nomad/$$/$target/rules

            print_verbose 1 "decompressing rules file $file_rules"
            print_verbose 2 "tar --extract --auto-compress --directory /tmp/nomad/$$/$target --file /tmp/nomad/$$/$target/$file_rules"
            tar --extract --auto-compress --directory /tmp/nomad/$$/$target --file /tmp/nomad/$$/$target/$file_rules
          fi

          if [ $override = true ]; then
            if [ -f /tmp/nomad/$$/$target/rules/pre ]; then
              print_verbose 1 "overriding pre script for $target"
              
              if [ $backup = true ]; then
                print_verbose 2 "cp -b -f /tmp/nomad/$$/$target/rules/pre $user_home/.config/nomad/rules/$target"
                [ -f $user_home/.config/nomad/rules/$target/pre ] && backuped_files="$backuped_files $user_home/.config/nomad/rules/$target/pre"
                cp -b -f /tmp/nomad/$$/$target/rules/pre $user_home/.config/nomad/rules/$target
              else
                print_verbose 2 "cp -f /tmp/nomad/$$/$target/rules/pre $user_home/.config/nomad/rules/$target"
                cp -f /tmp/nomad/$$/$target/rules/pre $user_home/.config/nomad/rules/$target
              fi
            fi

            if [ -f /tmp/nomad/$$/$target/rules/files ]; then
              print_verbose 1 "overriding files file for $target"
              
              if [ $backup = true ]; then
                print_verbose 2 "cp -b -f /tmp/nomad/$$/$target/rules/files $user_home/.config/nomad/rules/$target"
                [ -f $user_home/.config/nomad/rules/$target/files ] && backuped_files="$backuped_files $user_home/.config/nomad/rules/$target/files"
                cp -b -f /tmp/nomad/$$/$target/rules/files $user_home/.config/nomad/rules/$target
              else
                print_verbose 2 "cp -f /tmp/nomad/$$/$target/rules/files $user_home/.config/nomad/rules/$target"
                cp -f /tmp/nomad/$$/$target/rules/files $user_home/.config/nomad/rules/$target
              fi
            fi

            if [ -f /tmp/nomad/$$/$target/rules/post ]; then
              print_verbose 1 "overriding post script for $target"
              
              if [ $backup = true ]; then
                print_verbose 2 "cp -b -f /tmp/nomad/$$/$target/rules/post $user_home/.config/nomad/rules/$target"
                [ -f $user_home/.config/nomad/rules/$target/post ] && backuped_files="$backuped_files $user_home/.config/nomad/rules/$target/post"
                cp -b -f /tmp/nomad/$$/$target/rules/post $user_home/.config/nomad/rules/$target
              else
                print_verbose 2 "cp -f /tmp/nomad/$$/$target/rules/post $user_home/.config/nomad/rules/$target"
                cp -f /tmp/nomad/$$/$target/rules/post $user_home/.config/nomad/rules/$target
              fi
            fi
          fi
        fi

        pre_ret=0

        if [ $pre = true -a -f /tmp/nomad/$$/$target/rules/pre ]; then
          print_verbose 1 "executing pre script for $target"
          print_verbose 2 "/tmp/nomad/$$/$target/rules/pre"
          chmod +x /tmp/nomad/$$/$target/rules/pre
          /tmp/nomad/$$/$target/rules/pre 2> /tmp/nomad/$$/$target/pre.stderr
          pre_ret=$?
          
          if [ -s /tmp/nomad/$$/$target/pre.stderr ]; then
            cat /tmp/nomad/$$/$target/pre.stderr
          fi
          
          if [ $(echo "$pre_ret%2"|bc) = 0 ]; then
            echo "pre script for target $target exited with some error that prevents file copy for this target."
          fi
        fi

        #if the pre script wants to abort the rest of the action, it shall to return 1
        #if the pre script wants to abort only the copy of file but still execute the post script, it shall return an odd number greater than 1
        #whatever is the return of pre, it will be passed to post as its first argument (if it is different of 1)

        #if will copy user files and if pre_ret is even number
        if [ $user_files = true ] && [ $(echo "$pre_ret%2"|bc) = 0 ]; then
          file_user=$(ls /tmp/nomad/$$/$target/user*)

          if [ -n "$file_user" ]; then
            print_verbose 1 "decompressing user files for $target"
            
            if [ $backup = true ]; then
              print_verbose 2 "tar --backup --extract --auto-compress --directory $user_home --file /tmp/nomad/$$/$target/$file_user"
              backuped_files="$backuped_files $(tar --list --file /tmp/nomad/$$/$target/$file_user)"
              tar --backup --extract --auto-compress --directory $user_home --file /tmp/nomad/$$/$target/$file_user
            else
              print_verbose 2 "tar --extract --auto-compress --directory $user_home --file /tmp/nomad/$$/$target/$file_user"
              tar --extract --auto-compress --directory $user_home --file /tmp/nomad/$$/$target/$file_user
            fi
          fi
        fi

        #if will copy root files and if pre_ret is even number
        if [ $root_files = true ] && [ $(echo "$pre_ret%2"|bc) = 0 ]; then
          file_root=$(ls /tmp/nomad/$$/$target/root*)

          if [ -n "$file_root" ]; then
            print_verbose 1 "decompressing root files for $target"
            
            if [ $backup = true ]; then
              print_verbose 2 "tar --backup --extract --auto-compress --directory / --file /tmp/nomad/$$/$target/$file_root"
              backuped_files="$backuped_files $(tar --list --file /tmp/nomad/$$/$target/$file_root)"
              tar --backup --extract --auto-compress --directory / --file /tmp/nomad/$$/$target/$file_root
            else
              print_verbose 2 "tar --extract --auto-compress --directory / --file /tmp/nomad/$$/$target/$file_root"
              tar --extract --auto-compress --directory / --file /tmp/nomad/$$/$target/$file_root
            fi
          fi
        fi

        #if will execute post and if pre_ret is different of 1
        if [ $post = true -a -f /tmp/nomad/$$/$target/rules/post ] && [ $pre_ret != 1 ]; then
          print_verbose 1 "executing post script for $target"
          print_verbose 2 "/tmp/nomad/$$/$target/rules/post"
          chmod +x /tmp/nomad/$$/$target/rules/post
          /tmp/nomad/$$/$target/rules/post $pre_ret 2> /tmp/nomad/$$/$target/post.stderr
          post_ret=$?
          
          if [ -s /tmp/nomad/$$/$target/post.stderr ]; then
            cat /tmp/nomad/$$/$target/post.stderr
          fi
        fi

        if [ $backup = true ] && [ $(echo "$pre_ret%2"|bc) = 0 ] && [ $post_ret = 1 ]; then
          echo "post script for target $target exited with some error that demands the file copies being reversed."
          backuped_files="$(echo $backuped_files|sed -e 's/^[[:space:]]//' -e 's/[[:space]]\$//')"

          for file in $backuped_files; do
            last_file=$(ls $file*|tail -n 1)
            print_verbose 1 "reverting backup for file $file"
            print_verbose 2 "mv -f $last_file $file"
            mv -f $last_file $file
          done
        fi

        rm -R /tmp/nomad/$$/$target
      elif [ $action = "merge1" -a $all = false ]; then
        tar --extract --file $input --directory /tmp/nomad/$$ $target
      fi
    done

    if [ $action = "pack" -o $action = "merge2" ]; then
      if [ -n "$output" ]; then
        name=$output
      else
        host=$(hostname)
        user=$USER
        datetime=$(date +"$date_format-$time_format")
        name="$host-$user-$target-$datetime.nomad.$suffix"

        if [ $all = true ]; then
          name="$host-$user-all-$targets_count-$datetime.nomad.$suffix"
        elif [ $targets_count -gt 1 ]; then
          name="$host-$user-$targets_count-$datetime.nomad.$suffix"
        fi
      fi

      targets_files="$(echo $targets_files|sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      echo "" >> /tmp/nomad/$$/MANIFEST
      echo "$targets_files" >> /tmp/nomad/$$/MANIFEST
      print_verbose 1 "creating package $name"
      print_verbose 2 "tar --create --auto-compress --file /tmp/nomad/$$/$name --directory /tmp/nomad/$$ MANIFEST $targets_files"
      tar --create --auto-compress --file /tmp/nomad/$$/$name --directory /tmp/nomad/$$ MANIFEST $targets_files

      print_verbose 1 "moving package $name to $PWD"
      print_verbose 2 "mv /tmp/nomad/$$/$name $PWD"
      mv /tmp/nomad/$$/$name $PWD
    fi
  fi

  default_vars
}

default_vars

while [ -n "$1" ]; do
  case $1 in
    -h|--help) action="usage" ;;
    -o|--output) shift
                 output=$1
                 ;;
    -bz2|--bzip2) compression="TBZ2" ;;
    -gz|--gzip) compression="TGZ" ;;
    --no-files) files=false 
                user_files=false
                root_files=false
                ;;
    --no-user-files) user_files=false ;;
    --no-root-files) root_files=false ;;
    --no-pre) pre=false ;;
    --no-post) post=false ;;
    --no-rules) rules=false ;;
    --exit-on-error) EXIT_ON_ERROR=true ;;
    -v|--verbose) if [ $2 -ge 0 ] && [ $2 -le $VERBOSE_MAX ]; then
                    VERBOSE=$2
                    shift
                  else
                    VERBOSE=$(($VERBOSE+1))
                  fi
                  ;;
    --override-rules) override=true ;;
    -H|--user-home) shift
                    user_home=$1
                    ;;
    -b|--backup) backup=true ;;
    [Aa][Ll][Ll]) all=true ;;
    -l|--list) [ -n "$action" ] && process_action
               action="list"
               ;;
    -n|--new) [ -n "$action" ] && process_action
              action="new"
              ;;
    -s|--strip) [ -n "$action" ] && process_action
                action="strip"
                ;;
    -p|--pack) [ -n "$action" ] && process_action
               action="pack"
               ;;
    -u|--unpack) [ -n "$action" ] && process_action
                 action="unpack"
                 ;;
    -m|--merge) [ -n "$action" ] && process_action
                action="merge1"
                ;;
    *)
       if [ ! -f $1 ]; then
         targets="$targets $1"
       else
         if [ "$action" = "new" -o "$action" = "strip" -o "$action" = "pack" ]; then
           stderr "action $action does not permit the use of file $1"
           [ $EXIT_ON_ERROR = true ] && exit $BAD_ARGS
         else
           if [ -n "$action" -a -n "$input" ]; then
             old_action=$action
             process_action
             action=$old_action
           fi

           input=$1
         fi
       fi
       ;;
  esac
  shift
done

if [ -z "$action" ]; then
  action="usage"
elif [ "$action" = "merge1" ]; then
  process_action
  action="merge2"
  input=""
  targets=""
fi

[ -n "$action" ] && process_action

if [ -d /tmp/nomad/$$ ]; then
  print_verbose 1 "removing temp dir"
  print_verbose 2 "rm -R /tmp/nomad/$$"
  rm -R /tmp/nomad/$$
fi

exit 0
