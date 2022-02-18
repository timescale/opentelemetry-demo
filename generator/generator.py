import time
import random
from typing import Iterable

from flask import Flask
import requests

from opentelemetry import trace
from opentelemetry.trace import StatusCode, Status
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

app = Flask(__name__)

tracer_provider = TracerProvider(resource=Resource.create({"service.name": "generator"}))
tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(tracer_provider)
RequestsInstrumentor().instrument()
tracer = trace.get_tracer(__name__)


def work(mu: float, sigma: float) -> None:
    # simulate work being done
    time.sleep(max(0.0, random.normalvariate(mu, sigma)))


def uppers() -> Iterable[str]:
    with tracer.start_as_current_span("generator.uppers") as span:
        x = []
        for i in range(random.randint(0, 3)):
            span.add_event(f"iteration_{i}", {'iteration': i})
            try:
                response = requests.get("http://upper:5000/")
                c = response.json()['char']
            except Exception as e:
                e = Exception(f"FAILED to fetch a upper char")
                span.record_exception(e)
                span.set_status(Status(StatusCode.ERROR, str(e)))
                raise e
            x.append(c)
        return x


def lowers() -> Iterable[str]:
    with tracer.start_as_current_span("generator.lowers") as span:
        x = []
        for i in range(random.randint(0, 3)):
            span.add_event(f"iteration_{i}", {'iteration': i})
            try:
                response = requests.get("http://lower:5000/")
                c = response.json()['char']
            except Exception as e:
                e = Exception(f"FAILED to fetch a lower char")
                span.record_exception(e)
                span.set_status(Status(StatusCode.ERROR, str(e)))
                raise e
            x.append(c)
        return x


def digits() -> Iterable[str]:
    with tracer.start_as_current_span("generator.digits") as span:
        x = []
        for i in range(random.randint(0, 3)):
            span.add_event(f"iteration_{i}", {'iteration': i})
            try:
                response = requests.get("http://digit:5000/")
                c = response.json()['char']
            except Exception as e:
                e = Exception(f"FAILED to fetch a digit char")
                span.record_exception(e)
                span.set_status(Status(StatusCode.ERROR, str(e)))
                raise e
            x.append(c)
        return x


def specials() -> Iterable[str]:
    with tracer.start_as_current_span("generator.specials") as span:
        x = []
        for i in range(random.randint(0, 3)):
            span.add_event(f"iteration_{i}", {'iteration': i})
            try:
                response = requests.get("http://special:5000/")
                c = response.json()['char']
            except Exception as e:
                e = Exception(f"FAILED to fetch a special char")
                span.record_exception(e)
                span.set_status(Status(StatusCode.ERROR, str(e)))
                raise e
            x.append(c)
        return x


def generate() -> str:
    with tracer.start_as_current_span("generator.generate") as span:
        password = []
        span.add_event("selecting_password_length")
        work(0.00001, 0.00001)
        pwlen = random.randint(8, 25)
        span.set_attribute('pwlen', pwlen)
        i = 1
        while len(password) < pwlen:
            span.add_event(f"generate_loop_{i}", {'iteration': i})
            password.extend(uppers())
            password.extend(lowers())
            password.extend(digits())
            password.extend(specials())
            i = i + 1
        span.add_event("shuffling_password")
        random.shuffle(password)
        if len(password) > pwlen:
            span.add_event("trimming_password", {'pwlen': pwlen})
            password = password[:pwlen]
        return ''.join(password)
    

@app.route('/')
def generator():
    password = generate()
    return { 'password': password }


if __name__ == '__main__':
    app.run()
