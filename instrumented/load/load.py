#!/usr/bin/env python3
import requests

def main():
    while True:
        try:
            response = requests.get('http://generator:5000/')
            password = response.json()['password']
            print(password)
        except Exception as e:
            print('FAILED to get a password!')


if __name__ == '__main__':
    main()