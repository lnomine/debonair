# Debonair

Debonair ensures you have an identical Debian base wherever you need it, taking inspiration from https://github.com/bohanyang/debi and incorporating significant changes to tailor it to my specific requirements.

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
