#!/usr/bin/env python3

### IMPORTS ###
import argparse
import json
import logging
import os
import pathlib
import sys

from api_helpers.exceptions import NotFoundException
from api_helpers.lifecycle_rules import list_lifecycle_rules, create_lifecycle_rule
from api_helpers.lifecycle_policies import list_lifecycle_policies, create_lifecycle_policy

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

    parser.add_argument("input_file_name")

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

    input_data = None
    input_path = pathlib.Path("input_data", args.input_file_name)
    with open(input_path, 'r') as finput:
        input_data = json.load(finput)
    if input_data is None:
        logging.error("Failed to load data from file: %s", input_path)
        sys.exit(1)

    # Apply AppTrust Lifecycle Rules
    rules_to_ids = {}
    try:
        logging.info("Getting a list of all rules")
        rule_list = list_lifecycle_rules(tmp_login_data)
        logging.debug("  Lifecycle rule list: %s", rule_list)
        for item in rule_list["items"]:
            rules_to_ids[item["name"]] = item["id"]
        logging.debug("  rules_to_ids: (%d) %s", len(rules_to_ids), rules_to_ids)
        # FIXME: This just checks for existence, not whether the rule values match.
        for rule in input_data["RULES_TO_APPLY"]:
            if rule["name"] not in rules_to_ids:
                logging.info("Creating rule: %s", rule["name"])
                create_lifecycle_rule(tmp_login_data, rule["name"], rule["description"], rule["template_id"], rule["predicate_type"])
    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

    # Refresh AppTrust Lifecycle Rules
    try:
        logging.info("Getting a list of all rules again")
        rule_list = list_lifecycle_rules(tmp_login_data)
        logging.debug("  Lifecycle rule list: %s", rule_list)
        for item in rule_list["items"]:
            rules_to_ids[item["name"]] = item["id"]
        logging.debug("  rules_to_ids: (%d) %s", len(rules_to_ids), rules_to_ids)
    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

    # Apply AppTrust Lifecycle Policies
    policies_to_ids = {}
    try:
        logging.info("Getting a list of policies")
        policy_list = list_lifecycle_policies(tmp_login_data)
        logging.debug("  Lifecycle policy list: %s", policy_list)
        for item in policy_list["items"]:
            policies_to_ids[item["name"]] = item["id"]
        logging.debug("  policies_to_ids: (%d) %s", len(policies_to_ids), policies_to_ids)
        # FIXME: This just checks for existence, not whether the rule values match.
        for policy in input_data["POLICIES_TO_APPLY"]:
            if policy["name"] not in policies_to_ids:
                logging.info("Creating policy: %s", policy["name"])
                create_lifecycle_policy(
                    tmp_login_data,
                    project_key,
                    policy["name"],
                    policy["description"],
                    policy["stage_name"] if '{pkey}' not in policy["stage_name"] else str(policy["stage_name"]).replace('{pkey}', project_key),
                    policy["gate"],
                    [rules_to_ids[policy["rule_name"]]],
                    policy["mode"]
                )
    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

if __name__ == "__main__":
    main()
