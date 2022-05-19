FROM python:latest
WORKDIR /code
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY digit.py .
EXPOSE 5000
ENV FLASK_APP=digit
CMD ["flask", "run", "--host=0.0.0.0"]
