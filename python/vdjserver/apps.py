"""
Interface functions for App operations
"""

# System imports
import json
import sys
import os
from tapipy.tapis import Tapis
import vdjserver.defaults
import requests


def apps_list(system_id=None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)
    # Get apps list
    response = tapis_obj.apps.getApps(select="allAttributes")
    print(len(response))
    # Define the fields and initial column widths
    fields = ["App Name", "Owner", "Container Image", "Description", "Version"]
    field_widths = [len(field) for field in fields]

    print("\nVDJ server Tools Apps List: \n")
    if len(response) > 0:
        # Determine max widths for each column based on the data
        for data in response:
            appname = str(data.get("id", "N/A"))
            owner = str(data.get("owner", "N/A"))
            container_image = str(data.get("containerImage", "N/A"))
            description = str(data.get("description", "N/A"))
            version = str(data.get("version", "N/A"))

            field_widths[0] = max(field_widths[0], len(appname))  # App Name
            field_widths[1] = max(field_widths[1], len(owner))    # Owner
            field_widths[2] = max(field_widths[2], len(container_image))  # Container Image
            field_widths[3] = max(field_widths[3], len(description))  # Description
            field_widths[4] = max(field_widths[4], len(version))  # Version

        # Print the header row
        header = " | ".join([f"{field:<{field_widths[i]}}" for i, field in enumerate(fields)])
        print(header)
        print("-" * len(header))  # Print separator line

        # Print the data rows
        for data in response:
            appname = str(data.get("id", "N/A"))
            owner = str(data.get("owner", "N/A"))
            container_image = str(data.get("containerImage", "N/A"))
            description = str(data.get("description", "N/A"))
            version = str(data.get("version", "N/A"))

            row = " | ".join([f"{appname:<{field_widths[0]}}", 
                              f"{owner:<{field_widths[1]}}", 
                              f"{container_image:<{field_widths[2]}}", 
                              f"{description:<{field_widths[3]}}", 
                              f"{version:<{field_widths[4]}}"])
            print(row)
    else:
        print("No apps found.")

def create_app_version(json_file, system_id = None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Read the app data from the provided JSON file
        with open(json_file, 'r') as file:
            app_data = json.load(file)
        print(type(app_data))
    except Exception as e:
        print(f"Error reading JSON file: {e}")
        sys.exit(1)
    try:
        # Convert the app_data dictionary to a JSON string using json.dumps()

        # Call the Tapis API to create the app version with the data
        response = tapis_obj.apps.createAppVersion(**app_data)
        
        # Print the successful response
        print("App version created successfully:", response)

    except Exception as e:
        print(f"Error creating app version: {e}")




def apps_update(app_name, app_version, json_file, system_id = None, token=None):
    tapis_obj = vdjserver.defaults.init_tapis(token)
    try:
        # Read the app data from the provided JSON file
        with open(json_file, 'r') as file:
            data = json.load(file)
    except Exception as e:
        print(f"Error reading JSON file: {e}")
        sys.exit(1)
    # app_name = str(data.get("id", "N/A"))
    # owner = str(data.get("owner", "N/A"))
    container_image = str(data.get("containerImage", "N/A"))
    description = str(data.get("description", "N/A"))
    # version = str(data.get("version", "N/A"))
    # print(app_name, app_version)
    try:
        # Convert the app_data dictionary to a JSON string using json.dumps()

        # Call the Tapis API to create the app version with the data
        response = tapis_obj.apps.putApp(appId = app_name, appVersion = app_version, **data)
        
        # Print the successful response
        print("App version Updated successfully:", response)

    except Exception as e:
        print(f"Error Updating app version: {e}")
        
        
        
def delete_app(app_name, system_id=None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Call the Tapis API to delete the app version
        response = tapis_obj.apps.deleteApp(appId=app_name)

        # Print the successful response
        print(f"App {app_name} deleted successfully:", response)

    except Exception as e:
        print(f"Error deleting app {app_name}: {e}")

def change_app_owner(app_id, user_name, system_id=None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Call the Tapis API to change the app owner
        response = tapis_obj.apps.changeAppOwner(appId=app_id, userName=user_name)

        # Print the successful response
        print(f"App {app_id} owner changed to {user_name} successfully:", response)

    except Exception as e:
        print(f"Error changing owner of app {app_id}: {e}")


def get_app_history(app_id, system_id=None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Call the Tapis API to get the app history
        response = tapis_obj.apps.getHistory(appId=app_id)

        # Print a formatted history summary
        print(f"History for app '{app_id}':\n")
        
        # Assuming the response is a list of history entries
        for history_entry in response:
            # Extract and print important details, ensuring each field is accessed correctly
            app_version = history_entry.get('appVersion', 'N/A')
            created = history_entry.get('created', 'N/A')
            description_details = history_entry.get('description', 'No description available')
            description = description_details.get('description', 'No description available' )
            container_image = description_details.get('containerImage', 'N/A')
            exec_system_id = description_details.get('execSystemId', 'N/A')
            owner = description_details.get('owner', 'N/A')
            job_description = description_details.get('jobDescription', 'N/A')
            memory_mb = description_details.get('memoryMB', 'N/A')
            version_enabled = description_details.get('versionEnabled', 'N/A')
            archived = description_details.get('archiveOnAppError', 'N/A')
            
            # Print the extracted details in a nicely formatted manner
            print(f"\tApp Name: {app_id}")
            print(f"\tVersion: {app_version}")
            print(f"\tCreated: {created}")
            print(f"\tDescription: {description}")
            print(f"\tContainer Image: {container_image}")
            print(f"\tExec System ID: {exec_system_id}")
            print(f"\tOwner: {owner}")
            print(f"\tJob Description: {job_description}")
            print(f"\tMemory (MB): {memory_mb}")
            print(f"\tVersion Enabled: {version_enabled}")
            print(f"\tArchived: {archived}")
            print("-" * 100)  # Separator for readability

    except Exception as e:
        print(f"Error retrieving history for app {app_id}: {e}")



# def list_tapis_functions(system_id = None, token = None):
#     if system_id is None:
#         system_id = vdjserver.defaults.storage_system_id
#     print(system_id)
#     tapis_obj = vdjserver.defaults.init_tapis(token)
#     print(dir(tapis_obj.apps)) 
    
