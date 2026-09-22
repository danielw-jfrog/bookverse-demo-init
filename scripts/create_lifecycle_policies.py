#!/usr/bin/env python3

### IMPORTS ###
import argparse
import logging
import os
import sys

from api_helpers.exceptions import NotFoundException
from api_helpers.lifecycle_rules import list_lifecycle_rules, create_lifecycle_rule
from api_helpers.lifecycle_policies import list_lifecycle_policies, create_lifecycle_policy

### GLOBALS ###
# FIXME: Not the best way to handle this data, but don't want to pollute the workflow script.
RULES_TO_APPLY = [
    {
        "name": "BookVerse Atlassian Jira Evidence - DEV Entry",
        "description": "Requires Atlassian Jira release evidence for DEV stage entry",
        "predicate_type": "https://atlassian.com/evidence/jira/v1",
        "template_id": "1003"
    },{
        "name": "BookVerse SLSA Provenance Evidence - DEV Entry",
        "description": "Requires SLSA provenance evidence for DEV stage entry",
        "predicate_type": "https://slsa.dev/provenance/v1",
        "template_id": "1003"
    },{
        "name": "BookVerse DEV Entry - Build Quality Gate Required",
        "description": "Requires SonarQube quality gate evidence attached to build info for DEV stage entry",
        "predicate_type": "https://sonarsource.com/evidence/quality-gate/v1",
        "template_id": "1003"
    },{
        "name": "BookVerse DEV Entry - Docker SAST Evidence Required",
        "description": "Requires SAST scan evidence attached to Docker images for DEV stage entry",
        "predicate_type": "https://checkmarx.com/evidence/sast/v1.1",
        "template_id": "1003"
    },{
        "name": "BookVerse DEV Entry - Package Unit Test Evidence Required",
        "description": "Requires unit test results evidence attached to packages for DEV stage entry",
        "predicate_type": "https://pytest.org/evidence/results/v1",
        "template_id": "1003"
    },{
        "name": "BookVerse Smoke Test Evidence - DEV Exit",
        "description": "Requires smoke test evidence for DEV stage exit",
        "predicate_type": "https://testing.io/evidence/smoke-tests/v1",
        "template_id": "1003"
    },{
        "name": "BookVerse Invicti DAST Evidence - QA Exit",
        "description": "Requires Invicti DAST scan evidence for QA stage exit",
        "predicate_type": "https://invicti.com/evidence/dast/v3",
        "template_id": "1003"
    },{
        "name": "BookVerse Postman Collection Evidence - QA Exit",
        "description": "Requires Postman collection test evidence for QA stage exit",
        "predicate_type": "https://postman.com/evidence/collection/v2.2",
        "template_id": "1003"
    },{
        "name": "BookVerse Cobalt Pentest Evidence - STAGING",
        "description": "Requires Cobalt penetration testing evidence for STAGING stage exit",
        "predicate_type": "https://cobalt.io/evidence/pentest/v1",
        "template_id": "1003"
    },{
        "name": "BookVerse ServiceNow Change Evidence - STAGING Exit",
        "description": "Requires ServiceNow change approval evidence for STAGING stage exit",
        "predicate_type": "https://servicenow.com/evidence/release/v1",
        "template_id": "1003"
    },{
        "name": "BookVerse Snyk IaC Evidence - STAGING",
        "description": "Requires Snyk Infrastructure as Code scan evidence for STAGING stage exit",
        "predicate_type": "https://snyk.io/evidence/iac/v1",
        "template_id": "1003"
    },{
        "name": "BookVerse DEV Stage Completion for PROD",
        "description": "Requires DEV stage completion before PROD release",
        "predicate_type": "https://jfrog.com/evidence/apptrust/gate-certify/v1",
        "template_id": "1004"
    },{
        "name": "BookVerse QA Stage Completion for PROD",
        "description": "Requires QA stage completion before PROD release",
        "predicate_type": "https://jfrog.com/evidence/apptrust/gate-certify/v1",
        "template_id": "1004"
    },{
        "name": "BookVerse STAGING Stage Completion for PROD",
        "description": "Requires STAGING stage completion before PROD release",
        "predicate_type": "https://jfrog.com/evidence/apptrust/gate-certify/v1",
        "template_id": "1004"
    }
]

