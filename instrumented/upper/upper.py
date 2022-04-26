import string
import random
import time

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

tracer_provider = TracerProvider(resource=Resource.create({"service.name": "upper"}))
tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(tracer_provider)
FlaskInstrumentor().instrument_app(app)
tracer = trace.get_tracer(__name__)


def work(mu: float, sigma: float) -> None:
    # simulate work being done
    time.sleep(max(0.0, random.normalvariate(mu, sigma)))


def random_upper() -> str:
    with tracer.start_as_current_span("random_upper") as span:
        # gets progressively slower throughout the hour
        work(time.localtime().tm_min / 10000.0, 0.00001)
        c = random.choice(string.ascii_uppercase)
        span.set_attribute('char', c)
        return c


def process_upper(c: str) -> str:
    with tracer.start_as_current_span("process_upper") as span:
        span.set_attribute('char', c)
        span.add_event("processing upper char", {'char': c})
        work(0.0001, 0.00005)

        # 1/100 calls is extra slow
        if random.random() > 0.99:
            span.add_event("extra work", {'char': c})
            work(0.0002, 0.0001)
        
        # these chars are extra slow
        if c in {'Z', 'X', 'R',}:
            with tracer.start_as_current_span(f"extra_process_upper") as span:
                span.set_attribute('char', c)
                work(0.005, 0.0005)
        
        # these chars are extra slow and sometimes fail
        if c in {'Z', 'A', 'T'}:
            with tracer.start_as_current_span(f"extra_extra_process_upper") as span:
                span.set_attribute('char', c)
                work(0.0001, 0.00008)
                # fails 5% of the time
                if random.random() > 0.95:
                    e = Exception(f"FAILED to process {c}")
                    span.record_exception(e, {'char': c})
                    span.set_status(Status(StatusCode.ERROR, str(e)))
                    raise e
        return c
        

def render_upper(c: str) -> Response:
    with tracer.start_as_current_span(f"render_upper") as span:
        span.set_attribute('char', c)
        work(0.0002, 0.0001)
        return jsonify(char=c)


@app.route('/')
def upper():
    c = random_upper()
    c = process_upper(c)
    return render_upper(c)


if __name__ == '__main__':
    app.run()
