#!/usr/bin/env python3

### IMPORTS ###
import argparse
import logging
import os
import sys

from api_helpers.exceptions import NotFoundException
from api_helpers.projects import get_project, create_project

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

    parser.add_argument("project_key", help = "Short version of the project name used for identifying the project.")
    parser.add_argument("project_name", help = "Full name of the project.")
    args = parser.parse_args()

    # Set up logging
    logging.basicConfig(
        format = "%(asctime)s:%(levelname)s:%(name)s:%(funcName)s: %(message)s",
        level = logging.DEBUG if args.verbose else logging.INFO
    )
    logging.debug("Args: %s", args)

    logging.info("Preparing Environment")

    tmp_login_data = {}
    tmp_login_data["token"] = args.token
    tmp_login_data["host"] = args.host

    try:
        logging.info("Checking if project exists: [%s]", args.project_key)
        project_data = get_project(tmp_login_data, args.project_key)
        logging.info("  Project already exists")
        # FIXME: Check the data for the project and update if needed.
    except NotFoundException:
        try:
            logging.info("Creating Project: [%s] %s", args.project_key, args.project_name)
            create_project(tmp_login_data, args.project_key, args.project_name)
        except Exception as ex:
            raise ex
    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

if __name__ == "__main__":
    main()
