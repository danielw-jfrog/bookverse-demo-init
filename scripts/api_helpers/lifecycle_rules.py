#!/usr/bin/env python3

### IMPORTS ###
import json

from .make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###
def list_lifecycle_rules(login_data):
    # FIXME: Add all of the other options
    # FIXME: Handle pagination (probably needs to be a "generator" method for this)
    req_url = "/unifiedpolicy/api/v1/rules?limit=1000"
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def get_lifecycle_rule(login_data, rule_id, expand_template = False):
    req_url = "/unifiedpolicy/api/v1/rules/{}".format(rule_id)
    if expand_template:
        req_url = "{}?expand=template".format(req_url)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def create_lifecycle_rule(login_data, rule_name, description, template_id, predicate_type):
    # FIXME: Support more parameters
    req_url = "/unifiedpolicy/api/v1/rules"
    req_data = {
        "name": rule_name,
        "description": description,
        "is_custom": True,
        "parameters": [
            {
                "name": "predicateType",
                "value": predicate_type
            }
        ],
        "template_id": template_id
    }
    make_api_request(login_data, 'POST', req_url, req_data)

def update_lifecycle_rule(login_data, rule_id):
    raise NotImplemented

def delete_lifecycle_rule(login_data, rule_id):
    raise NotImplemented

### CLASSES ###
