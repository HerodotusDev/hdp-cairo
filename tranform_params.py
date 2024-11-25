#!venv/bin/python3

import json
import sys

input_data = sys.stdin.read()

data = eval(input_data.strip())[0]

data = [len(data)] + data

transformed_data = [
    {"visibility": "public", "value": hex(value)}
    for value in data
]

sys.stdout.write(json.dumps(transformed_data, indent=4) + "\n")