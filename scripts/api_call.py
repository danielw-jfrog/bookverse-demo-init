#!/usr/bin/env python3

### IMPORTS ###
import argparse
import json
import logging
import os
import sys

from api_helpers.exceptions import NotFoundException
from api_helpers.make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###

### CLASSES ###

### MAIN ###
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", action = "store_true")
    parser.add_argument("--token", default = os.getenv("JFROG_ADMIN_TOKEN", ""),
                        help = "Artifactory access token to use for requests.  Will use JFROG_ADMIN_TOKEN if not specified.")
    parser.add_argument("--host", default = os.getenv("JFROG_URL", ""),
                        help = "Artifactory host URL (e.g. https://artifactory.example.com/) to use for requests.  Will use JFROG_URL if not specified.")

    parser.add_argument("--method", default = "GET")
    parser.add_argument("--body")
    parser.add_argument("url-path")

    args = parser.parse_args()

    # Set up logging
    logging.basicConfig(
        format = "%(asctime)s:%(levelname)s:%(name)s:%(funcName)s: %(message)s",
        level = logging.DEBUG if args.verbose else logging.INFO
    )
    logging.debug("Args: %s", args)

    tmp_login_data = {}
    tmp_login_data["token"] = args.token
    tmp_login_data["host"] = args.host

    if str(args.method) not in ["GET", "PUT", "POST", "DELETE"]:
        logging.error("Invalid HTTP method.  Choose from GET, PUT, POST, DELETE.")
        sys.exit(1)

    try:
        req_data = None
        if args.body is not None:
            req_data = json.loads(str(args.body))
        req_url = str(args.url_path)
        resp_data = make_api_request(tmp_login_data, str(args.method), req_url, req_data)
        logging.info("  Resp Data: %s", resp_data)
    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

if __name__ == "__main__":
    main()
