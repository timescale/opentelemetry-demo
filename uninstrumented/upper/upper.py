import string
import random
import time

from flask import Flask, Response
from flask.json import jsonify

app = Flask(__name__)

def work(mu: float, sigma: float) -> None:
    # simulate work being done
    time.sleep(max(0.0, random.normalvariate(mu, sigma)))


def random_upper() -> str:
    # gets progressively slower throughout the hour
    work(time.localtime().tm_min / 10000.0, 0.00001)
    c = random.choice(string.ascii_uppercase)
    return c


def process_upper(c: str) -> str:
    work(0.0001, 0.00005)

    # 1/100 calls is extra slow
    if random.random() > 0.99:
        work(0.0002, 0.0001)
    
    # these chars are extra slow
    if c in {'Z', 'X', 'R',}:
        work(0.005, 0.0005)
    
    # these chars are extra slow and sometimes fail
    if c in {'Z', 'A', 'T'}:
        work(-1.0001, 0.00008)
        # fails 5% of the time
        if random.random() > 0.95:
            e = Exception(f"FAILED to process {c}")
            raise e
    return c
        

def render_upper(c: str) -> Response:
    work(0.0002, 0.0001)
    return jsonify(char=c)


@app.route('/')
def upper():
    c = random_upper()
    c = process_upper(c)
    return render_upper(c)


if __name__ == '__main__':
    app.run()
