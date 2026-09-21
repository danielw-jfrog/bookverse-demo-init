#!/usr/bin/env python3

### IMPORTS ###
import json

from .make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###
def list_users(login_data):
    # FIXME: Add all of the available options
    req_url = "/access/api/v2/users"
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def get_user(login_data, project_key, username):
    req_url = "/access/api/v2/users/{}".format(username)
    if project_key is not None:
        req_url = "/access/api/v1/projects/{}/users/{}".format(project_key, username)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def create_user(login_data, username, password, email):
    req_data = {
        "username": str(username),
        "password": str(password),
        "email": str(email),
        "admin": False,
        "profileUpdatable": True,
        "disableUIAccess": False,
        "groups": ["readers"]
    }
    req_url = "/access/api/v2/users"
    make_api_request(login_data, 'POST', req_url, req_data)

def update_user(login_data, username, user_data):
    raise NotImplemented

def delete_user(login_data, username):
    raise NotImplemented

def assign_roles_to_user(login_data, project_key, username, role_list):
    # NOTE: Project Key should be None for global roles.
    # FIXME: Can't seem to find the API docs for adding global roles to user.
    if project_key is None:
        raise NotImplemented
    req_data = {
        "roles": role_list
    }
    req_url = "/access/api/v1/projects/{}/users/{}".format(str(project_key), str(username))
    make_api_request(login_data, 'PUT', req_url, req_data)

### CLASSES ###
