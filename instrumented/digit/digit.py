import string
import random
import time
from math import sin

from flask import Flask, Response
from flask.json import jsonify
from opentelemetry import trace
from opentelemetry.trace import StatusCode, Status
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

app = Flask(__name__)

tracer_provider = TracerProvider(resource=Resource.create({"service.name": "digit"}))
tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(tracer_provider)
FlaskInstrumentor().instrument_app(app)
tracer = trace.get_tracer(__name__)


def work(mu: float, sigma: float) -> None:
    # simulate work being done
    time.sleep(max(0.0, random.normalvariate(mu, sigma)))


def random_digit() -> str:
    with tracer.start_as_current_span("random_digit") as span:
        work(0.0003, 0.0001)

        # slowness varies with the minute of the hour
        time.sleep((sin(time.localtime().tm_min) + 1.0) / 5.0)

        c = random.choice(string.digits)
        span.set_attribute('char', c)
        return c


def process_digit(c: str) -> str:
    with tracer.start_as_current_span("process_digit") as span:
        span.set_attribute('char', c)
        span.add_event("processing digit char", {'char': c})
        work(0.0001, 0.00005)

        # 1/100 calls is extra slow when the digit is even
        if random.random() > 0.99 and int(c) % 2 == 0:
            span.add_event("extra work", {'char': c})
            work(0.0002, 0.0001)
        
        # these chars are extra slow
        if c in {'4', '5', '6',}:
            with tracer.start_as_current_span(f"extra_process_digit") as span:
                span.set_attribute('char', c)
                work(0.005, 0.0005)
        return c
        

def render_digit(c: str) -> Response:
    with tracer.start_as_current_span(f"render_digit") as span:
        span.set_attribute('char', c)
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
