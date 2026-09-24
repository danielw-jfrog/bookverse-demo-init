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
from api_helpers.integrations_oidc import list_oidc_integrations, delete_oidc_integration, list_oidc_identity_mappings, delete_oidc_identity_mapping
from api_helpers.lifecycle_policies import list_lifecycle_policies, delete_lifecycle_policy
from api_helpers.lifecycle_rules import list_lifecycle_rules, delete_lifecycle_rule
from api_helpers.users import list_users, delete_user, list_project_users
from api_helpers.roles import list_roles, delete_role
from api_helpers.lifecycle_stages import list_lifecycle_stages, delete_lifecycle_stage, set_lifecycle
from api_helpers.projects import delete_project

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

        # Clean up builds

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

        # Clean up OIDC Identity Mappings and Integrations
        logging.info("Cleaning up OIDC Identity Mappings and Integrations")
        oidc_integs = []
        oidc_integ_list = list_oidc_integrations(tmp_login_data)
        logging.debug("  oidc_integ_list: %s", oidc_integ_list)
        for oidc_integ in oidc_integ_list:
            # FIXME: This is a naive way to clean up, using the project_key in the name, but it's a pattern we have.
            #        This should really walk the identity mappings, remove any that are associated with the project key,
            #        and mark for removal the associated integration if there are no longer any identity mappings.
            if project_key in oidc_integ["name"]:
                oidc_integs.append(oidc_integ["name"])
        logging.debug("  oidc_integs: (%d) %s", len(oidc_integs), oidc_integs)

        for oidc_name in oidc_integs:
            logging.debug("Cleaning OIDC Identity Maps for %s:", oidc_name)
            ident_maps = []
            ident_map_list = list_oidc_identity_mappings(tmp_login_data, project_key, oidc_name)
            logging.debug("  ident_map_list: %s", ident_map_list)
            for ident_map in ident_map_list:
                ident_maps.append(ident_map["name"])
            logging.debug("  ident_maps: (%d) %s", len(ident_maps), ident_maps)
            for ident_name in ident_maps:
                logging.info("  Deleting OIDC Identity Map: %s - %s", oidc_name, ident_name)
                delete_oidc_identity_mapping(tmp_login_data, oidc_name, ident_name)

        for oidc_name in oidc_integs:
            logging.info("  Deleting OIDC Integration: %s", oidc_name)
            delete_oidc_integration(tmp_login_data, oidc_name)

        # Clean up lifecycle policies
        logging.info("Cleaning up AppTrust Lifecycle Policies")
        policy_ids = []
        rule_ids = []
        policy_list = list_lifecycle_policies(tmp_login_data, project_key)
        logging.debug("  policy_list: %s", policy_list)
        # FIXME: This will cover cleaning up any project scoped policies, but not any organization
        #        wide policies or application specific scoped policies.  Figure out how to handle those.
        for policy in policy_list["items"]:
            if policy["scope"]["type"] == "project" and project_key in policy["scope"]["project_keys"]:
                policy_ids.append(str(policy["id"]))
                for rule_id in policy["rule_ids"]:
                    rule_ids.append(str(rule_id))
        logging.debug("  policy_ids: (%d) %s", len(policy_ids), policy_ids)
        logging.debug("  rule_ids: (%d) %s", len(rule_ids), rule_ids)

        for policy_id in policy_ids:
            logging.info("  Deleting policy: %s", policy_id)
            delete_lifecycle_policy(tmp_login_data, policy_id)

        # Clean up lifecycle rules
        # NOTE: Rule IDs start being collected above with the policies.
        # FIXME: For now, just going to remove the Rule IDs from above.  Should check for others
        #        by checking names of the rules for a project key or something.
        logging.info("Cleaning up AppTrust Lifecycle Rules")
        for rule_id in rule_ids:
            logging.info("  Deleting rule: %s", rule_id)
            delete_lifecycle_rule(tmp_login_data, rule_id)

        # Clean up users
        logging.info("Cleaning up Users")
        user_names = []
        user_list = list_users(tmp_login_data, project_key)
        project_user_list = list_project_users(tmp_login_data, project_key)
        logging.debug("  user_list: %s", user_list)
        logging.debug("  project_user_list: %s", project_user_list)
        for user in project_user_list["members"]:
            user_names.append(user["name"])
        logging.debug("  user_names: (%d) %s", len(user_names), user_names)
        for user_name in user_names:
            logging.info("  Deleting user: %s", user_name)
            delete_user(tmp_login_data, user_name)

        # Clean up roles
        logging.info("Cleaning up Custom Roles")
        role_names = []
        project_role_list = list_roles(tmp_login_data, project_key)
        logging.debug("  project_role_list: %s", project_role_list)
        for role in project_role_list:
            if role["type"] == "CUSTOM":
                role_names.append(role["name"])
        logging.debug("  role_names: (%d) %s", len(role_names), role_names)
        for role_name in role_names:
            logging.info("  Deleting role: %s", role_name)
            delete_role(tmp_login_data, project_key, role_name)

        # Clean up stages
        logging.info("Cleaning up AppTrust Lifecycle Stages")
        # NOTE: Have to remove the stages from the lifecycle itself before removing.
        set_lifecycle(tmp_login_data, project_key, [])
        stage_names = []
        stage_list = list_lifecycle_stages(tmp_login_data, project_key)
        logging.debug("stage_list: %s", app_list)
        for item in stage_list:
            # Can't delete the two permanent stages
            if item["name"] not in ["DEV", "PROD"]:
                stage_names.append(item["name"])
        logging.debug("  stage_names: (%d) %s", len(stage_names), stage_names)
        for stage_name in stage_names:
            logging.info("  Deleting Lifecycle Stage: %s", stage_name)
            delete_lifecycle_stage(tmp_login_data, project_key, stage_name)

        # Clean up project
        delete_project(tmp_login_data, project_key)

        # Clean up evidence keys
        # FIXME: Should this be handled here, or elsewhere?

    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

if __name__ == "__main__":
    main()

