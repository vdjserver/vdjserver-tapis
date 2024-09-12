"""
Interface functions for Token operations
"""

# System imports
import json
import sys
from tapipy.tapis import Tapis
import vdjserver.defaults
import getpass

#### Token ####

def get_token(username, password):
    """
    Call VDJServer API to get a new token

    Arguments:
      username (str): system username.
      password (str): user password.

    Returns:
      token object.
    """

    if password is None:
        try:
            p = getpass.getpass()
        except Exception as error:
            print('ERROR', error)
            sys.exit(1)
        else:
            password = p

    # Create python Tapis client for user
    t = Tapis(base_url= "https://" + vdjserver.defaults.tapis_host,
              username=username,
              password=password)

    # Call to Tokens API to get access token
    t.get_tokens()
    print(t.access_token.access_token)
    return t.access_token
