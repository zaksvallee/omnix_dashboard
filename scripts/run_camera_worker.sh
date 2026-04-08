#!/bin/sh
# Run the ONYX camera worker with config from onyx.local.json
# Usage: ONYX_HIK_PASSWORD=yourpassword ./scripts/run_camera_worker.sh

CONFIG=config/onyx.local.json

export ONYX_SUPABASE_URL=$(cat $CONFIG | python3 -c "import sys,json; print(json.load(sys.stdin).get('SUPABASE_URL',''))")
export ONYX_SUPABASE_SERVICE_KEY=$(cat $CONFIG | python3 -c "import sys,json; print(json.load(sys.stdin).get('ONYX_SUPABASE_SERVICE_KEY',''))")
export ONYX_HIK_HOST=$(cat $CONFIG | python3 -c "import sys,json; print(json.load(sys.stdin).get('ONYX_HIK_HOST','192.168.0.117'))")
export ONYX_HIK_PORT=$(cat $CONFIG | python3 -c "import sys,json; print(json.load(sys.stdin).get('ONYX_HIK_PORT','80'))")
export ONYX_HIK_USERNAME=$(cat $CONFIG | python3 -c "import sys,json; print(json.load(sys.stdin).get('ONYX_HIK_USERNAME','admin'))")
export ONYX_HIK_KNOWN_FAULT_CHANNELS=$(cat $CONFIG | python3 -c "import sys,json; print(json.load(sys.stdin).get('ONYX_HIK_KNOWN_FAULT_CHANNELS','11'))")
export ONYX_CLIENT_ID=$(cat $CONFIG | python3 -c "import sys,json; print(json.load(sys.stdin).get('ONYX_CLIENT_ID','CLIENT-MS-VALLEE'))")
export ONYX_SITE_ID=$(cat $CONFIG | python3 -c "import sys,json; print(json.load(sys.stdin).get('ONYX_SITE_ID','SITE-MS-VALLEE-RESIDENCE'))")

dart run bin/onyx_camera_worker.dart