POLICIES_TO_APPLY = [
    {
        "name": "BookVerse DEV Entry - Atlassian Jira Required",
        "description": "Requires Atlassian Jira release evidence for DEV stage entry",
        "stage_name": "{pkey}-DEV",
        "gate": "entry",
        "rule_name": "BookVerse Atlassian Jira Evidence - DEV Entry",
        "mode": "warning"
    },{
        "name": "BookVerse DEV Entry - SLSA Provenance Required",
        "description": "Requires SLSA provenance evidence for DEV stage entry",
        "stage_name": "{pkey}-DEV",
        "gate": "entry",
        "rule_name": "BookVerse SLSA Provenance Evidence - DEV Entry",
        "mode": "warning"
    },{
        "name": "BookVerse DEV Entry - Build Quality Gate Required",
        "description": "Requires SonarQube quality gate evidence attached to build info for DEV stage entry",
        "stage_name": "{pkey}-DEV",
        "gate": "entry",
        "rule_name": "BookVerse DEV Entry - Build Quality Gate Required",
        "mode": "warning"
    },{
        "name": "BookVerse DEV Entry - Docker SAST Evidence Required",
        "description": "Requires SAST scan evidence attached to Docker images for DEV stage entry",
        "stage_name": "{pkey}-DEV",
        "gate": "entry",
        "rule_name": "BookVerse DEV Entry - Docker SAST Evidence Required",
        "mode": "warning"
    },{
        "name": "BookVerse DEV Entry - Package Unit Test Evidence Required",
        "description": "Requires unit test results evidence attached to packages for DEV stage entry",
        "stage_name": "{pkey}-DEV",
        "gate": "entry",
        "rule_name": "BookVerse DEV Entry - Package Unit Test Evidence Required",
        "mode": "warning"
    },{
        "name": "BookVerse DEV Exit - Smoke Test Required",
        "description": "Requires smoke test evidence for DEV stage exit",
        "stage_name": "{pkey}-DEV",
        "gate": "exit",
        "rule_name": "BookVerse Smoke Test Evidence - DEV Exit",
        "mode": "warning"
    },{
        "name": "BookVerse QA Exit - Invicti DAST Required",
        "description": "Requires Invicti DAST scan evidence for QA stage exit",
        "stage_name": "{pkey}-QA",
        "gate": "exit",
        "rule_name": "BookVerse Invicti DAST Evidence - QA Exit",
        "mode": "warning"
    },{
        "name": "BookVerse QA Exit - Postman Collection Required",
        "description": "Requires Postman collection test evidence for QA stage exit",
        "stage_name": "{pkey}-QA",
        "gate": "exit",
        "rule_name": "BookVerse Postman Collection Evidence - QA Exit",
        "mode": "warning"
    },{
        "name": "BookVerse STAGING Exit - Cobalt Pentest Required",
        "description": "Requires Cobalt penetration testing evidence for STAGING stage exit",
        "stage_name": "{pkey}-STAGING",
        "gate": "exit",
        "rule_name": "BookVerse Cobalt Pentest Evidence - STAGING",
        "mode": "warning"
    },{
        "name": "BookVerse STAGING Exit - ServiceNow Change Required",
        "description": "Requires ServiceNow change approval evidence for STAGING stage exit",
        "stage_name": "{pkey}-STAGING",
        "gate": "exit",
        "rule_name": "BookVerse ServiceNow Change Evidence - STAGING Exit",
        "mode": "warning"
    },{
        "name": "BookVerse STAGING Exit - Snyk IaC Required",
        "description": "Requires Snyk Infrastructure as Code scan evidence for STAGING stage exit",
        "stage_name": "{pkey}-STAGING",
        "gate": "exit",
        "rule_name": "BookVerse Snyk IaC Evidence - STAGING",
        "mode": "warning"
    },{
        "name": "BookVerse PROD Release - DEV Completion Required",
        "description": "Requires DEV stage completion before PROD release",
        "stage_name": "PROD",
        "gate": "release",
        "rule_name": "BookVerse DEV Stage Completion for PROD",
        "mode": "warning"
    },{
        "name": "BookVerse PROD Release - QA Completion Required",
        "description": "Requires QA stage completion before PROD release",
        "stage_name": "PROD",
        "gate": "release",
        "rule_name": "BookVerse QA Stage Completion for PROD",
        "mode": "warning"
    },{
        "name": "BookVerse PROD Release - STAGING Completion Required",
        "description": "Requires STAGING stage completion before PROD release",
        "stage_name": "PROD",
        "gate": "release",
        "rule_name": "BookVerse STAGING Stage Completion for PROD",
        "mode": "warning"
    }
]

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
        for rule in RULES_TO_APPLY:
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
        for policy in POLICIES_TO_APPLY:
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
