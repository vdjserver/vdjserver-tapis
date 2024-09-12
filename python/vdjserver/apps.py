"""
Interface functions for App operations
"""

# System imports
import json
import sys
import os
from tapipy.tapis import Tapis

#### Files ####

def apps_list(tapis_obj):
    a = tapis_obj.apps.getApps()
    print(a)
