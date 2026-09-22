#!/usr/bin/env python3

### IMPORTS ###
import json

from .make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###
def list_applications(login_data, project_key = None):
    # FIXME: Add the other options
    req_url = "/apptrust/api/v1/applications"
    if project_key is not None:
        req_url = "{}?project_key={}".format(req_url, project_key)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def get_application(login_data, application_key):
    req_url = "/apptrust/api/v1/applications/{}".format(application_key)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def create_application(login_data, project_key, application_key, application_name, description, criticality, maturity, team, user_owners = [], group_owners = []):
    req_url = "/apptrust/api/v1/applications"
    req_data = {
        "project_key": project_key,
        "application_key": application_key,
        "application_name": application_name,
        "description": description,
        "criticality": criticality,
        "maturity_level": maturity,
        "labels": {
            "team": team,
            "type": "microservice",
            "architecture": "microservices",
            "environment": "production"
        },
        "user_owners": user_owners,
        "group_owners": group_owners
    }
    make_api_request(login_data, 'POST', req_url, req_data)

def update_application(login_data, project_key, application_name, application_data):
    pass

def delete_application(login_data, project_key, application_name):
    pass

### CLASSES ###
