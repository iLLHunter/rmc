#!/bin/bash

# Config in rmc.config
source rtb.config

## Requirements
# tmux

function server_monitor() {
  while [[ 1 ]]
   do
    server_check
    sleep $server_monitor_wait_time
   done
}

function server_check() {
# Run a netcat check on the server port to see if it accepts connections. Grep the output looking for the "succeeded" message. If not found, server port is not responding. Log this and initiate a restart
  if [[ "$(nc 127.0.0.1 $server_port 2>&1 | grep succeeded)"  == "" ]]; then
    log "Server port not responding", "Attempting to restart."
    server_restart
  fi
}

function server_restart() {
  server_stop
  server_launch
}
function server_stop() {
  pkill -f $server_start 
# After the gentle kill, wait these seconds for the world to save & server to shutdown
  sleep $kill_sleep_seconds 
# Now drop the hammer
  pkill -9 -f $server_start
}
function server_launch() {
  mux="$(tmux has-session -t $tmux_session_name)"
  if [ $mux != 0 ]
    tmux new-session -d -s $tmux_session_name $server_start 
  else
    tmux send-keys -t $tmux_session_name $server_start Enter
  fi
}

function log() {
  echo "$(date) -- $1 | $2" >> $crashlog
  echo "" >> $crashlog
}


server_monitor &
tmux new-session -s $tmux_session_name $server_start
