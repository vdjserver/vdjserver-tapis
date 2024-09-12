"""
VDJServer Tools
"""

#
# vdjserver.py
# Main function
#
# VDJServer Analysis Portal
# Repertoire calculations, comparisons and summaries
# https://vdjserver.org
#
# Copyright (C) 2020-2022 The University of Texas Southwestern Medical Center
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

from __future__ import print_function
import sys
import argparse
import os

from tapipy.tapis import Tapis

# modules
from vdjserver import __version__
import vdjserver.defaults
import vdjserver.tokens
import vdjserver.files
import vdjserver.apps

def init_tapis(token):
    try:
        if token:
            tapis_obj = Tapis(base_url='https://' + vdjserver.defaults.tapis_host, access_token=token)
        elif os.environ['JWT']:
            tapis_obj = Tapis(base_url='https://' + vdjserver.defaults.tapis_host, access_token=os.environ['JWT'])
        else:
            print('Missing access token.')
            sys.exit(1)
    except:
        print('Error initializing tapis with access token.')
        sys.exit(1)

    return tapis_obj

def token_get_cmd(username, password=None, system_id=None, token=None):
    #tapis_obj = init_tapis(token)
    return vdjserver.tokens.get_token(username, password)

def files_list_cmd(path, system_id=None, token=None):
    if system_id is None:
        system_id = vdjserver.defaults.storage_system_id
    print(system_id)
    tapis_obj = init_tapis(token)
    return vdjserver.files.files_list(tapis_obj, system_id, path)

def apps_list_cmd(system_id=None, token=None):
    tapis_obj = init_tapis(token)
    return vdjserver.apps.apps_list(tapis_obj)

def define_args():
    """
    Define commandline arguments

    Returns:
      argparse.ArgumentParser: argument parser.
    """
    parser = argparse.ArgumentParser(add_help=False,
                                     description='VDJServer utility commands.')
    group_help = parser.add_argument_group('help')
    group_help.add_argument('-h', '--help', action='help', help='show this help message and exit')
    group_help.add_argument('--version', action='version',
                            version='%(prog)s:' + ' %s' % __version__)
    group_help.add_argument('--token', action='store', dest='token',
                            help='''Manually provide token instead of using JWT environment variable.''')
    group_help.add_argument('--system', action='store', dest='system_id',
                            help='''System ID for operation.''')

    # Setup subparsers
    subparsers = parser.add_subparsers(title='subcommands', dest='command', metavar='')
    # TODO:  This is a temporary fix for Python issue 9253
    subparsers.required = True

    # Define arguments common to all subcommands
    common_parser = argparse.ArgumentParser(add_help=False)
    common_help = common_parser.add_argument_group('help')
    common_help.add_argument('--version', action='version',
                             version='%(prog)s:' + ' %s' % __version__)
    common_help.add_argument('-h', '--help', action='help', help='show this help message and exit')

    #
    # Subparser for Token operations
    #
    parser_token = subparsers.add_parser('token', parents=[common_parser],
                                         add_help=False,
                                         help='Token operations.',
                                         description='Token operations.')
    token_subparser = parser_token.add_subparsers(title='subcommands', metavar='')

    # Subparser for token operations
    parser_token = token_subparser.add_parser('get', parents=[common_parser],
                                            add_help=False,
                                            help='Get token.',
                                            description='Get token.')
    group_tokens = parser_token.add_argument_group('get token arguments')
    group_tokens.add_argument('username',type=str,help="Username")
    group_tokens.add_argument('-p', action='store', dest='password',
                              help='''Password.''')
    parser_token.set_defaults(func=token_get_cmd)

    #
    # Subparser for Meta operations
    #
    parser_meta = subparsers.add_parser('meta', parents=[common_parser],
                                         add_help=False,
                                         help='Meta database operations.',
                                         description='Meta database operations.')
    meta_subparser = parser_meta.add_subparsers(title='subcommands', metavar='')

    # Subparser for meta operations
    parser_meta = meta_subparser.add_parser('get', parents=[common_parser],
                                            add_help=False,
                                            help='Get token.',
                                            description='Get token.')
    group_meta = parser_meta.add_argument_group('get meta arguments')
    group_meta.add_argument('uuid',type=str,help="Meta uuid")

    #group_merge = parser_merge.add_argument_group('merge arguments')
    #group_merge.add_argument('-o', action='store', dest='out_file', required=True,
    #                          help='''Output file name.''')
    #group_merge.add_argument('--drop', action='store_true', dest='drop',
    #                          help='''If specified, drop fields that do not exist in all input files.
    #                               Otherwise, include all columns in all files and fill missing data 
    #                               with empty strings.''')
    #group_merge.add_argument('-a', nargs='+', action='store', dest='airr_files', required=True,
    #                         help='A list of AIRR rearrangement files.')
    #parser_merge.set_defaults(func=merge_cmd)

    # Subparser for File operations
    parser_files = subparsers.add_parser('files', parents=[common_parser],
                                            add_help=False,
                                            help='Tapis Files API operations.',
                                            description='Tapis Files API operations.')
    files_subparser = parser_files.add_subparsers(title='subcommands', metavar='')

    # Subparser to list files
    parser_files = files_subparser.add_parser('list', parents=[common_parser],
                                            add_help=False,
                                            help='List files.',
                                            description='List files.')
    group_files = parser_files.add_argument_group('list files arguments')
    group_files.add_argument('path',type=str,help="File path")
    parser_files.set_defaults(func=files_list_cmd)

    # Subparser for App operations
    parser_apps = subparsers.add_parser('apps', parents=[common_parser],
                                            add_help=False,
                                            help='Tapis Apps API operations.',
                                            description='Tapis Apps API operations.')
    apps_subparser = parser_apps.add_subparsers(title='subcommands', metavar='')

    # Subparser to list apps
    parser_apps = apps_subparser.add_parser('list', parents=[common_parser],
                                            add_help=False,
                                            help='List apps.',
                                            description='List apps.')
    group_apps = parser_apps.add_argument_group('list apps arguments')
    #group_apps.add_argument('path',type=str,help="appID")
    parser_apps.set_defaults(func=apps_list_cmd)

    return parser

def main():
    """VDJServer Tools"""
    parser = define_args()
    args = parser.parse_args()
    args_dict = args.__dict__.copy()
    del args_dict['command']
    del args_dict['func']

    if not args:
        args.print_help()
        sys.exit()

    # Call tool function
    result = args.func(**args_dict)

