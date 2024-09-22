"""
Interface functions for Files operations
"""

# System imports
import json
import sys
import os
from tapipy.tapis import Tapis
import vdjserver.defaults

#### Files ####

def files_list_cmd(path, system_id=None, token=None):
    if system_id is None:
        system_id = vdjserver.defaults.storage_system_id
    print(system_id)

    fields = [ 'nativePermissions', 'owner', 'group', 'size', 'lastModified', 'path', 'type' ]
    field_widths = [ len(obj) for obj in fields ]

    tapis_obj = vdjserver.defaults.init_tapis(token)
    res = tapis_obj.files.listFiles(systemId=system_id, path=path)
    #res = tapis_obj.authenticator.list_clients()

    if len(res) > 0:
        # determine max widths
        for obj in res:
            for i in range(0, len(fields)):
                if len(str(obj.get(fields[i]))) > field_widths[i]:
                    field_widths[i] = len(str(obj.get(fields[i])))

        # headers
        vdjserver.defaults.print_table_headers(fields, field_widths)

        # print values
        for obj in res:
            vdjserver.defaults.print_table_row(fields, field_widths, obj)

    else:
        print('no files')
