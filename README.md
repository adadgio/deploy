# 360medical deployment script

Deploy Symfony2 application without breaking end user service by using symlinks.

Supports assets, symlinks, cache clearing and all other common Sf2 post deploy tasks.

## Installation

```
cd /somewhere/convenient
wget https://github.com/adadgio/deploy/archive/1.2.zip && unzip 1.2.zip && rm 1.2.zip
chmod +x deploy.sh
sudo ln -s /somewhere/convenient/deploy.sh /usr/local/bin/deploy
```

## Prerequisites

Have the following files and directory in the Sf2 project.

```
deploy/
    include.txt (optional)
    exclude.txt
    conf-staging.cnf
    conf-staging.cnf (optional)
```

## Commands

Deploy to a new version or override existing version.

```
deploy --env=staging --version=2.2.1 --verbose
# deploy --e=staging -v=2.2.1
```

Rollback to a specific version.

```
deploy --env=staging --version=2.2.0 --rollback
```

Read remotely deployed live version vs local version.

```
deploy --env=staging --status
```

Clean older version (safe).

```
deploy --version=2.2.1 --env=staging --clean
```

## Caveheats

**Issues you might have**

Remote composer install might fail for several reasons, usually missing dependencies or installs.

- Make sure DBAL php mysql extension is installed
- Make sure global environments variables are set in .profile
- Make sure remote env variables are set in ~.ssh/environment, change PermitUserEnvironment yes in /etc/ssh/sshd_config and restart ssh

**Install to think about**

- Php extensions like mbstring, imagik, php-mysql,
- apt-get install acl

**Change a few php.ini values**
