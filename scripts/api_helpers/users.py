#!/usr/bin/env python3

### IMPORTS ###
import json

from .make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###
def list_users(login_data, project_key):
    # NOTE: Project Key should be None for global repositories.
    pass

def get_user(login_data, username):
    req_url = "/access/api/v2/users/{}".format(username)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def create_user(login_data, username, password, email):
    req_data = {
        "username": str(username),
        "password": str(password),
        "email": str(email)
    }
    req_url = "/access/api/v2/users"
    make_api_request(login_data, 'POST', req_url, req_data)

def update_user(login_data, project_key, repository_name, repository_data):
    # NOTE: Project Key should be None for global repositories.
    pass

def delete_user(login_data, project_key, repository_name):
    # NOTE: Project Key should be None for global repositories.
    pass

### CLASSES ###
