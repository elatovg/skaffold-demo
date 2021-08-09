#!/usr/bin/env python3
"""
Simple Flask App to return a string
and also provide a /status end point
"""
from flask import Flask, json, Response

app = Flask(__name__)


@app.route('/status', methods=['GET'])
def get_status():
    """ Return HTTP Code 200 """
    data = {
        'status': 'up',
    }
    jsn = json.dumps(data)

    resp = Response(jsn, status=200, mimetype='application/json')

    return resp


@app.route('/')
def hello_world():
    """ Return a simple string"""
    return 'Hello Folks, I like containers\n'


if __name__ == "__main__":
    # app.run(debug=True)
    app.run(host="0.0.0.0", port=8000)
