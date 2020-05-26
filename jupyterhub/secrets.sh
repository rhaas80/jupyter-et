#!/bin/bash

# store / retrieve secrets in a file encrypted using ssh public keys
# the secrets file must be less than 1024 bytes

# this is more or less what gpg does when one encrypts with a public key and
# multiple recipients

# this uses information from
# https://www.bjornjohansen.com/encrypt-file-using-ssh-key

set -e

# handle command line arguments
if [ "$1" = -d ] ; then
  action=decrypt
  shift
elif [ "$1" = -e ] ; then
  action=encrypt
  shift
fi

if [ $# -eq 2 ] ; then
  keyfile="$1"
  secretfile="$2"
else
  echo >/dev/stderr "usage: $0 [-e | -d] keyfile secretfile"
  exit 1
fi

if ! [ -r "$keyfile" ] ; then
  echo >/dev/stderr "Keyfile '$keyfile' is not readable"
  exit 1
fi

if ! [ -r "$secretfile" ] ; then
  echo >/dev/stderr "Secretfile '$secretfile' is not readable"
  exit 1
fi

# store or retrieve secret

if [ $action = encrypt ] ; then
  tmpdir=$(mktemp -d)
  n=1
  files=
  # for each key encrypt the secret once and store them all in a tar archive
  while read key ; do
    openssl rsautl -encrypt -oaep -pubin -inkey <(echo "$key" | ssh-keygen -e -m PKCS8 -f /dev/stdin) -in "$secretfile"  -out "$tmpdir/$n"
    files="$files $n"
    n=$(($n+1))
  done <"$keyfile"
  tar -c -C "$tmpdir" $files
  rm -r "$tmpdir"
elif [ $action = decrypt ] ; then
  # try and see if the private key and decrypt any of the files in the archive
  for fn in ""$(tar -t -f "$secretfile") ; do
    # for this to work the key must be readable to rsautl ie be in PKCS8 or
    # OpenSSH's private format (which is usually the case)
    if tar -O -x "$fn" -f "$secretfile" | openssl 2>/dev/null rsautl -decrypt -oaep -inkey "$keyfile" ; then
      exit 0
    fi
  done
  echo >/dev/stderr "Could not decrypt secretfile '$secretfile' using keyfile '$keyfile'"
  exit 1
else
  echo >/dev/stderr "Internal error: unknonw action $action"
fi
