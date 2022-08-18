FROM grafana/grafana-oss:9.0.0
COPY grafana.ini /etc/grafana/grafana.ini
COPY datasources.yaml  /etc/grafana/provisioning/datasources/datasources.yaml
COPY dashboards.yaml /etc/grafana/provisioning/dashboards/dashboards.yaml
COPY APM-dashboards /etc/grafana/provisioning/dashboards/APM_Demo
COPY monitoring /etc/grafana/provisioning/dashboards/Monitoring
COPY dashboards /etc/grafana/provisioning/dashboards/Demo
COPY workshop /etc/grafana/provisioning/dashboards/Workshop
