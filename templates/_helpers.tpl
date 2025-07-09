{{/*
Expand the name of the chart.
*/}}
{{- define "swagger-editor.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "swagger-editor.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "swagger-editor.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "swagger-editor.labels" -}}
helm.sh/chart: {{ include "swagger-editor.chart" . }}
{{ include "swagger-editor.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "swagger-editor.selectorLabels" -}}
app.kubernetes.io/name: {{ include "swagger-editor.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Swagger Editor component labels
*/}}
{{- define "swagger-editor.componentLabels" -}}
{{- include "swagger-editor.labels" . }}
app.kubernetes.io/component: swagger-editor
{{- end }}

{{/*
Swagger Editor component selector labels
*/}}
{{- define "swagger-editor.componentSelectorLabels" -}}
{{- include "swagger-editor.selectorLabels" . }}
app.kubernetes.io/component: swagger-editor
{{- end }}

{{/*
Swagger Generator v2 component labels
*/}}
{{- define "swagger-generator-v2.componentLabels" -}}
{{- include "swagger-editor.labels" . }}
app.kubernetes.io/component: swagger-generator-v2
{{- end }}

{{/*
Swagger Generator v2 component selector labels
*/}}
{{- define "swagger-generator-v2.componentSelectorLabels" -}}
{{- include "swagger-editor.selectorLabels" . }}
app.kubernetes.io/component: swagger-generator-v2
{{- end }}

{{/*
Swagger Generator v3 component labels
*/}}
{{- define "swagger-generator-v3.componentLabels" -}}
{{- include "swagger-editor.labels" . }}
app.kubernetes.io/component: swagger-generator-v3
{{- end }}

{{/*
Swagger Generator v3 component selector labels
*/}}
{{- define "swagger-generator-v3.componentSelectorLabels" -}}
{{- include "swagger-editor.selectorLabels" . }}
app.kubernetes.io/component: swagger-generator-v3
{{- end }}

{{/*
OpenAPI Generator component labels
*/}}
{{- define "openapi-generator.labels" -}}
{{- include "swagger-editor.labels" . }}
app.kubernetes.io/component: openapi-generator
{{- end }}

{{/*
OpenAPI Generator selector labels
*/}}
{{- define "openapi-generator.selectorLabels" -}}
{{- include "swagger-editor.selectorLabels" . }}
app.kubernetes.io/component: openapi-generator
{{- end }}

{{/*
Swagger Converter v1 component labels
*/}}
{{- define "swagger-converter-v1.componentLabels" -}}
{{- include "swagger-editor.labels" . }}
app.kubernetes.io/component: swagger-converter-v1
{{- end }}

{{/*
Swagger Converter v1 component selector labels
*/}}
{{- define "swagger-converter-v1.componentSelectorLabels" -}}
{{- include "swagger-editor.selectorLabels" . }}
app.kubernetes.io/component: swagger-converter-v1
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "swagger-editor.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "swagger-editor.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
