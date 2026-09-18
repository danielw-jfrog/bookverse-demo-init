#!/usr/bin/env python3

### IMPORTS ###
import argparse
import logging
import os
import sys

from api_helpers.exceptions import NotFoundException
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

    parser.add_argument("package_type")
    parser.add_argument("external_url")
    parser.add_argument("--pypi_registry_url")

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

    package_type = str(args.package_type).lower()
    external_url = str(args.external_url)

    pypi_registry_url = None
    if package_type == "pypi":
        if args.pypi_registry_url is not None:
            pypi_registry_url = str(args.pypi_registry_url)
        else:
            logging.error("PyPi remote repos need the registry URL")
            sys.exit(1)

    # NOTE: Project key part handled by method internally...
    repo_name = "{}-remote".format(package_type)

    try:
        logging.info("Checking if repository exists: %s - %s", project_key, repo_name)
        stage_data = get_repository(tmp_login_data, project_key, repo_name)
        logging.info("  Repository already exists")
        # FIXME: Check the data for the Repository and update if needed.
    except NotFoundException:
        try:
            logging.info("  Creating Repository: %s - %s", project_key, repo_name)
            create_remote_repository(tmp_login_data, project_key, repo_name, package_type, external_url, pypi_registry_url)
        except Exception as ex:
            raise ex
    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

if __name__ == "__main__":
    main()
