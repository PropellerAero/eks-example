      - host: ${host}
        http:
          paths:
            - backend:
                serviceName: ${service_name}
                servicePort: ${service_port}