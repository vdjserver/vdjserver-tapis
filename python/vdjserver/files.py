"""
Interface functions for Files operations
"""

# System imports
import json
import sys
import os
from tapipy.tapis import Tapis

#### Files ####

def files_list(tapis_obj, system_id, path):
    f = tapis_obj.files.listFiles(systemId=system_id, path=path)
    print(f)
