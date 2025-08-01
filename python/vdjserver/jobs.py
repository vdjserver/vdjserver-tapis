"""
Interface functions for Jobs operations
"""

# System imports
import json
import sys
import os
from tapipy.tapis import Tapis
import vdjserver.defaults
import json


def get_job_list(list_type="ALL_JOBS", limit=None, skip=None, start_after=None, order_by=None,
                 compute_total=False, system_id=None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Call the Tapis API to get the job list
        response = tapis_obj.jobs.getJobList(
            listType=list_type,
            limit=limit,
            skip=skip,
            startAfter=start_after,
            orderBy=order_by,
            computeTotal=compute_total,
        )
        # print(response)
        # Check if response is a list (job data)
        if isinstance(response, list):
            if len(response) > 0:
                # Define the fields we want to print
                fields = ["appId", "appVersion", "status", "uuid", "created", "ended", "name"]
                
                # Determine the maximum width for each column based on the data
                field_widths = [len(field) for field in fields]

                # First pass to calculate the maximum width for each column
                for job in response:
                    for i, field in enumerate(fields):
                        field_widths[i] = max(field_widths[i], len(str(job.get(field, 'N/A'))))

                # Print the header row
                header = " | ".join([f"{field:<{field_widths[i]}}" for i, field in enumerate(fields)])
                print(header)
                print("-" * len(header))  # Separator line

                # Print each row of job data
                for job in response:
                    row = " | ".join([f"{str(job.get(field, 'N/A')):<{field_widths[i]}}" for i, field in enumerate(fields)])
                    print(row)

            else:
                print(f"No jobs found for {list_type}.")
        else:
            print(f"Unexpected response format. Expected list, got {type(response)}.")

    except Exception as e:
        print(f"Error retrieving job list: {e}")



def submit_job(json_file, system_id = None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)
    try:
        # Read the app data from the provided JSON file
        with open(json_file, 'r') as file:
            data = json.load(file)
    except Exception as e:
        print(f"Error reading JSON file: {e}")
        sys.exit(1)
    
    try:
        # Submit the job
        response = tapis_obj.jobs.submitJob(pretty = True, **data)

        # Print a formatted response
        if response:
            print("\nJob Submission Response Summary:")
            print("-" * 100)
            print(f"\tApplication Name (appId): {response.get('appId', 'N/A')}")
            print(f"\tApplication Version: {response.get('appVersion', 'N/A')}")
            print(f"\tJob UUID: {response.get('uuid', 'N/A')}")
            print(f"\tJob Status: {response.get('status', 'N/A')}")
            print("-" * 100)
            
        else:
            print("No response received from the job submission request.")

    except Exception as e:
        print(f"Error submitting job: {e}")

def get_job_status(job_uuid, pretty=False, system_id = None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Call the Tapis API to get the job status
        response = tapis_obj.jobs.getJobStatus(
            jobUuid=job_uuid,
            pretty=pretty
        )
        
        # # Print job status summary
        print(f"\nJob Status for UUID {job_uuid}:\n")
        print("-" * 100)
        print(response)
        print("-" * 100)

    except Exception as e:
        print(f"Error retrieving job status: {e}")

def get_job_history(job_uuid, limit=None, skip=None, pretty=False, system_id = None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Call the Tapis API to get the job history
        response = tapis_obj.jobs.getJobHistory(
            jobUuid=job_uuid,
            limit=limit,
            skip=skip,
            pretty=pretty
        )

        # Print the history details of the job
        print(f"\nJob History (UUID: {job_uuid}):\n")
        print(response)

    except Exception as e:
        print(f"Error retrieving job history: {e}")

def get_job(job_uuid, pretty=True, system_id = None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Call the Tapis API to get the job by UUID
        response = tapis_obj.jobs.getJob(
            jobUuid=job_uuid,
            pretty=pretty
        )

        # Print the job details
        print("-" * 100)
        print(f"Job Details (UUID: {job_uuid}):\n")
        print(response)
        print("-" * 100)

    except Exception as e:
        print(f"Error retrieving job: {e}")

def cancel_job(job_uuid, pretty=False, system_id = None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Call the Tapis API to cancel the job by UUID
        response = tapis_obj.jobs.cancelJob(
            jobUuid=job_uuid,
            pretty=pretty
        )

        # Print the result of the cancelation
        print("-" * 100)
        print(f"Job {job_uuid} has been successfully canceled.")
        print("-" * 100)

    except Exception as e:
        print("-" * 100)
        print(f"Error canceling job: {e}")
        print("-" * 100)
