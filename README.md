# Readme

## Installation
- Move the files into the desired locations
  - systemd-unit-files
  - script

### Script
Change the vars to connect to the instances in "tag.sh"

### Systemd-units
Reload systemd *systemctl daemon-reload** and check if it is executed correctly

## How it works
The script searches for tickets, that are tagged with "*spam*".
It takes the first article of a ticket and downloads it as raw .eml
Pipes it into rspamc

## Notes for rspamd in docker environment
If you execute rspamd in a docker container, please first check the name of it and change it accordingly.
