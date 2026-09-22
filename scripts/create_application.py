#!/usr/bin/env python3

### IMPORTS ###
import argparse
import logging
import os
import sys

from api_helpers.exceptions import NotFoundException
from api_helpers.applications import get_application, create_application

### GLOBALS ###
# FIXME: Not the best way to handle this, but don't want to pollute the workflow script with all the data.
APP_DEFINITIONS = {
    "checkout": {
        "application_key": "bookverse-checkout",
        "application_name": "BookVerse Checkout Service",
        "description": "Secure microservice handling payment processing, order fulfillment, and transaction management for book purchases",
        "criticality": "high",
        "maturity": "production",
        "team": "checkout-team",
        "owner": "henry.checkout@bookverse.com"
    },
    "helm": {
        "application_key": "bookverse-helm",
        "application_name": "BookVerse Helm Charts",
        "description": "Kubernetes deployment manifests and Helm charts for the BookVerse platform, providing infrastructure-as-code for container orchestration and service deployment.",
        "criticality": "high",
        "maturity": "production",
        "team": "devops-team",
        "owner": "helm.manager@bookverse.com"
    },
    "infra": {
        "application_key": "bookverse-infra",
        "application_name": "BookVerse Infrastructure",
        "description": "Consolidated infrastructure repository containing multiple packages: bookverse-core (Python commons library), bookverse-devops (CI/CD workflows and scripts), and evidence templates for the entire BookVerse platform.",
        "criticality": "high",
        "maturity": "production",
        "team": "infra-team",
        "owner": "infra.manager@bookverse.com"
    },
    "inventory": {
        "application_key": "bookverse-inventory",
        "application_name": "BookVerse Inventory Service",
        "description": "Microservice responsible for managing book inventory, stock levels, and availability tracking across all BookVerse locations.",
        "criticality": "high",
        "maturity": "production",
        "team": "inventory-team",
        "owner": "inventory.manager@bookverse.com"
    },
    "platform": {
        "application_key": "bookverse-platform",
        "application_name": "BookVerse Platform",
        "description": "Integrated platform solution combining all microservices with unified API gateway, monitoring, and operational tooling.",
        "criticality": "high",
        "maturity": "production",
        "team": "platform-team",
        "owner": "platform.manager@bookverse.com"
    },
    "recommendations": {
        "application_key": "bookverse-recommendations",
        "application_name": "BookVerse Recommendations Service",
        "description": "AI-powered microservice that provides personalized book recommendations based on user preferences, reading history, and collaborative filtering.",
        "criticality": "medium",
        "maturity": "production",
        "team": "ai-ml-team",
        "owner": "recommendations.manager@bookverse.com"
    },
    "web": {
        "application_key": "bookverse-web",
        "application_name": "BookVerse Web Application",
        "description": "Frontend web application delivering the BookVerse user interface and static assets, served via nginx with versioned bundles.",
        "criticality": "medium",
        "maturity": "production",
        "team": "web-team",
        "owner": "web.manager@bookverse.com"
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

    parser.add_argument("--project_key", default = os.getenv("PROJECT_KEY", None),
                        help = "Short version of the project name used for identifying the project.")

    parser.add_argument("component")

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

    if args.component not in APP_DEFINITIONS:
        logging.error("Not a valid component value.")
        sys.exit(1)
    app_pdata = APP_DEFINITIONS[str(args.component)]

    try:
        logging.info("Checking if application exists: %s - %s", project_key, app_pdata["application_key"])
        app_data = get_application(tmp_login_data, app_pdata["application_key"])
        logging.info("  Application already exists")
        # FIXME: Check the data for the Application and update if needed.
    except NotFoundException:
        try:
            logging.info("  Creating Application: %s - %s", project_key, app_pdata["application_key"])
            create_application(
                tmp_login_data,
                project_key,
                app_pdata["application_key"],
                app_pdata["application_name"],
                app_pdata["description"],
                app_pdata["criticality"],
                app_pdata["maturity"],
                app_pdata["team"],
                [app_pdata["owner"]],
                []
            )
        except Exception as ex:
            raise ex
    except Exception as ex:
        logging.error(ex)
        sys.exit(1)

if __name__ == "__main__":
    main()
