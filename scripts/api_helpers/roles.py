#!/usr/bin/env python3

### IMPORTS ###
import json

from .make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###
def list_roles(login_data, project_key):
    # NOTE: Project Key should be None for global roles.
    pass

def get_role(login_data, project_key, role_name):
    # NOTE: Project Key should be None for global roles.
    req_url = "/access/api/v1/roles/{}".format(role_name)
    if project_key is not None:
        req_url = "/access/api/v1/projects/{}/roles/{}".format(project_key, role_name)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def create_role(login_data, project_key, role_name, description, actions_list, environments_list):
    # NOTE: Project Key should be None for global roles.
    req_data = {
        "name": role_name,
        "description": description,
        "type": "CUSTOM",
        "actions": actions_list,
        "environments": environments_list
    }
    req_url = "/access/api/v1/roles"
    if project_key is not None:
        req_url = "/access/api/v1/projects/{}/roles".format(project_key)
    make_api_request(login_data, 'POST', req_url, req_data)

def update_role(login_data, project_key, role_name, role_data):
    # NOTE: Project Key should be None for global roles.
    pass

def delete_role(login_data, project_key, role_name):
    # NOTE: Project Key should be None for global roles.
    pass

### CLASSES ###
