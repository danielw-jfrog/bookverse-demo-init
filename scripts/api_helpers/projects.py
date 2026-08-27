#!/usr/bin/env python3

### IMPORTS ###
from .make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###
def create_project(login_data, project_key, project_name):
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

### CLASSES ###
