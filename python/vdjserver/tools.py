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
import vdjserver.meta
import vdjserver.tokens
import vdjserver.clients
import vdjserver.files
import vdjserver.apps
import vdjserver.adc_cache
import vdjserver.jobs
import vdjserver.project

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

# def apps_list_cmd(system_id=None, token=None):
#     tapis_obj = init_tapis(token)
#     return vdjserver.apps.apps_list(tapis_obj)

# not used yet
#def define_token_args(subparser):

#
# Subparser for Client operations
#
def define_clients_args(subparsers, common_parser):
    parser_sub = subparsers.add_parser('clients', parents=[common_parser],
                                            add_help=False,
                                            help='Tapis Client API operations.',
                                            description='Tapis Client API operations.')
    group_subparser = parser_sub.add_subparsers(title='subcommands', metavar='')

    # Subparser to list clients
    parser_sub = group_subparser.add_parser('list', parents=[common_parser],
                                            add_help=False,
                                            help='List clients.',
                                            description='List clients.')
    parser_sub.set_defaults(func=vdjserver.clients.clients_list_cmd)

#
# Subparser for Project operations
#
def define_project_args(subparsers, common_parser):
    parser_project = subparsers.add_parser('project',
                                            parents=[common_parser],
                                            add_help=False,
                                            help='Project database operations.',
                                            description='Project database operations.')
    project_subparser = parser_project.add_subparsers(title='subcommands', metavar='')

     # Subparser for listing projects
    parser_list_metadata = project_subparser.add_parser('list', parents=[common_parser],
                                            add_help=False,
                                            help='List project metadata records.',
                                            description='Show metadata for all projects.')
    parser_list_metadata.add_argument('--format-json', dest='format_json', action='store_true', 
                                      help='Print full metadata in raw JSON format.')
    parser_list_metadata.set_defaults(func=vdjserver.meta.meta_list)


    # Subparser for getting metadata for a specific project
    parser_get_metadata = project_subparser.add_parser('meta-name', parents=[common_parser],
                                            add_help=False,
                                            help='Query metadata by name for project.',
                                            description='Query metadata for project with project uuid')
    group_get_metadata = parser_get_metadata.add_argument_group('get query meta arguments')
    group_get_metadata.add_argument('project_uuid', type=str, help="project identifier")
    group_get_metadata.add_argument('name', type=str, help="metadata type name (e.g., 'subject, repertoire')")
    parser_get_metadata.set_defaults(func=vdjserver.meta.get_metadata)

    # Subparser for getting metadata for a specific project
    parser_meta_get_by_uuid = project_subparser.add_parser('meta-uuid', parents=[common_parser],
                                            add_help=False,
                                            help='Get metadata by uuid for project.',
                                            description='Retrieve specific metadata for a project by UUID.\
                                                Requires both project UUID and metadata UUID.')
    group_meta_get_by_uuid = parser_meta_get_by_uuid.add_argument_group('meta_get_by_uuid arguments')
    group_meta_get_by_uuid.add_argument('project_uuid', type=str,help="project identifer")
    group_meta_get_by_uuid.add_argument('uuid',type=str, help="metadata identifer")
    parser_meta_get_by_uuid.set_defaults(func=vdjserver.meta.meta_get_by_uuid)
    
    # Subparser for creating a new project
    parser_create_project = project_subparser.add_parser('create',
                                                        parents=[common_parser],
                                                        add_help=False,
                                                        help='Create a new project.',
                                                        description='Create a new project by specifying a title or JSON file.')
    #Arguments added to this group are mutually exclusive, meaning the user can specify only one of them at a time, not multiple.
    group_parser_create_project = parser_create_project.add_mutually_exclusive_group(required=True)
    group_parser_create_project.add_argument('--title',type=str,help='Title of the new project.')
    group_parser_create_project.add_argument('--json-file',type=str,help='Path to JSON file containing project fields.')
    parser_create_project.set_defaults(func=vdjserver.project.create_project)

    
    # Subparser for adding a user to a project
    parser_add_user = project_subparser.add_parser('add-user',
                                                    parents=[common_parser],
                                                    add_help=False,
                                                    help='Add a user to a project.',
                                                    description='Add a user to a VDJServer project.')
    group_parser_add_user = parser_add_user.add_argument_group('Add user arguments')
    group_parser_add_user.add_argument('project_uuid', type = str, help='UUID of the project.')
    group_parser_add_user.add_argument('username', type = str, help='Username to add to the project.')
    parser_add_user.set_defaults(func=vdjserver.project.add_user_to_project)
    
    # Subparser for removing a user from a project
    parser_remove_user = project_subparser.add_parser('remove-user',
                                                    parents=[common_parser],
                                                    add_help=False,
                                                    help='Remove a user from a project.',
                                                    description='Remove a user from a VDJServer project.')

    group_parser_remove_user = parser_remove_user.add_argument_group('Remove user arguments')
    group_parser_remove_user.add_argument('project_uuid', type=str, help='UUID of the project.')
    group_parser_remove_user.add_argument('username', type=str, help='Username to remove from the project.')
    parser_remove_user.set_defaults(func=vdjserver.project.remove_user_from_project)

    # Subparser for 'export_metadata'
    parser_export_metadata = project_subparser.add_parser('export-metadata',  parents=[common_parser],
                                                       add_help=False,
                                                       help='Export AIRR metadata JSON.',
                                                       description='')
    group_parser_export_metadata = parser_export_metadata.add_argument_group("Export Metadata argument.")
    group_parser_export_metadata.add_argument('project_uuid', type=str, help="The project UUID.")
    parser_export_metadata.set_defaults(func= vdjserver.meta.export_metadata)
    
    # Subparser for 'import metadata'
    parser_import_metadata = project_subparser.add_parser('import-metadata',  parents=[common_parser],
                                                       add_help=False,
                                                       help='Import AIRR metadata JSON.',
                                                       description='Import AIRR metadata JSON.')
    group_parser_import_metadata = parser_import_metadata.add_argument_group("Import metadata arguments.")
    group_parser_import_metadata.add_argument('project_uuid', type=str, help="The project UUID.")
    group_parser_import_metadata.add_argument('metadata_file_path', type=str, help='Path to the metadata file to import.')
    group_parser_import_metadata.add_argument('operation', type=str, help='Operations to perform (e.g., append, replace).')
    parser_import_metadata.set_defaults(func= vdjserver.meta.import_metadata)
    
    
    # Subparser for export_table_metadata
    parser_export_table_metadata = project_subparser.add_parser('export-table',  parents=[common_parser],
                                                       add_help=False,
                                                       help='Export metadata table from project by its UUID and table name.',
                                                       description='Export metadata table from project by its UUID and table name')
    group_parser_export_table_metadata = parser_export_table_metadata.add_argument_group("Export metadata table arguments.")
    group_parser_export_table_metadata.add_argument('project_uuid', type=str, help="project identifier.")
    group_parser_export_table_metadata.add_argument('table_name', type=str, help="table name(e.g. values : subject, sample_processing).")
    parser_export_table_metadata.set_defaults(func= vdjserver.meta.export_table_metadata)
    
    
    # Subparser for import_table_metadata
    parser_import_table_metadata = project_subparser.add_parser('import-table', parents=[common_parser],
                                                        add_help=False,
                                                        help='Import metadata table to project by its UUID and table name.',
                                                        description='Import metadata table to project by its UUID and table name')
    group_parser_import_table_metadata = parser_import_table_metadata.add_argument_group("Import metadata table arguments.")
    group_parser_import_table_metadata.add_argument('project_uuid', type=str, help="Project identifier.")
    group_parser_import_table_metadata.add_argument('table_name', type=str, help="Table name (e.g. values: subject, sample_processing).")
    group_parser_import_table_metadata.add_argument('metadata_file_path', type=str, help="Path to the metadata file to import (in tsv format).")
    parser_import_table_metadata.set_defaults(func=vdjserver.meta.import_table_metadata)


