#!/usr/bin/env python3

### IMPORTS ###
import json

from .make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###
def list_lifecycle_policies(login_data, project_key = None):
    # FIXME: Add all of the other options
    # FIXME: Handle pagination (probably needs to be a "generator" method for this)
    req_url = "/unifiedpolicy/api/v1/policies?limit=1000"
    if project_key is not None:
        req_url = "{}&project_key={}".format(req_url, project_key)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def get_lifecycle_policy(login_data, policy_id):
    req_url = "/unifiedpolicy/api/v1/policies/{}".format(policy_id)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def create_lifecycle_policy(login_data, project_key, policy_name, description, stage, gate, rule_ids, mode):
    # NOTE: Project Key should be None for global policies.
    # FIXME: Policies can be applied globally, on project, or on application.
    #        Application labels can also be used to filter policy application.
    #        Support all these option later.
    req_url = "/unifiedpolicy/api/v1/policies"
    req_data = {
        "name": policy_name,
        "description": description,
        "enabled": True,
        "mode": mode,
        "action": {
            "type": "certify_to_gate",
            "stage": {
                "key": stage,
                "gate": gate
            }
        },
        "scope": {
            "type": "project",
            "project_keys": [project_key]
        },
        "rule_ids": rule_ids
    }
    make_api_request(login_data, 'POST', req_url, req_data)

def update_lifecycle_policys(login_data, project_key, policy_name, policy_data):
    # NOTE: Project Key should be None for global policys.
    raise NotImplemented

def delete_lifecycle_policys(login_data, project_key, policy_name):
    # NOTE: Project Key should be None for global policys.
    raise NotImplemented

### CLASSES ###
