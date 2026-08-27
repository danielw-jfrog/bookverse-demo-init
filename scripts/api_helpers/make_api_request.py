#!/usr/bin/env python3

### IMPORTS ###
#!/usr/bin/env python3

### IMPORTS ###
import json
import logging
import urllib.request
import urllib.error
import urllib.parse

### GLOBALS ###

### FUNCTIONS ###
def make_api_request(login_data, method, path, data = None, is_data_json = True):
    # Send the request to the JFrog Artifactory API.
    req_url = "{}{}".format(login_data["host"], urllib.parse.quote(path, safe="/?=,&"))
    req_headers = {}
    req_data = None
    if is_data_json:
        req_headers["Content-Type"] = "application/json"
        req_data = json.dumps(data).encode("utf-8") if data is not None else None
    else:
        req_headers["Content-Type"] = "text/plain"
        req_data = data.encode("utf-8") if data is not None else None

    logging.debug("req_url: %s", req_url)
    logging.debug("req_headers: %s", req_headers)
    logging.debug("req_data: %s", req_data)

    req_headers["Authorization"] = "Bearer {}".format(login_data["token"])

    request = urllib.request.Request(req_url, data = req_data, headers = req_headers, method = method)
    resp = None
    try:
        with urllib.request.urlopen(request) as response:
            # Check the status and log
            # NOTE: response.status for Python >=3.9, change to response.code if Python <=3.8
            resp = response.read().decode("utf-8")
            logging.debug("  Response Status: %d, Response Body: %s", response.status, resp)
            logging.debug("Repository operation successful")
    except urllib.error.HTTPError as ex:
        logging.warning("Error (%d) for operation", ex.code)
        logging.debug("  response body: %s", ex.read().decode("utf-8"))
        raise Exception("Fail Build")
    except urllib.error.URLError as ex:
        logging.error("Request Failed (URLError): %s", ex.reason)
        raise Exception("Fail Build")
    # FIXME: Should make the status code available to the calling method.
    return resp

### CLASSES ###
