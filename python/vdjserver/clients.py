"""
Interface functions for Client operations
"""

# System imports
import json
import sys
import os
from tapipy.tapis import Tapis
import vdjserver.defaults

#### Clients ####
spacer = 3

def clients_list_cmd(system_id=None, token=None):
    fields = [ 'client_id', 'client_key', 'display_name', 'callback_url', 'owner']
    field_widths = [ len(obj) for obj in fields ]
    tapis_obj = vdjserver.defaults.init_tapis(token)
    res = tapis_obj.authenticator.list_clients()

    if len(res) > 0:
        # determine max widths
        for obj in res:
            for i in range(0, len(fields)):
                if len(obj.get(fields[i])) > field_widths[i]:
                    field_widths[i] = len(obj.get(fields[i]))
        # add spacer
        field_widths = [ n + spacer for n in field_widths ]

        # headers
        for i in range(0, len(fields)):
            value = fields[i]
            width = field_widths[i]
            print(f"{value:{width}}", end='')
        print(f"active")
        for i in range(0, len(fields)):
            width = field_widths[i] - spacer
            value = '-' * width
            print(f"{value:{width}}", end='')
            print(' ' * spacer, end='')
        print(f"------")

        # print values
        for obj in res:
            for i in range(0, len(fields)):
                value = obj.get(fields[i])
                width = field_widths[i]
                print(f"{value:{width}}", end='')
            value = str(obj.get('active'))
            width = 6
            print(f"{value:{width}}")
    else:
        print('no clients')
