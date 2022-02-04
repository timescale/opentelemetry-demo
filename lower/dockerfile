FROM ruby:2.7
WORKDIR /code
COPY Gemfile .

RUN bundle install
COPY ./ /code

EXPOSE 5000

ENV APP_NAME=lower
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4318

CMD ["bundle", "exec", "ruby", "lower.rb"]
