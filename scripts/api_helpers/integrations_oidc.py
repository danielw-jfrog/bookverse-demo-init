#!/usr/bin/env python3

### IMPORTS ###
import json

from .make_api_request import make_api_request

### GLOBALS ###

### FUNCTIONS ###
# OIDC Integrations
def list_oidc_integrations(login_data):
    req_url = "/access/api/v1/oidc"
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def get_oidc_integration(login_data, oidc_name):
    req_url = "/access/api/v1/oidc/{}".format(oidc_name)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def create_oidc_integration(login_data, oidc_name, provider_type, issuer_url, audience, token_issuer, description):
    req_data = {
        "name": oidc_name,
        "provider_type": provider_type,
        "issuer_url": issuer_url,
        "audience": audience,
        "token_issuer": token_issuer,
        "description": description
    }
    req_url = "/access/api/v1/oidc"
    make_api_request(login_data, 'POST', req_url, req_data)

def update_oidc_integration(login_data, project_key, role_name, role_data):
    # NOTE: Project Key should be None for global oidc integrations.
    raise NotImplemented

def delete_oidc_intergration(login_data, project_key, role_name):
    # NOTE: Project Key should be None for global oidc integrations.
    raise NotImplemented

# OIDC Identity Mappings
def list_oidc_identity_mappings(login_data, project_key, provider_name):
    # NOTE: Project Key should be None for global oidc identity mappings.
    req_url = "/access/api/v1/oidc/{}/identity_mappings".format(provider_name)
    if project_key is not None:
        req_url = "{}?project_key={}".format(req_url, project_key)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def get_oidc_identity_mapping(login_data, provider_name, mapping_name):
    req_url = "/access/api/v1/oidc/{}/identity_mappings/{}".format(provider_name, mapping_name)
    resp = make_api_request(login_data, 'GET', req_url)
    return json.loads(resp)

def create_oidc_identity_mapping(login_data, provider_name, mapping_name, description, priority, claims, token_spec):
    # NOTE: Project Key should be None for global oidc identity mapping.
    req_data = {
        "name": mapping_name,
        "description": description,
        "priority": int(priority),
        "claims": claims,
        "token_spec": token_spec
    }
    req_url = "/access/api/v1/oidc/{}/identity_mappings".format(provider_name)
    make_api_request(login_data, 'POST', req_url, req_data)

def update_oidc_identity_mapping(login_data, project_key, role_name, role_data):
    # NOTE: Project Key should be None for global oidc identity mapping.
    raise NotImplemented

def delete_oidc_identity_mapping(login_data, project_key, role_name):
    # NOTE: Project Key should be None for global oidc identity mapping.
    raise NotImplemented

### CLASSES ###
