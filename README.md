# nebula salt

Basic configuration for booting up a salt master that has minions communicate exclusively over [nebula](https://github.com/slackhq/nebula).

Bootstrapping a minion over nebula and then having it communicate over nebula lets the salt-master not be exposed to the public internet, or at least ensures there's a NAT that prevents it from receiving unexpected inbound connections.

## Setup

Setup is fairly adhoc, especially setting up the master. In the future, this could be improved.

Some binaries are checked into the repo to make this flow a bit easier. You can always grab the latest from the latest nebula release on github .

### nebula

Follow the nebula quickstart guide in the readme. Note that `ca.crt` should be everywhere and `ca.key` is extremely sensitive.

### Master

Note that all salt entries containing GPG encrypted data will need to be regenerated. `grep -r PGP` should find everything, typically nebula certificates that need to get reissused using your CA.

1. (working within `master-config`)
1. copy master to /etc/master
1. `sudo apt install salt-master`
1. run nebula on master: `sudo nebula -config config.yml` (optionally, configure as a service)
1. Put `salt` directory in /srv/salt
1. Generate gpg keys: (from https://r-pufky.github.io/docs/configuration-management/saltstack/salt-master/gpg.html)
    - mkdir -p /etc/salt/gpgkeys
    - chmod 0700 /etc/salt/gpgkeys
    - gpg --gen-key --homedir /etc/salt/gpgkeys
    - gpg --homedir /etc/salt/gpgkeys --armor --export > salty_public_key.gpg
1. Restart master: `sudo systemctl restart salt-master.service`
1. Make sure master is happy: `sudo systemctl status salt-master.service`

### Minions

1. (working within `minion-bootstrap`)
1. Boot up a minion with a reasonably new debian base image(bullseye known to work well)
1. Issue certs and copy data using `pre-bootstrap.sh`
    - ie, `./pre-bootstrap.sh 100 kyle@192.168.100.9 20`
    - (first numerical argument is temporary index in network; second numerical argument is permanent, post-highstate, index in network)
    - Note that this issues two flavors of credentials, temporary and permanent. If you wanted to use group-based firewalls, which nebula supports in `config.yml`, you could easily restrict the groups of either certificate.
1. Include cert and ENCRYPTED key in nebula pillar init.sls with the hostname matching the planned hostname.
    - ie, `cat permanent.key | gpg --homedir /etc/salt/gpgkeys --armor --batch --trust-model always --encrypt -r "master" > enc`
1. ssh into minion node and run `bootstrap.sh`
    - follow instructions, which includes accepting the key on the master; find the unaccepted key with `salt-key -l all` then accept it `salt-key -a $HOSTNAME`
    - you may have to run the bootstrap script twice as the minion may died on us.

At this point your minion should be up and communicating with salt via nebula.

## Troubleshooting

### salt failing to decrypt gpg

Dump the salt master logs using journalctl and see the lines where it says it failed to decrypt, look at the end of the line past the full PGP message.