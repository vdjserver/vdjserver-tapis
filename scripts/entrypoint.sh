#!/bin/bash
# entrypoint.sh

# Define tapis helper functions.
. /vdjserver-tapis/scripts/tapis_functions.sh

# Run the main container command.
exec "$@"
