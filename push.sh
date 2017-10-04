#!/usr/bin/env bash

set -e

rsync -rv --delete-during ./update/mac/ root@infincia.com:/data/update/safedrive/
