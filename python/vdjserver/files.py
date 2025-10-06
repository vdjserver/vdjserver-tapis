"""
Interface functions for Files operations
"""

# System imports
import json
import sys
import os
from tapipy.tapis import Tapis
import vdjserver.defaults
import requests
import time

#### Files ####

def files_list_cmd(path, system_id=None, token=None):
    if system_id is None:
        system_id = vdjserver.defaults.storage_system_id
    fields = [ 'nativePermissions', 'owner', 'group', 'size', 'lastModified', 'path', 'type' ]
    field_widths = [ len(obj) for obj in fields ]

    tapis_obj = vdjserver.defaults.init_tapis(token)
    try:
        res = tapis_obj.files.listFiles(systemId=system_id, path=path)
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
    except Exception as e:
        print(f"Error: \n\n{str(e)}\n")
        
## Make Directory
def tapis_files_mkdir(path, system_id=None, token=None):
    # Default storage system if none is provided
    if system_id is None:
        system_id = vdjserver.defaults.storage_system_id
    # Initialize Tapis client with token
    tapis_obj = vdjserver.defaults.init_tapis(token)
    # Send the request to create the directory
    try:
        response = tapis_obj.files.mkdir(systemId=system_id, path=path)
        
        # Check if the response is successful
        if response:
            print(f"Directory '{path}' created successfully.")
        else:
            print(f"Failed to create directory '{path}'.")
    except Exception as e:
        print(f"Error: {str(e)}")



def tapis_files_upload(source_file_path, system_id=None, dest_file_path=None, token=None):
    # Default storage system if none is provided
    if system_id is None:
        system_id = vdjserver.defaults.storage_system_id
    # Initialize Tapis client with token
    tapis_obj = vdjserver.defaults.init_tapis(token)
    # Check if the source file exists
    if not os.path.isfile(source_file_path):
        print(f"Error: The file '{source_file_path}' does not exist.")
        return
    try:
        # Perform the file upload using t.upload() method
        response = tapis_obj.upload(
            source_file_path=source_file_path,  # Local file path
            system_id=system_id,                # Tapis system ID
            dest_file_path=dest_file_path       # Destination path on Tapis system
        )

        # Check if the response indicates success
        if response:
            print("-" * 100)
            print(f"\tFile '{source_file_path}' uploaded successfully to '{dest_file_path}'.")
            print("-" * 100)
        else:
            print("-" * 100)
            print(f"\tFailed to upload file '{source_file_path}' to '{dest_file_path}'.")
            print("-" * 100)

    except Exception as e:
        print(f"Error during file upload: {str(e)}")


def tapis_files_delete(path, system_id=None, token=None):
    # Default storage system if none is provided
    if system_id is None:
        system_id = vdjserver.defaults.storage_system_id
    # Initialize Tapis client with token
    tapis_obj = vdjserver.defaults.init_tapis(token)
    # Send the request to delete the file
    try:
        response = tapis_obj.files.delete(systemId=system_id, path=path)
        
        # Check if the response is successful
        if response:
            print(f"File '{path}' deleted successfully.")
        else:
            print(f"Failed to delete file '{path}'.")
    
    except Exception as e:
        print(f"Error: {str(e)}")

# getPermissions

# In your functions.py or wherever appropriate

def tapis_files_get_permission(path, system_id=None, username=None, token=None):
    # Default storage system if none is provided
    if system_id is None:
        system_id = vdjserver.defaults.storage_system_id
    # Initialize Tapis client with token
    tapis_obj = vdjserver.defaults.init_tapis(token)

    # Send the request to get permissions for the file/folder
    try:
        # Call the getPermissions method
        permissions = tapis_obj.files.getPermissions(systemId=system_id, path=path, username=username, permission = 'None')
        
        # Print out the permissions
        if permissions:
            print(f"Permissions for '{path}': {permissions}")
        else:
            print(f"No permissions found for '{path}'.")
    except Exception as e:
        print(f"Error: {str(e)}")




#Function for granting permission

