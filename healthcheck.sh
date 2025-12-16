#!/usr/bin/env bash

set -e

supervisorctl status sssd
supervisorctl status smbd

exit 0
