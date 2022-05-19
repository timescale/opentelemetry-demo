FROM python:latest
WORKDIR /code
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY load.py .
CMD ["python3", "load.py"]
