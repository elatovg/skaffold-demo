#!/usr/bin/env python3
from flask import Flask, json, Response

app = Flask(__name__)


@app.route('/status', methods=['GET'])
def get_status():
    data = {
        'status': 'up',
    }
    js = json.dumps(data)

    resp = Response(js, status=200, mimetype='application/json')

    return resp


@app.route('/')
def hello_world():
    return 'Hello Folks, I like containers\n'


if __name__ == "__main__":
    # app.run(debug=True)
    app.run(host="0.0.0.0", port=8000)
