import string
import random
import time

from flask import Flask, Response
from flask.json import jsonify
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

trace.set_tracer_provider(TracerProvider(resource=Resource.create({"service.name": "lower"})))
span_exporter = OTLPSpanExporter(endpoint="collector:4317")
trace_provider = trace.get_tracer_provider()
trace_provider.add_span_processor(BatchSpanProcessor(span_exporter))
FlaskInstrumentor().instrument_app(app, tracer_provider=trace_provider)
RequestsInstrumentor().instrument()
tracer = trace.get_tracer(__name__)


def work(mu: float, sigma: float) -> None:
    # simulate work being done
    time.sleep(max(0.0, random.normalvariate(mu, sigma)))


def get_digit() -> int:
    with tracer.start_as_current_span("get_digit") as span:
        try:
            response = requests.get("http://digit:5000/")
            c = response.json()['char']
            return int(c)
        except Exception as e:
            e = Exception(f"FAILED to fetch a digit char")
            span.record_exception(e)
            span.set_status(Status(StatusCode.ERROR, str(e)))
            raise e


def random_lower() -> str:
    with tracer.start_as_current_span("random_lower") as span:
        _ = get_digit()
        c = random.choice(string.ascii_lowercase)
        span.set_attribute('char', c)
        return c


def process_lower(c: str) -> str:
    with tracer.start_as_current_span("process_lower") as span:
        span.set_attribute('char', c)
        span.add_event("processing lower char", {'char': c})
        work(0.0001, 0.00005)

        # 1/100 calls is extra slow
        if random.random() > 0.99:
            span.add_event("extra work", {'char': c})
            work(0.0002, 0.0001)
        
        # these chars are extra slow
        if c in {'Z', 'X', 'R',}:
            with tracer.start_as_current_span(f"extra_process_lower") as span:
                span.set_attribute('char', c)
                work(0.005, 0.0005)
        
        # these chars are extra slow too
        if c in {'Z', 'A', 'T'}:
            with tracer.start_as_current_span(f"extra_extra_process_lower") as span:
                span.set_attribute('char', c)
                work(0.0001, 0.00008)
        return c


def render_lower(c: str) -> Response:
    with tracer.start_as_current_span(f"render_lower") as span:
        span.set_attribute('char', c)
        work(0.0002, 0.0001)
        return jsonify(char=c)


@app.route('/')
def lower():
    c = random_lower()
    c = process_lower(c)
    return render_lower(c)


if __name__ == '__main__':
    app.run()
