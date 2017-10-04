#!/usr/bin/env bash

s3cmd put mac s3://cdn.safedrive.io/ --recursive --exclude=.DS_Store --acl-public 
