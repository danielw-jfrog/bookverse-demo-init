#!/usr/bin/env python3

### IMPORTS ###
import json

from .make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###
def list_application_versions(login_data, application_key):
    # FIXME: Add the other options
    req_url = "/apptrust/api/v1/applications/{}/versions?limit=1000".format(application_key)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def get_application_version(login_data, project_key, application_key):
    # req_url = "/apptrust/api/v1/applications/{}".format(application_key)
    # resp = make_api_request(login_data, 'GET', req_url)
    # return json.loads(resp)
    raise NotImplemented

def create_application_version(login_data, project_key, application_key, application_name, description, criticality, maturity, team, user_owners = [], group_owners = []):
    # req_url = "/apptrust/api/v1/applications"
    # req_data = {
    #     "project_key": project_key,
    #     "application_key": application_key,
    #     "application_name": application_name,
    #     "description": description,
    #     "criticality": criticality,
    #     "maturity_level": maturity,
    #     "labels": {
    #         "team": team,
    #         "type": "microservice",
    #         "architecture": "microservices",
    #         "environment": "production"
    #     },
    #     "user_owners": user_owners,
    #     "group_owners": group_owners
    # }
    # make_api_request(login_data, 'POST', req_url, req_data)
    raise NotImplemented

def update_application_version(login_data, application_key, application_data):
    raise NotImplemented

def delete_application_version(login_data, application_key, application_version, asynchronous = False):
    req_url = "/apptrust/api/v1/applications/{}/versions/{}?async={}".format(
        application_key,
        application_version,
        "true" if asynchronous else "false"
    )
    make_api_request(login_data, 'DELETE', req_url)

### CLASSES ###
