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
    # req_url = "/apptrust/api/v1/applications/{}/versions".format(application_key)
    # resp = make_api_request(login_data, 'GET', req_url)
    # return json.loads(resp)
    raise NotImplemented

def create_application_version(login_data, project_key, application_key, version, version_tag, sources):
    # FIXME: Add the other options
    req_url = "/apptrust/api/v1/applications/{}/versions".format(application_key)
    req_data = {
        "version": version,
        "tag": version_tag,
        "sources": sources
    }
    make_api_request(login_data, 'POST', req_url, req_data)

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
