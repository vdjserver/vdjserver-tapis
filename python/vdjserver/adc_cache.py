"""
Interface functions for ADC Download Cache operations
"""

# System imports
import json
import sys
import os
from tapipy.tapis import Tapis
import vdjserver.defaults
import requests

# These call the VDJServer Repository API

def cache_get_status_cmd(system_id=None, token=None):

    try:
        response = requests.get('https://vdjserver.org/airr/v1/admin/adc/cache')
        response.raise_for_status()  # Raise HTTPError for bad responses (4xx or 5xx)
        r = json.loads(response.text)
        if r['status'] == 'success':
            print(json.dumps(r['result'], indent=2))
        else:
            print(f"Unsuccessful request, response was: {r}")
    except requests.exceptions.RequestException as e:
        print(f"Request error: {e}")
    except Exception as e:
        print(f"Error processing response: {e}")

def cache_update_status_cmd(status, system_id=None, token=None):

    try:
        response = requests.get('https://vdjserver.org/airr/v1/admin/adc/status')
        response.raise_for_status()  # Raise HTTPError for bad responses (4xx or 5xx)
    except requests.exceptions.RequestException as e:
        print(f"Request error: {e}")

    print(response)
