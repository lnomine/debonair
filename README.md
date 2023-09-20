# Debonair

Debonair helps with having a identical Debian base wherever you need it to be. Inspired by https://github.com/bohanyang/debi with notable changes to fit my needs.

## Installation

```bash
git clone https://github.com/lnomine/debonair.git
```

## Usage

```bash
./start.sh -h myhostname -o 0 -r 10000 -m my.http.repo

# -o 'override' if your netmask/gateway is considered as invalid by the Debian installer


# -r 'rootsize' in megabytes

# -m 'repo FQDN or IP', use IP if you're using -o
```

## Contributing

Most likely an internal project, pull requests might be considered.