#
# Subparser for Meta operations
#
# def define_meta_args(subparsers, common_parser):
#     parser_meta = subparsers.add_parser('meta', parents=[common_parser],
#                                          add_help=False,
#                                          help='Meta database operations.',
#                                          description='Meta database operations.')
#     meta_subparser = parser_meta.add_subparsers(title='subcommands', metavar='')
#    
    

#
# Subparser for File operations
#
def define_files_args(subparsers, common_parser):
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
    parser_files.set_defaults(func=vdjserver.files.files_list_cmd)
    
    
    # Subparser to make directory    
    # Define the 'mkdir' subcommand to create a new directory
    parser_files_mkdir = files_subparser.add_parser('mkdir', parents=[common_parser],
                                                    add_help=False,
                                                    help='Create a new directory.',
                                                    description='Create a new directory in the storage system.')
    # Group arguments related to directory creation
    group_files_mkdir = parser_files_mkdir.add_argument_group('Directory creation arguments')
    # Add an argument for the directory path
    group_files_mkdir.add_argument('path', type=str, help="Path of the new directory (e.g., '/folderA/folderB/newDirectory')")
    # Set the function to be called when the subcommand is invoked
    parser_files_mkdir.set_defaults(func=vdjserver.files.tapis_files_mkdir)

    # Add the 'upload' subcommand to the parser
    parser_files_upload = files_subparser.add_parser('upload', parents=[common_parser],
                                                    add_help=False,
                                                    help='Upload a file.',
                                                    description='Upload a file to the specified path.')
    # Group arguments related to uploading a file
    group_files_upload = parser_files_upload.add_argument_group('upload file arguments')
    # Add arguments for the source file and destination path
    group_files_upload.add_argument('source_file_path', type=str, help="Path to the source file (e.g., 'someFile.txt')")
    group_files_upload.add_argument('dest_file_path', type=str, help="Destination path (e.g., '/folderA/folderB/someFile.txt')")
    # Set the default function to handle the upload
    parser_files_upload.set_defaults(func=vdjserver.files.tapis_files_upload)
    
    
    # Define the 'delete' subcommand to delete a file
    parser_files_delete = files_subparser.add_parser('delete', parents=[common_parser],
                                                    add_help=False,
                                                    help='Delete a file.',
                                                    description='Delete a file from the storage system.')
    # Group arguments related to file deletion
    group_files_delete = parser_files_delete.add_argument_group('File deletion arguments')
    # Add an argument for the file path
    group_files_delete.add_argument('path', type=str, help="Path of the file to be deleted (e.g., '/folderA/folderB/someFile.txt')")
    # Optional argument for specifying the storage system
    group_files_delete.add_argument('--system_id', type=str, help="Storage system ID (optional, default will be used if not provided)")
    # Set the function to be called when the subcommand is invoked
    parser_files_delete.set_defaults(func=vdjserver.files.tapis_files_delete)

    
    ##Files permissions
    
    # Define the 'get-permission' subcommand to get file permissions
    parser_files_get_permission = files_subparser.add_parser('get-permission', parents=[common_parser],
                                                              add_help=False,
                                                              help='Get file permissions.',
                                                              description='Get the permissions for a file or directory on the storage system.')

    # Group arguments related to file permission retrieval
    group_files_get_permission = parser_files_get_permission.add_argument_group('File permission arguments')
    # Add an argument for the file path
    group_files_get_permission.add_argument('path', type=str, help="Path of the file or directory (e.g., '/folderA/folderB/someFile.txt')")
    # Optional argument for specifying the username (if not provided, the requester's username will be used)
    group_files_get_permission.add_argument('--username', type=str, help="Username whose permissions are to be retrieved (optional)")
    # Optional argument for specifying the storage system
    group_files_get_permission.add_argument('--system_id', type=str, help="Storage system ID (optional, default will be used if not provided)")
    # Set the function to be called when the subcommand is invoked
    parser_files_get_permission.set_defaults(func=vdjserver.files.tapis_files_get_permission)
    
    
    # Subparser for granting file permissions
    parser_files_grant_perms = files_subparser.add_parser('grant-permission', parents=[common_parser],
                                                        add_help=False,
                                                        help='Grant permissions to a user for a file or directory.',
                                                        description='Grant permissions (READ or MODIFY) to a user for a file or directory in the storage system.')
    # Group arguments related to granting permissions
    group_files_grant_perms = parser_files_grant_perms.add_argument_group('Grant permission arguments')
    # Add an argument for the file path
    group_files_grant_perms.add_argument('path', type=str, help="Path of the file or directory (e.g., '/folderA/folderB/file.txt')")
    # Add an argument for the username
    group_files_grant_perms.add_argument('username', type=str, help="Username to whom permission will be granted.")
    # Add an argument for specifying the permission type (READ or MODIFY)
    group_files_grant_perms.add_argument('permission', type=str, choices=['READ', 'MODIFY'], help="Permission type to grant (READ or MODIFY).")
    # Optional argument for specifying the storage system
    group_files_grant_perms.add_argument('--system_id', type=str, help="Storage system ID (optional, default will be used if not provided)")
    # Set the function to be called when the subcommand is invoked
    parser_files_grant_perms.set_defaults(func=vdjserver.files.tapis_files_grant_permission)
    

    # Subparser for revoking permissions
    revoke_permission_parser = files_subparser.add_parser('revoke-permission', parents=[common_parser],
                                                     add_help=False,
                                                     help='Revoke permissions for a user on a file or directory.',
                                                     description='Revoke permissions for a user for a file or directory in the storage system.')
    
    # Group arguments related to revoking permissions
    group_revoke_permission = revoke_permission_parser.add_argument_group('Revoke Permission Arguments')
    # Path of the file or directory
    group_revoke_permission.add_argument('path', type=str, help="Path of the file or directory (e.g., '/folderA/folderB/someFile.txt')")
    # Username to whom permission will be revoked
    group_revoke_permission.add_argument('username', type=str, help="Username whose permission will be revoked")
    # Optional argument for the system ID
    group_revoke_permission.add_argument('--system_id', type=str, help="Storage system ID (optional, default will be used if not provided)")
    # Set the function to be called when the subcommand is invoked
    revoke_permission_parser.set_defaults(func=vdjserver.files.tapis_files_revoke_permission)
    

    # Subparser for downloading a file or directory as a ZIP
    parser_files_download = files_subparser.add_parser('download', parents=[common_parser],
                                                    add_help=False,
                                                    help='Download a file or directory as a ZIP.',
                                                    description='Download a file or directory from the storage system as a ZIP file.')
    # Group arguments related to file download
    group_files_download = parser_files_download.add_argument_group('Download arguments')
    # Add an argument for the file or directory path
    group_files_download.add_argument('path', type=str, help="Path of the file or directory to be downloaded (e.g., '/folderA/folderB/file.txt')")
    # Optional argument for specifying the output filename
    group_files_download.add_argument('--output_filename', type=str, help="The name of the file to save the ZIP as (optional, defaults to path's last part with .zip)")
    # Optional argument for specifying the storage system
    group_files_download.add_argument('--system_id', type=str, help="Storage system ID (optional, default will be used if not provided)")
    # Set the function to be called when the subcommand is invoked
    parser_files_download.set_defaults(func=vdjserver.files.tapis_files_download)

