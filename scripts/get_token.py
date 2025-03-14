
from tapipy.tapis import Tapis
import argparse
import sys
import os

parser = argparse.ArgumentParser(description='Get Tapis V3 token.')
parser.add_argument('username', type=str, help='username', metavar=('username'))
parser.add_argument('password', type=str, help='password', metavar=('password'))

args = parser.parse_args()
if args:
    # Create python Tapis client for user
    host = "vdjserver.tapis.io"
    if os.environ['tapis_default_host']:
        host = os.environ['tapis_default_host']
    t = Tapis(base_url= "https://" + host,
              username=args.username,
              password=args.password)

    # Call to Tokens API to get access token
    t.get_tokens()
    print(t.access_token.access_token)
    sys.exit(0)

sys.exit(1)
