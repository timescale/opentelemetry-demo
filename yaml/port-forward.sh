echo "Starting up port-forwards"
kubectl port-forward svc/generator 5000:5000 &
kubectl port-forward svc/digit 5001:5000 &
kubectl port-forward svc/special 5002:5000 &
kubectl port-forward svc/lower 5003:5000 &
kubectl port-forward svc/upper 5004:5000 &
kubectl port-forward svc/check 5005:5000 &
kubectl port-forward svc/grafana 3000 &
kubectl port-forward svc/jaeger 16686 &
kubectl port-forward svc/timescaledb 5432 &