#
# Subparser for Postit operations
#
def define_postits_args(subparsers, common_parser):
    parser_postits = subparsers.add_parser('postits', parents=[common_parser],
                                            add_help=False,
                                            help='Tapis Files Postits API operations.',
                                            description='Tapis Files Postits API operations.')
    postits_subparser = parser_postits.add_subparsers(title='subcommands', metavar='')


    # Subparser to list postits
    parser_postits = postits_subparser.add_parser('list', parents=[common_parser],
                                            add_help=False,
                                            help='List postits.',
                                            description='List postits.')
    group_postits = parser_postits.add_argument_group('list postits arguments')
    group_postits.add_argument('--uuid', type=str, help="List postit by uuid")
    parser_postits.set_defaults(func=vdjserver.files.postits_list_cmd)


def define_adc_cache_args(subparsers, common_parser):
    parser_cache = subparsers.add_parser('adc_cache', parents=[common_parser],
                                            add_help=False,
                                            help='ADC Download Cache API operations.',
                                            description='ADC Download Cache API operations.')
    cache_subparser = parser_cache.add_subparsers(title='subcommands', metavar='')


    # Subparser to get ADC Download Cache status
    parser_cache = cache_subparser.add_parser('status', parents=[common_parser],
                                            add_help=False,
                                            help='Get ADC Download Cache status.',
                                            description='Get ADC Download Cache status.')
    parser_cache.set_defaults(func=vdjserver.adc_cache.cache_get_status_cmd)

    # Subparser to update ADC Download Cache status
    parser_cache = cache_subparser.add_parser('update', parents=[common_parser],
                                            add_help=False,
                                            help='Update ADC Download Cache status.',
                                            description='Update ADC Download Cache status.')
    group_cache = parser_cache.add_argument_group('update ADC Download Cache arguments')
    group_cache.add_argument('update', type=str, help="Update ADC Download Cache status")
    parser_cache.set_defaults(func=vdjserver.adc_cache.cache_update_status_cmd)


