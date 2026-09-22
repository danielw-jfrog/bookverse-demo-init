#!/usr/bin/env python3

### IMPORTS ###
import argparse
import logging
import os
import sys

from api_helpers.exceptions import NotFoundException
from api_helpers.lifecycle_stages import set_lifecycle

### GLOBALS ###
predefined_roles = {
    "cicd_pipeline": {
        "name": "cicd_pipeline",
        "description": "Role for QA and testing activities, allowing read access to dev repositories.",
        "type": "CUSTOM",
        "actions": [
            "ANNOTATE_BUILD",
            "ANNOTATE_RELEASE_BUNDLE",
            "ANNOTATE_REPOSITORY",
            "MANAGE_XRAY_MD_BUILD",
            "MANAGE_XRAY_MD_RELEASE_BUNDLE",
            "MANAGE_XRAY_MD_REPOSITORY",
            "BIND_APPLICATION",
            "CREATE_APPLICATION",
            "CREATE_RELEASE_BUNDLE",
            "DELETE_APPLICATION",
            "DELETE_BUILD",
            "DELETE_OVERWRITE_REPOSITORY",
            "DELETE_RELEASE_BUNDLE",
            "DEPLOY_BUILD",
            "DEPLOY_CACHE_REPOSITORY",
            "PROMOTE_APPLICATION",
            "READ_APPLICATION",
            "READ_BUILD",
            "READ_RELEASE_BUNDLE",
            "READ_REPOSITORY"
        ],
        "environments": [
            "{pkey}-DEV",
            "{pkey}-QA",
            "{pkey}-STAGING",
            "PROD",
            "DEV"
        ]
    },
    "k8s_image_pull": {
        "name": "k8s_image_pull",
        "description": "Kubernetes Image Pull - Minimal read access to PROD repositories for container deployment.",
        "type": "CUSTOM",
        "actions": [
            "READ_REPOSITORY",
            "READ_RELEASE_BUNDLE",
            "READ_APPLICATION"
        ],
        "environments": [
            "PROD"
        ]
    }
}

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

    parser.add_argument("--project_key", default=os.getenv("PROJECT_KEY", None),
                        help="Short version of the project name used for identifying the project.")

    parser.add_argument("stages", nargs = '+')

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

    stages = []
    for arg in args.stages:
        if project_key is not None:
            stages.append("{}-{}".format(project_key, arg))
        else:
            stages.append(str(arg))

    try:
        logging.info("Updating lifecycle with stages: %s - %s", project_key, stages)
        set_lifecycle(tmp_login_data, project_key, stages)
    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

if __name__ == "__main__":
    main()
