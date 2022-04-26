import psycopg2


from flask import Flask, Response, request

app = Flask(__name__)

def check_password(digest: str) -> bool:
    cnx = psycopg2.connect(host='timescaledb',database='otel_demo',user='postgres')
    cursor = cnx.cursor()
    # This will get an exception if the password has been used
    # as the PRIMARY KEY will clash
    cursor.execute("INSERT INTO used_passwords VALUES (%s)", (digest,))
    cursor.close()
    cnx.commit()
    cnx.close()
    return 'OK'
        

@app.route('/')
def check():
    return check_password(request.args.get('digest'))


if __name__ == '__main__':
    app.run()
