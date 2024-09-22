"""
Interface functions for Client operations
"""

# System imports
import json
import sys
import os
import itertools
from tapipy.tapis import Tapis
import vdjserver.defaults

#### Clients ####

def clients_list_cmd(system_id=None, token=None):
    fields = [ 'client_id', 'client_key', 'display_name', 'callback_url', 'owner']
    field_widths = [ len(obj) for obj in fields ]
    tapis_obj = vdjserver.defaults.init_tapis(token)
    res = tapis_obj.authenticator.list_clients()

    if len(res) > 0:
        # determine max widths
        for obj in res:
            for i in range(0, len(fields)):
                if len(str(obj.get(fields[i]))) > field_widths[i]:
                    field_widths[i] = len(str(obj.get(fields[i])))

        # add custom fields
        fields.append('active')
        field_widths.append(6)

        # headers
        vdjserver.defaults.print_table_headers(fields, field_widths)

        # print values
        for obj in res:
            vdjserver.defaults.print_table_row(fields, field_widths, obj)

    else:
        print('no clients')
