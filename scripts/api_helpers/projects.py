#!/usr/bin/env python3

### IMPORTS ###
import json

from .make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###
def list_projects(login_data):
    pass

def get_project(login_data, project_key):
    req_url = "/access/api/v1/projects/{}".format(project_key)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def create_project(login_data, project_key, project_name):
    # FIXME: Allow setting the other data
    req_url = "/access/api/v1/projects"
    req_data = {
        "project_key": str(project_key),
        "display_name": str(project_name),
        "admin_privileges": {
            "manage_members": True,
            "manage_resources": True,
            "index_resources": True
        },
        "storage_quota_bytes": int(-1)
    }
    make_api_request(login_data, 'POST', req_url, req_data)

def update_project(login_data, project_key, project_data):
    pass

def delete_project(login_data, project_key):
    pass

### CLASSES ###
