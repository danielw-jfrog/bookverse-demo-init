#!/usr/bin/env python3

### IMPORTS ###
import argparse
import logging
import os
import sys

from api_helpers.exceptions import NotFoundException
from api_helpers.users import get_user, assign_roles_to_user

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

    parser.add_argument("--project_key", default=os.getenv("PROJECT_KEY", None),
                        help="Short version of the project name used for identifying the project.")

    parser.add_argument("username")
    parser.add_argument("role")

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
        logging.info("Checking if user assigned to role: %s - %s", project_key, args.username)
        roles = []
        try:
            user_data = get_user(tmp_login_data, project_key, str(args.username))
            logging.debug("User Data: %s", user_data)
            # Add project role and add
            for role in user_data["roles"]:
                roles.append(role)
        except NotFoundException:
            # User not assigned role in project yet, leave roles list blank and continue
            pass
        except Exception as ex:
            raise ex
        roles.append(str(args.role))
        assign_roles_to_user(tmp_login_data, project_key, str(args.username), roles)
    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

if __name__ == "__main__":
    main()
