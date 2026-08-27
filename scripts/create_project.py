#!/usr/bin/env python3

### IMPORTS ###
import argparse
import logging
import os

from api_helpers.projects import create_project

### GLOBALS ###

### FUNCTIONS ###

### CLASSES ###

### MAIN ###
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", action = "store_true")
    parser.add_argument("--token", default = os.getenv("ARTIFACTORY_TOKEN", ""),
                        help = "Artifactory access token to use for requests.  Will use ARTIFACTORY_TOKEN if not specified.")
    parser.add_argument("--host", default = os.getenv("ARTIFACTORY_HOST", ""),
                        help = "Artifactory host URL (e.g. https://artifactory.example.com/) to use for requests.  Will use ARTIFACTORY_HOST if not specified.")

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

    logging.info("Creating Project: {} {}", args.project_key, args.project_name)
    create_project(tmp_login_data, args.project_key, args.project_name)

if __name__ == "__main__":
    main()
