#!/bin/sh
set -e
exec gosu nginxuser "$@"