#
# Subparser for App operations
#
def define_apps_args(subparsers, common_parser):
    parser_apps = subparsers.add_parser('apps', parents=[common_parser],
                                        add_help=False,
                                        help='Tapis Apps API operations.',
                                        description='Tapis Apps API operations.')
    apps_subparser = parser_apps.add_subparsers(title='subcommands', metavar='')

    # Subparser to list apps
    parser_apps_list = apps_subparser.add_parser('list', parents=[common_parser],
                                                add_help=False,
                                                help='List apps.',
                                                description='List apps.')
    group_parser_apps_list = parser_apps_list.add_argument_group('List apps')
    group_parser_apps_list.add_argument('--all', action='store_true', help="Show all app versions.")
    parser_apps_list.set_defaults(func=vdjserver.apps.apps_list)

    # Subparser for retrieving app details for given app id and version
    parser_apps_get_details = apps_subparser.add_parser('get', parents=[common_parser],
                                                        add_help=False,
                                                        help='Get details for an app.',
                                                        description='Retrieve the details for a given app and their version.')
    group_parser_apps_get_details = parser_apps_get_details.add_argument_group('Get app details arguments')
    group_parser_apps_get_details.add_argument('app_id', type=str, help="App Name/ID")
    group_parser_apps_get_details.add_argument('app_version', type=str, help="App Version")
    parser_apps_get_details.set_defaults(func=vdjserver.apps.get_app_details)

    # Subparser for creating a new app version
    parser_create_app_version = apps_subparser.add_parser('create', parents=[common_parser],
                                                          add_help=False,
                                                          help='Create a new app version.',
                                                          description='Create a new app version.')
    group_parser_create_app_version = parser_create_app_version.add_argument_group('Create app version arguments')
    group_parser_create_app_version.add_argument('json_file', type=str, help="JSON file with app version details")
    parser_create_app_version.set_defaults(func=vdjserver.apps.create_app_version)
    
    
    # Subparser for updating apps
    parser_apps_update = apps_subparser.add_parser('update', parents=[common_parser],
                                                   add_help=False,
                                                   help='Update apps.',
                                                   description='Update apps.')
    group_parser_apps_update = parser_apps_update.add_argument_group('App update arguments')
    group_parser_apps_update.add_argument('app_name', type=str, help="App Name/ID")
    group_parser_apps_update.add_argument('app_version', type=str, help="App Version")
    group_parser_apps_update.add_argument('json_file', type=str, help="JSON file with app version details")
    parser_apps_update.set_defaults(func=vdjserver.apps.apps_update)
    
    # Subparser for deleting an app
    parser_apps_delete = apps_subparser.add_parser('delete', parents=[common_parser],
                                                add_help=False,
                                                help='Delete an app.',
                                                description='Delete an app version.')
    group_parser_apps_delete = parser_apps_delete.add_argument_group('Delete app arguments')
    group_parser_apps_delete.add_argument('app_name', type=str, help="App Name/ID")
    parser_apps_delete.set_defaults(func=vdjserver.apps.delete_app)

    # Subparser for retrieving app history
    parser_apps_get_history = apps_subparser.add_parser('history', parents=[common_parser],
                                                        add_help=False,
                                                        help='Get history of changes for an app.',
                                                        description='Retrieve the history of changes for a given app.')
    group_parser_apps_get_history = parser_apps_get_history.add_argument_group('Get app history arguments')
    group_parser_apps_get_history.add_argument('app_id', type=str, help="App Name/ID")
    parser_apps_get_history.set_defaults(func=vdjserver.apps.get_app_history)

    # Subparser for changing the owner of an app
    parser_apps_change_owner = apps_subparser.add_parser('change_owner', parents=[common_parser],
                                                        add_help=False,
                                                        help='Change the owner of an app.',
                                                        description='Change the owner of an app for all versions.')
    group_parser_apps_change_owner = parser_apps_change_owner.add_argument_group('Change app owner arguments')
    group_parser_apps_change_owner.add_argument('app_id', type=str, help="App ID/Name")
    group_parser_apps_change_owner.add_argument('user_name', type=str, help="New app owner (User Name)")
    parser_apps_change_owner.set_defaults(func=vdjserver.apps.change_app_owner)
    

