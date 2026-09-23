#!/usr/bin/env python3

### IMPORTS ###
import argparse
import logging
import os
import sys

from api_helpers.exceptions import NotFoundException

from api_helpers.applications import list_applications, delete_application
from api_helpers.application_versions import list_application_versions, delete_application_version
from api_helpers.repositories import list_repositories, delete_repository

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

    # FIXME: Should probably add a dry run option...

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
        logging.info("Cleaning up AppTrust Applications")
        for app_key in app_keys:
            logging.info("  Deleting Application: %s", app_key)
            delete_application(tmp_login_data, app_key)

        # Clean up repositories (virtual, remote, federated, local)
        logging.info("Cleaning up Repositories")
        repo_keys_virtual = []
        repo_keys_remote = []
        repo_keys_federated = []
        repo_keys_local = []
        repo_list = list_repositories(tmp_login_data)
        logging.debug("repo_list: %s", repo_list)
        if "VIRTUAL" in repo_list:
            for item in repo_list["VIRTUAL"]:
                if "projectKey" in item and item["projectKey"] == project_key:
                    repo_keys_virtual.append(item["key"])
        logging.debug("  repo_keys_virtual: (%d) %s", len(repo_keys_virtual), repo_keys_virtual)
        if "REMOTE" in repo_list:
            for item in repo_list["REMOTE"]:
                if "projectKey" in item and item["projectKey"] == project_key:
                    repo_keys_remote.append(item["key"])
        logging.debug("  repo_keys_remote: (%d) %s", len(repo_keys_remote), repo_keys_remote)
        if "FEDERATED" in repo_list:
            for item in repo_list["FEDERATED"]:
                if "projectKey" in item and item["projectKey"] == project_key:
                    repo_keys_federated.append(item["key"])
        logging.debug("  repo_keys_federated: (%d) %s", len(repo_keys_federated), repo_keys_federated)
        if "LOCAL" in repo_list:
            for item in repo_list["LOCAL"]:
                if "projectKey" in item and item["projectKey"] == project_key:
                    repo_keys_local.append(item["key"])
        logging.debug("  repo_keys_local: (%d) %s", len(repo_keys_local), repo_keys_local)
        for repo_key in repo_keys_virtual:
            logging.info("  Deleting VIRTUAL repository: %s", repo_key)
            delete_repository(tmp_login_data, repo_key)
        for repo_key in repo_keys_remote:
            logging.info("  Deleting REMOTE repository: %s", repo_key)
            delete_repository(tmp_login_data, repo_key)
        for repo_key in repo_keys_federated:
            logging.info("  Deleting FEDERATED repository: %s", repo_key)
            delete_repository(tmp_login_data, repo_key)
        for repo_key in repo_keys_local:
            logging.info("  Deleting LOCAL repository: %s", repo_key)
            delete_repository(tmp_login_data, repo_key)

        # Clean up stages

        # Clean up OIDC Integrations

        # Clean up lifecycle policies

        # Clean up lifecycle rules

        # Clean up users

        # Clean up roles

        # Clean up project

    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

if __name__ == "__main__":
    main()

