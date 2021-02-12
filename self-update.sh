#!/usr/bin/env bash
cd $(dirname ${BASH_SOURCE})
git checkout -- .
git pull
git submodule update --init --recursive
git submodule foreach git pull origin master
