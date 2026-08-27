#!/usr/bin/env python3

### IMPORTS ###
import json

from .make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###
def list_lifecycle_stages(login_data, project_key):
    # NOTE: Project Key should be None for global stages.
    pass

def get_lifecycle_stage(login_data, project_key, stage_name):
    # NOTE: Project Key should be None for global stages.
    req_url = "/access/api/v2/stages/{}".format(stage_name)
    if project_key is not None:
        req_url = "{}?project_key={}".format(req_url, project_key)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def create_lifecycle_stage(login_data, project_key, stage_name):
    # NOTE: Project Key should be None for global stages.
    req_url = "/access/api/v2/stages"
    req_data = {}
    if project_key is not None:
        req_data["name"] = "{}-{}".format(project_key, stage_name)
        req_data["project_key"] =  project_key
    else:
        req_data["name"] = stage_name
    req_data["category"] = "promote"
    make_api_request(login_data, 'POST', req_url, req_data)

def update_lifecycle_stages(login_data, project_key, stage_name, stage_data):
    # NOTE: Project Key should be None for global stages.
    pass

def delete_lifecycle_stages(login_data, project_key, stage_name):
    # NOTE: Project Key should be None for global stages.
    pass

### CLASSES ###
