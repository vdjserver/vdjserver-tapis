"""
Default settings
"""

#
# defaults.py
# Default settings
#
# VDJServer Analysis Portal
# Repertoire calculations and comparison
# https://vdjserver.org
#
# Copyright (C) 2024 The University of Texas Southwestern Medical Center
#
# Author: Scott Christley <scott.christley@utsouthwestern.edu>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

import os
import sys
import itertools

from tapipy.tapis import Tapis

storage_system_id = "data-storage.vdjserver.org"

tapis_host = "vdjserver.tapis.io"
if os.environ['tapis_default_host']:
    tapis_host = os.environ['tapis_default_host']

def init_tapis(token):
    try:
        if token:
            tapis_obj = Tapis(base_url='https://' + tapis_host, access_token=token)
        elif os.environ['JWT']:
            tapis_obj = Tapis(base_url='https://' + tapis_host, access_token=os.environ['JWT'])
        else:
            print('Missing access token.')
            sys.exit(1)
    except:
        print('Error initializing tapis with access token.')
        sys.exit(1)

    return tapis_obj

# standard tables
spacer = 3

def print_table_intro():
    pass

def print_table_headers(fields, field_widths):
    for (value, width) in zip(fields, field_widths):
        width += spacer
        print(f"{value:{width}}", end='')
    print('')
    for i in range(0, len(fields)):
        width = field_widths[i]
        value = '-' * width
        print(f"{value:{width}}", end='')
        print(' ' * spacer, end='')
    print('')

def print_table_row(fields, field_widths, obj):
    for (field, width) in zip(fields, field_widths):
        value = str(obj.get(field))
        width += spacer
        print(f"{value:{width}}", end='')
    print('')
