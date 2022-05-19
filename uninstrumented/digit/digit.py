import string
import random
import time
from math import sin

from flask import Flask, Response
from flask.json import jsonify
app = Flask(__name__)


def work(mu: float, sigma: float) -> None:
    # simulate work being done
    time.sleep(max(0.0, random.normalvariate(mu, sigma)))


def random_digit() -> str:
    work(0.0003, 0.0001)

        # slowness varies with the minute of the hour
    time.sleep(sin(time.localtime().tm_min) + 1.0)

    c = random.choice(string.digits)
    return c


def process_digit(c: str) -> str:
    work(0.0001, 0.00005)

    # 1/100 calls is extra slow when the digit is even
    if random.random() > 0.99 and int(c) % 2 == 0:
        work(0.0002, 0.0001)
        
    # these chars are extra slow
    if c in {'4', '5', '6',}:
        work(0.005, 0.0005)
    return c
        

def render_digit(c: str) -> Response:
    work(0.0002, 0.0001)

    # every five minutes something goes wrong
    if time.localtime().tm_min % 5 == 0:
        work(0.05, 0.005)
    
    return jsonify(char=c)


@app.route('/')
def digit():
    c = random_digit()
    c = process_digit(c)
    return render_digit(c)


if __name__ == '__main__':
    app.run()
