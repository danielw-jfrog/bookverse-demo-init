#!/usr/bin/env python3

### IMPORTS ###
import argparse
import logging
import os
import sys

from api_helpers.exceptions import NotFoundException
from api_helpers.integrations_oidc import list_oidc_integrations, create_oidc_integration, list_oidc_identity_mappings, create_oidc_identity_mapping

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
    parser.add_argument("--token_issuer", default = os.getenv("GH_REPOSITORY_OWNER", None),
                        help = "The token issuer for OIDC, which is usually the repository owner.")

    parser.add_argument("repo_owner")
    parser.add_argument("component")
    #parser.add_argument("email")

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
    token_issuer = None
    if args.token_issuer is not None:
        token_issuer = str(args.token_issuer)

    integ_name = "{}-{}-github".format(project_key, str(args.component))

    # Create the OIDC Configuration(s)
    oidc_integs = []
    try:
        logging.info("Getting a list of all OIDC integrations")
        oidc_integ_list = list_oidc_integrations(tmp_login_data)
        logging.debug("  OIDC integration list: %s", oidc_integ_list)
        for item in oidc_integ_list:
             oidc_integs.append(item["name"])
        logging.debug("  oidc_integs: (%d) %s", len(oidc_integs), oidc_integs)
        # # FIXME: This just checks for existence, not whether the rule values match.
        if integ_name not in oidc_integs:
            logging.info("Creating OIDC Integration: %s", integ_name)
            create_oidc_integration(
                tmp_login_data,
                integ_name,
                "GitHub",
                "https://token.actions.githubusercontent.com",
                tmp_login_data["host"],
                token_issuer,
                "OIDC integration for GitHub Actions"
            )
    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

    # Refresh the OIDC Integration List
    oidc_integs = []
    try:
        logging.info("Getting a list of all OIDC integrations")
        oidc_integ_list = list_oidc_integrations(tmp_login_data)
        logging.debug("  OIDC integration list: %s", oidc_integ_list)
        for item in oidc_integ_list:
             oidc_integs.append(item["name"])
        logging.debug("  oidc_integs: (%d) %s", len(oidc_integs), oidc_integs)
    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

    # Create the OIDC Identity Mappings
    oidc_maps = []
    try:
        logging.info("Getting a list of all OIDC mappings for %s", integ_name)
        oidc_map_list = list_oidc_identity_mappings(tmp_login_data, None, integ_name)
        logging.debug("  OIDC mapping list: %s", oidc_map_list)
        for item in oidc_map_list:
             oidc_maps.append(item["name"])
        logging.debug("  oidc_maps: (%d) %s", len(oidc_maps), oidc_maps)
        # # FIXME: This just checks for existence, not whether the rule values match.
        if integ_name not in oidc_maps:
            logging.info("Creating OIDC Mapping: %s", integ_name)
            scope = "applied-permissions/roles:{}:cicd_pipeline".format(project_key)
            if project_key == "bgvi":
                scope = "applied-permissions/roles:bvgi:cicd_pipeline_gi"
            create_oidc_identity_mapping(
                tmp_login_data,
                integ_name,
                integ_name,
                "Identity mapping for {}".format(integ_name),
                1,
                {
                    "repository": "{}/bookverse-{}".format(args.repo_owner, args.component)
                },
                {
                    "scope": scope
                }
            )
    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

if __name__ == "__main__":
    main()