#
# Subparser for job operations
#
def define_jobs_args(subparsers, common_parser):
    parser_jobs = subparsers.add_parser('jobs', parents=[common_parser],
                                            add_help=False,
                                            help='Tapis Jobs API operations.',
                                            description='Tapis Jobs API operations.')
    jobs_subparser = parser_jobs.add_subparsers(title='subcommands', metavar='')
    
    # Subparser to list all jobs files
    parser_jobs_list = jobs_subparser.add_parser('list', parents=[common_parser],
                                            add_help=False,
                                            help='List Jobs.',
                                            description='Retrieve the list of Jobs.')
    group_parser_jobs_list = parser_jobs_list.add_argument_group('Job list arguments')
    group_parser_jobs_list.add_argument('--list-type', choices=["MY_JOBS", "SHARED_JOBS", "ALL_JOBS"], default="ALL_JOBS", help="Type of job list to retrieve.")
    group_parser_jobs_list.add_argument('--limit', type=int, default=25, help="Limit the number of jobs returned.")
    group_parser_jobs_list.add_argument('--skip', type=int, help="Number of jobs to skip.")
    group_parser_jobs_list.add_argument('--order-by', type=str, default="created(desc)", help="Order the list by a field.")
    parser_jobs_list.set_defaults(func=vdjserver.jobs.get_job_list)
    
    # Subparser for submitting a job
    parser_job_submit = jobs_subparser.add_parser('submit', parents=[common_parser],
                                                     add_help=False,
                                                     help="Submit Job",
                                                     description="Submit Jobs using Json file.")
    
    group_parser_job_submit = parser_job_submit.add_argument_group("Job submitting arguments")
    group_parser_job_submit.add_argument('json_file', type=str, help="JSON file with Job Name, appID and, appVersion and other details")
    parser_job_submit.set_defaults(func=vdjserver.jobs.submit_job)

    # Subparser for getting job status by UUID
    parser_job_status = jobs_subparser.add_parser('status', parents=[common_parser],
                                                add_help=False,
                                                help="Get Job Status",
                                                description="Retrieve the status of a job by UUID.")
    group_parser_job_status = parser_job_status.add_argument_group("Job Status Arguments")
    group_parser_job_status.add_argument('job_uuid', type=str, help="The UUID of the job to get the status for.")
    group_parser_job_status.add_argument('--pretty', action='store_true', help="Format the output nicely.")
    parser_job_status.set_defaults(func=vdjserver.jobs.get_job_status)
    
    
    # Subparser to get job history by job UUID
    parser_jobs_history = jobs_subparser.add_parser('history', parents=[common_parser],
                                                    add_help=False,
                                                    help='Retrieve Job History by UUID.',
                                                    description='Retrieve the history of a job by its UUID.')
    group_parser_jobs_history = parser_jobs_history.add_argument_group('Job History arguments')
    group_parser_jobs_history.add_argument('job_uuid', type=str, help="UUID of the job to retrieve the history for.")
    group_parser_jobs_history.add_argument('--limit', type=int, help="Limit the number of history entries returned.")
    group_parser_jobs_history.add_argument('--skip', type=int, help="Number of history entries to skip.")
    group_parser_jobs_history.add_argument('--pretty', action='store_true', help="Pretty print the response.")
    parser_jobs_history.set_defaults(func=vdjserver.jobs.get_job_history)
        
    # Subparser to get a job by job UUID
    parser_jobs_get = jobs_subparser.add_parser('get', parents=[common_parser],
                                                add_help=False,
                                                help='Retrieve Job by UUID.',
                                                description='Retrieve the details of a job by its UUID.')
    group_parser_jobs_get = parser_jobs_get.add_argument_group('Job arguments')
    group_parser_jobs_get.add_argument('job_uuid', type=str, help="UUID of the job to retrieve.")
    group_parser_jobs_get.add_argument('--pretty', action='store_true', help="Pretty print the response.")
    parser_jobs_get.set_defaults(func=vdjserver.jobs.get_job)    
    
    # Subparser to cancel a job by job UUID
    parser_jobs_cancel = jobs_subparser.add_parser('cancel', parents=[common_parser],
                                                add_help=False,
                                                help='Cancel Job by UUID.',
                                                description='Cancel a previously submitted job by its UUID.')
    group_parser_jobs_cancel = parser_jobs_cancel.add_argument_group('Cancel Job arguments')
    group_parser_jobs_cancel.add_argument('job_uuid', type=str, help="UUID of the job to cancel.")
    group_parser_jobs_cancel.add_argument('--pretty', action='store_true', help="Pretty print the response.")
    parser_jobs_cancel.set_defaults(func=vdjserver.jobs.cancel_job)



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
    #Moved these two arguments from group_help to common_help so user can send toke and system_id of their choice.
    common_help.add_argument('--token', action='store', dest='token',
                            help='''Manually provide token instead of using JWT environment variable.''')
    common_help.add_argument('--system', action='store', dest='system_id',
                            help='''System ID for operation.''')
    ## Added --format-json to common parser so that every function has accesss to it.
    # common_help.add_argument('--format-json', action='store_true', dest='format_json',
    #                         help='''Print full metadata in raw JSON format.''')

    # Subparser for project operations
    define_project_args(subparsers, common_parser)

    # Subparser for File operations
    define_files_args(subparsers, common_parser)

    # Subparser for Job operations
    define_jobs_args(subparsers, common_parser)

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

    # Subparser for Client operations
    define_clients_args(subparsers, common_parser)

    # Subparser for Meta operations
    #define_meta_args(subparsers, common_parser)

    # Subparser for App operations
    define_apps_args(subparsers, common_parser)

    # Subparser for Postit operations
    define_postits_args(subparsers, common_parser)

    # Subparser for ADC Download Cache operations
    define_adc_cache_args(subparsers, common_parser)




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

