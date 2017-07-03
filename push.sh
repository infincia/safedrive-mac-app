#!/usr/bin/env bash

set -e

rsync -rv --delete-during ./update/ root@infincia.com:/data/update/safedrive/
