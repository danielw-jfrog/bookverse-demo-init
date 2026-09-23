#!/usr/bin/env python3

### IMPORTS ###
import argparse
import logging
import os
import sys

from api_helpers.exceptions import NotFoundException

from api_helpers.applications import list_applications, delete_application
from api_helpers.application_versions import list_application_versions, delete_application_version

from api_helpers.repositories import get_repository, create_remote_repository

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

    parser.add_argument("--project_key", default = os.getenv("PROJECT_KEY", None),
                        help = "Short version of the project name used for identifying the project.")

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

    project_key = None
    if args.project_key is not None:
        project_key = str(args.project_key)

    try:
        # Prepare application key list
        app_keys = []
        app_list = list_applications(tmp_login_data, project_key)
        logging.debug("app_list: %s", app_list)
        for item in app_list["applications"]:
            app_keys.append(item["application_key"])
        logging.debug("  app_keys: (%d) %s", len(app_keys), app_keys)

        # Clean up application versions
        for app_key in app_keys:
            app_vers = []
            logging.info("Cleaning up AppTrust Application Versions for Application: %s", app_key)
            app_ver_list = list_application_versions(tmp_login_data, app_key)
            logging.debug("app_ver_list: %s", app_ver_list)
            for item in app_ver_list["versions"]:
                app_vers.append(item["version"])
            logging.debug("  app_vers: (%d) %s", len(app_vers), app_vers)

            for app_ver in app_vers:
                logging.info("  Deleting version: %s", app_ver)
                delete_application_version(tmp_login_data, app_key, app_ver)

        # Clean up applications
        for app_key in app_keys:
            logging.info("Deleting Application: %s", app_key)
            delete_application(tmp_login_data, app_key)

        # Clean up repositories (virtual, remote, federated, local)

    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

if __name__ == "__main__":
    main()