def tapis_files_grant_permission(path, system_id=None, token=None, username=None, permission=None):
    # Default storage system if none is provided
    if system_id is None:
        system_id = vdjserver.defaults.storage_system_id
    # Initialize Tapis client with token
    tapis_obj = vdjserver.defaults.init_tapis(token)

    # Check if permission is provided
    if permission is None:
        print("Error: Permission type (READ or MODIFY) is required.")
        return

    if username is None:
        print("No user provided. Permissions are retrieved for the user making the request.")
        return

    # Prepare the payload for the permission request
    permission_data = {
        "username": username,
        "permission": permission
    }

    # Send the request to grant the permission
    try:
        response = tapis_obj.files.grantPermissions(systemId=system_id, path=path, username=username, permission=permission)
        
        # Check if the response is successful
        if response:
            print(f"Permission '{permission}' granted to user '{username}' for '{path}'.")
        else:
            print(f"Failed to grant permission '{permission}' to user '{username}' for '{path}'.")
    
    except Exception as e:
        print(f"Error: {str(e)}")
        
        
# Function to revoke permissions
def tapis_files_revoke_permission(path, username, system_id=None, token=None):
    # Default storage system if none is provided
    if system_id is None:
        system_id = vdjserver.defaults.storage_system_id
    # Initialize Tapis client with token (assuming token handling is done elsewhere)
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Send the request to revoke permission
        response = tapis_obj.files.deletePermissions(systemId=system_id, path=path, username=username)
        print(response)

        # Check if the response is successful
        if response:
            print(f"Permission revoked for '{username}' on '{path}' successfully.")
        else:
            print(f"Failed to revoke permission for '{username}' on '{path}'.")

    except Exception as e:
        print(f"Error: {str(e)}")
        
def tapis_files_download(path, system_id=None, token=None, output_filename=None, chunk_size=128 * 1024):
    if system_id is None:
        system_id = vdjserver.defaults.storage_system_id
    if token is None:
        token = os.environ['JWT']
    
    # Construct the Tapis file download URL (for Agave-style APIs)
    url = f"https://vdjserver.tapis.io/v3/files/content/{system_id}/{path}"
    headers = {"X-Tapis-Token": token}
    if output_filename is None:
        output_filename = path.split('/')[-1]

    downloaded_size = 0  # Variable to track downloaded size
    start_time = time.time()  # Start time to calculate download speed
    
    try:
        tapis_obj = vdjserver.defaults.init_tapis(token)
        contents = tapis_obj.files.getStatInfo(systemId=system_id, path=path)
        if contents.get('dir'):
            response = requests.get(url, headers=headers, stream=True, params={'zip': 'true'})
            print(f"Downloading {output_filename} as ZIP...")
            output_filename = f'{output_filename}.zip'
        else:
            # Assuming the server supports the zip parameter
            response = requests.get(url, headers=headers, stream=True)
        # Check if the response status code is OK
        if response.status_code != 200:
            print(f"Error: {response.text}")
            return

        # Open file and write in chunks
        with open(output_filename, 'wb') as f:
            for chunk in response.iter_content(chunk_size=chunk_size):
                if chunk:
                    f.write(chunk)
                    downloaded_size += len(chunk)
                    # Calculate elapsed time
                    elapsed_time = time.time() - start_time
                    if elapsed_time > 0:
                        # Calculate download speed (MB per minute)
                        speed = (downloaded_size / 1024 / 1024) / (elapsed_time / 60)  # MB/min
                        # Print downloaded size and speed
                        print(f"Downloaded: {downloaded_size / 1024 / 1024:.2f} MB at {speed:.2f} MB/min", end='\r')

        print(f"\nDownload complete: {output_filename}")
    except Exception as e:
        print("-------------------------------------------------")
        print(f"Error downloading file: \n{e}")
        print("-------------------------------------------------")

def postits_list_cmd(uuid, system_id=None, token=None):
    if system_id is None:
        system_id = vdjserver.defaults.storage_system_id

    fields = [ 'id', 'created', 'timesUsed', 'path', 'redeemUrl' ]
    field_widths = [ len(obj) for obj in fields ]

    tapis_obj = vdjserver.defaults.init_tapis(token)
    res = tapis_obj.files.listPostIts()

    if len(res) > 0:
        # determine max widths
        for obj in res:
            print(obj)
            for i in range(0, len(fields)):
                if len(str(obj.get(fields[i]))) > field_widths[i]:
                    field_widths[i] = len(str(obj.get(fields[i])))

        # headers
        vdjserver.defaults.print_table_headers(fields, field_widths)

        # print values
        for obj in res:
            vdjserver.defaults.print_table_row(fields, field_widths, obj)

    else:
        print('no postits!')

##Show all TAPIS functions
# def list_tapis_functions(system_id = None, token = None):
#     # Get all available attributes and methods of the Tapis class
#     # Initialize Tapis client with token
#     tapis_obj = vdjserver.defaults.init_tapis(token)
#     print(help(tapis_obj.files))
    




