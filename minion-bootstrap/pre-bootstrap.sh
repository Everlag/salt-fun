#!/bin/bash

set -e

index=$1
if [[ -z $index ]]
then
    echo 'index argument not provided, exiting'
    exit 1
fi
host=$2
if [[ -z $host ]]
then
    echo 'host argument not provided, exiting'
    exit 1
fi
permanent=$3
if [[ -z $permanent ]]
then
    echo 'permanent index argument not provided, exiting'
    exit 1
fi

# TODO: sign to only be able to access salt master!
echo 'signing temp'
./nebula-cert sign -ca-crt ca.crt -ca-key ca.key \
    -name "self" -ip "172.16.91.${index}/24"

echo 'signing perm'
./nebula-cert sign -ca-crt ca.crt -ca-key ca.key \
    -name "permanent" -ip "172.16.91.${permanent}/24"

echo 'encrypting perm'
cat permanent.key | gpg --homedir ~/Downloads/salt-key/ --armor --batch --trust-model always --encrypt -r "master" > enc

echo 'removing perm'
rm permanent.key

echo 'copying over bootstrap dependencies'
scp ca.crt $host:.
scp self.crt $host:.
scp self.key $host:.
scp bootstrap.sh $host:.
scp nebula $host:.
