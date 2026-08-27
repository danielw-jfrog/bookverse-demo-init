#!/usr/bin/env python3

### IMPORTS ###
import json

from .make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###
def list_repositories(login_data, project_key):
    # NOTE: Project Key should be None for global repositories.
    pass

def get_repository(login_data, project_key, repository_name):
    # NOTE: Project Key should be None for global repositories.
    repo_key = repository_name
    if project_key is not None:
        repo_key = "{}-{}".format(project_key, repository_name)
    req_url = "/artifactory/api/v2/repositories/{}".format(repo_key)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def create_local_repository(login_data, project_key, repository_name, stage_name, package_type):
    # NOTE: Project Key should be None for global repositories.
    req_data = {
        "rclass": "local",
        "key": repository_name,
        "packageType": package_type
    }
    if project_key is not None:
        req_data["key"] = "{}-{}".format(project_key, repository_name)
        req_data["projectKey"] =  project_key
    if stage_name is not None:
        req_data["environments"] = [stage_name]
    req_url = "/artifactory/api/repositories/{}".format(req_data["key"])
    make_api_request(login_data, 'PUT', req_url, req_data)

def create_remote_repository(login_data, project_key, repository_name, package_type, external_url):
    # NOTE: Project Key should be None for global repositories.
    pass

def update_repositories(login_data, project_key, repository_name, repository_data):
    # NOTE: Project Key should be None for global repositories.
    pass

def delete_repositories(login_data, project_key, repository_name):
    # NOTE: Project Key should be None for global repositories.
    pass

### CLASSES ###
