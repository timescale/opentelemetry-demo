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

tracer_provider = TracerProvider(resource=Resource.create({"service.name": "special"}))
tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(tracer_provider)
FlaskInstrumentor().instrument_app(app)
tracer = trace.get_tracer(__name__)


def work(mu: float, sigma: float) -> None:
    # simulate work being done
    time.sleep(max(0.0, random.normalvariate(mu, sigma)))


def random_special() -> str:
    with tracer.start_as_current_span("random_special") as span:
        work(0.0003, 0.0001)
        c = random.choice('!@#$%^&*<>,.:;?/+={}[]-_\|~`')
        span.set_attribute('char', c)
        return c


def process_special(c: str) -> str:
    with tracer.start_as_current_span("process_special") as span:
        span.set_attribute('char', c)
        span.add_event("processing special char", {'char': c})
        work(0.0001, 0.00005)
        
        # these chars are extra slow
        if c in {'$', '@', '#', '?', '%'}:
            with tracer.start_as_current_span(f"extra_process_special") as span:
                span.set_attribute('char', c)
                work(0.005, 0.0005)
        
        # these chars fail 5% of the time
        if c in {'!', '@', '?'} and random.random() > 0.95:
            e = Exception(f"FAILED to process {c}")
            span.record_exception(e, {'char': c})
            span.set_status(Status(StatusCode.ERROR, str(e)))
            raise e
        return c
        

def render_special(c: str) -> Response:
    with tracer.start_as_current_span(f"render_special") as span:
        span.set_attribute('char', c)
        work(0.0002, 0.0001)
        return jsonify(char=c)


@app.route('/')
def special():
    c = random_special()
    c = process_special(c)
    return render_special(c)


if __name__ == '__main__':
    app.run()
