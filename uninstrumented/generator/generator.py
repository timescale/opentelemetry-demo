import time
import hashlib
import random
from typing import Iterable

from flask import Flask
import requests

app = Flask(__name__)

def work(mu: float, sigma: float) -> None:
    # simulate work being done
    time.sleep(max(0.0, random.normalvariate(mu, sigma)))


def uppers() -> Iterable[str]:
    x = []
    for i in range(random.randint(0, 3)):
        try:
            response = requests.get("http://upper:5000/")
            c = response.json()['char']
        except Exception as e:
            e = Exception(f"FAILED to fetch a upper char")
            raise e
        x.append(c)
    return x


def lowers() -> Iterable[str]:
    x = []
    for i in range(random.randint(0, 3)):
        try:
            response = requests.get("http://lower:5000/")
            c = response.json()['char']
        except Exception as e:
            e = Exception(f"FAILED to fetch a lower char")
            raise e
        x.append(c)
    return x


def digits() -> Iterable[str]:
    x = []
    for i in range(random.randint(0, 3)):
        try:
            response = requests.get("http://digit:5000/")
            c = response.json()['char']
        except Exception as e:
            e = Exception(f"FAILED to fetch a digit char")
            raise e
        x.append(c)
    return x


def specials() -> Iterable[str]:
    x = []
    for i in range(random.randint(0, 3)):
        try:
            response = requests.get("http://special:5000/")
            c = response.json()['char']
        except Exception as e:
            e = Exception(f"FAILED to fetch a special char")
            raise e
        x.append(c)
    return x

def check(password):
    try:
        response = requests.get(
                "http://check:5000/", 
                params={'digest':hashlib.sha224(password.encode("utf-8")).hexdigest()}
                )
    except Exception as e:
        e = Exception(f"FAILED, password matches previous password")
        raise e

def generate() -> str:
    password = []
    work(0.00001, 0.00001)
    pwlen = random.randint(8, 25)
    i = 1
    while len(password) < pwlen:
        password.extend(uppers())
        password.extend(lowers())
        password.extend(digits())
        password.extend(specials())
        i = i + 1
    random.shuffle(password)
    if len(password) > pwlen:
        password = password[:pwlen]
    if random.randint(1, 100) == 1:
        password = list('password123')
    check(''.join(password))
    return ''.join(password)
    

@app.route('/')
def generator():
    password = generate()
    return { 'password': password }


if __name__ == '__main__':
    app.run()
