#!/bin/bash

set -x
cp /config/scripts/calltracking.service /lib/systemd/system/
systemctl daemon-reload
systemctl enable --now calltracking.service
