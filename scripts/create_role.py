#!/usr/bin/env python3

### IMPORTS ###
import argparse
import logging
import os
import sys

from api_helpers.exceptions import NotFoundException
from api_helpers.roles import get_role, create_role

### GLOBALS ###
predefined_roles = {
    "cicd_pipeline": {
        "name": "cicd_pipeline",
        "description": "Role for QA and testing activities, allowing read access to dev repositories.",
        "type": "CUSTOM",
        "actions": [
            "READ_REPOSITORY",
            "ANNOTATE_REPOSITORY",
            "DEPLOY_CACHE_REPOSITORY",
            "DELETE_OVERWRITE_REPOSITORY",
            "MANAGE_XRAY_MD_REPOSITORY",
            "READ_RELEASE_BUNDLE",
            "ANNOTATE_RELEASE_BUNDLE",
            "CREATE_RELEASE_BUNDLE",
            "DISTRIBUTE_RELEASE_BUNDLE",
            "DELETE_RELEASE_BUNDLE",
            "MANAGE_XRAY_MD_RELEASE_BUNDLE",
            "READ_BUILD",
            "ANNOTATE_BUILD",
            "DEPLOY_BUILD",
            "DELETE_BUILD",
            "MANAGE_XRAY_MD_BUILD",
            "READ_APPLICATION",
            "CREATE_APPLICATION",
            "DELETE_APPLICATION",
            "PROMOTE_APPLICATION",
            "BIND_APPLICATION",
            "CREATE_APPLICATION_VERSION",
            "READ_APPLICATION_VERSION",
            "ANNOTATE_APPLICATION_VERSION",
            "DELETE_APPLICATION_VERSION",
            "PROMOTE_APPLICATION_VERSION",
            "RELEASE_APPLICATION_VERSION"
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
    },
    "cicd_pipeline_gi": {
        "name": "cicd_pipeline_gi",
        "description": "Role for operations by the CI/CD Pipeline.",
        "type": "CUSTOM",
        "actions": [
            "READ_REPOSITORY",
            "ANNOTATE_REPOSITORY",
            "DEPLOY_CACHE_REPOSITORY",
            "DELETE_OVERWRITE_REPOSITORY",
            "MANAGE_XRAY_MD_REPOSITORY",
            "READ_RELEASE_BUNDLE",
            "ANNOTATE_RELEASE_BUNDLE",
            "CREATE_RELEASE_BUNDLE",
            "DISTRIBUTE_RELEASE_BUNDLE",
            "DELETE_RELEASE_BUNDLE",
            "MANAGE_XRAY_MD_RELEASE_BUNDLE",
            "READ_BUILD",
            "ANNOTATE_BUILD",
            "DEPLOY_BUILD",
            "DELETE_BUILD",
            "MANAGE_XRAY_MD_BUILD",
            "READ_APPLICATION",
            "CREATE_APPLICATION",
            "DELETE_APPLICATION",
            "PROMOTE_APPLICATION",
            "BIND_APPLICATION",
            "CREATE_APPLICATION_VERSION",
            "READ_APPLICATION_VERSION",
            "ANNOTATE_APPLICATION_VERSION",
            "DELETE_APPLICATION_VERSION",
            "PROMOTE_APPLICATION_VERSION",
            "RELEASE_APPLICATION_VERSION"
        ],
        "environments": [
            "{pkey}-DEV",
            "PROD",
            "DEV" # NOTE: Global DEV Stage is needed for the bvgi-build-info repository.
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

    parser.add_argument("predefined_role_name")

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

    if args.predefined_role_name not in predefined_roles:
        logging.error("Not one of the predefined roles.")
        sys.exit(1)
    role_name = str(args.predefined_role_name)

    project_key = None
    if args.project_key is not None:
        project_key = str(args.project_key)

    try:
        logging.info("Checking if role exists: %s - %s", project_key, role_name)
        role_data = get_role(tmp_login_data, project_key, predefined_roles[role_name]["name"])
        logging.info("  Role already exists")
    except NotFoundException:
        try:
            logging.info("  Creating role: %s - %s", project_key, role_name)
            environments = []
            for environ in predefined_roles[role_name]["environments"]:
                # If the environ needs the project key replaced, replace and append
                if '{pkey}' in environ:
                    if project_key is not None:
                        environments.append(str(environ).replace('{pkey}', str(project_key)))
                # Otherwise just append to list
                else:
                    environments.append(environ)
            create_role(
                tmp_login_data,
                project_key,
                role_name,
                predefined_roles[role_name]["description"],
                predefined_roles[role_name]["actions"],
                environments
            )
        except Exception as ex:
            raise ex
    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

if __name__ == "__main__":
    main()
