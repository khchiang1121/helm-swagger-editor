# Swagger Editor Helm Chart

This Helm chart deploys [Swagger Editor](https://swagger.io/tools/swagger-editor/), an open source editor for OpenAPI/Swagger definitions, to a Kubernetes cluster.

## Features
- Deploys the official Swagger Editor Docker image
- Exposes all configuration options supported by the Docker image via `values.yaml`
- Supports custom base URL, port, default API definition, and generator endpoints
- Easily configurable for ingress, resources, and more

## Installation

Add this chart to your Helm repository or use it locally:

```sh
helm install my-swagger-editor ./swagger-editor
```

## Configuration

All configuration options for Swagger Editor are available under the `swaggerEditor` section in `values.yaml`:

```yaml
swaggerEditor:
  url: ""  # URL to an API definition to load by default
  swaggerFile: ""  # Path to a swagger file to load (ignored if url is set)
  baseUrl: "/"  # Base URL for the application
  port: 8080  # Port to run the application on
  gtm: ""  # Google Tag Manager ID
  urlSwagger2Generator: "https://generator.swagger.io/api/swagger.json"
  urlOas3Generator: "https://generator3.swagger.io/openapi.json"
  urlSwagger2Converter: "https://converter.swagger.io/api/convert"
```

### Example

```yaml
swaggerEditor:
  url: "https://petstore3.swagger.io/api/v3/openapi.json"
  baseUrl: "/swagger-editor"
  port: 8080
```

Other standard Helm values (replicaCount, resources, ingress, etc.) are also supported.

## Upgrading

To upgrade the chart after changing values:

```sh
helm upgrade my-swagger-editor ./swagger-editor -f values.yaml
```

## License

This chart is provided under the Apache 2.0 License. 