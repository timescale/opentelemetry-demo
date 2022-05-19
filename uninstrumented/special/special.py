import random
import time

from flask import Flask, Response
from flask.json import jsonify

app = Flask(__name__)

def work(mu: float, sigma: float) -> None:
    # simulate work being done
    time.sleep(max(0.0, random.normalvariate(mu, sigma)))


def random_special() -> str:
    work(0.0003, 0.0001)
    c = random.choice('!@#$%^&*<>,.:;?/+={}[]-_\|~`')
    return c


def process_special(c: str) -> str:
    work(0.0001, 0.00005)
    
    # these chars are extra slow
    if c in {'$', '@', '#', '?', '%'}:
        work(0.005, 0.0005)
    
    # these chars fail 5% of the time
    if c in {'!', '@', '?'} and random.random() > 0.95:
        e = Exception(f"FAILED to process {c}")
        raise e
    return c
        

def render_special(c: str) -> Response:
    work(0.0002, 0.0001)
    return jsonify(char=c)


@app.route('/')
def special():
    c = random_special()
    c = process_special(c)
    return render_special(c)


if __name__ == '__main__':
    app.run()
