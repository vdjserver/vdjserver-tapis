#!/bin/bash

# docker entrypoint
# entrypoint.sh

# bring in common settings
if [[ "x${VDJSERVER_TAPIS_BIN}" == "x" ]]; then
    VDJSERVER_TAPIS_BIN=/vdjserver-tapis/bin
fi

# Define tapis helper functions.
source ${VDJSERVER_TAPIS_BIN}/tapis_functions.sh

# Run the main container command.
exec "$@"
