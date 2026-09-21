#!/usr/bin/env python3

### IMPORTS ###
import json

from .make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###
def list_groups(login_data, limit = 1000):
    # FIXME: Add pagination for request
    # FIXME: Add project_key
    # FIXME: Add group_name_pattern
    req_url = "/access/api/v2/groups"
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def get_group(login_data, group_name):
    req_url = "/access/api/v2/groups/{}".format(group_name)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def create_group(login_data, group_name, description = None):
    # FIXME: Add other options
    req_data = {
        "name": str(group_name)
    }
    if description is not None:
        req_data["description"] = str(description)
    req_url = "/access/api/v2/users"
    make_api_request(login_data, 'POST', req_url, req_data)

def update_group(login_data, group_name, group_data):
    raise NotImplemented

def delete_group(login_data, group_name):
    req_url = "/access/api/v2/groups/{}".format(group_name)
    make_api_request(login_data, 'DELETE', req_url)

def add_users_to_group(login_data, group_name, username_list):
    req_data = {
        "add": username_list
    }
    req_url = "/access/api/v2/groups/{}/members".format(group_name)
    make_api_request(login_data, 'PATCH', req_url, req_data)

def remove_users_from_group(login_data, group_name, username_list):
    req_data = {
        "remove": username_list
    }
    req_url = "/access/api/v2/groups/{}/members".format(group_name)
    make_api_request(login_data, 'PATCH', req_url, req_data)

### CLASSES ###
