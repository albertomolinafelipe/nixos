#!/bin/bash
amixer sget Master | grep 'Mono:' | awk '{print $4}' | sed 's/\[\(.*\)%\]/\1/'

