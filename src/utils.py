import os
import json
import sysconfig


def load_json_from_package(resource):
    path = os.path.join(sysconfig.get_path("purelib"), resource)
    with open(path, "r") as file:
        # Load JSON data
        return json.load(file)
