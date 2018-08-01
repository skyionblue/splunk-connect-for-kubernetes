{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "splunk-kubernetes-logging.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "splunk-kubernetes-logging.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "splunk-kubernetes-logging.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
The jq filter used to generate source and sourcetype for container logs.
Define it as a template here so there we don't need to escape the double quotes `` " ''.
To find the sourcetype, it cannot use map here, because the `pod` extracted from source
is not exact the pod name. That's why we generated all those `if-elif-then` here.
*/}}
{{- define "splunk-kubernetes-logging.container_jq_filter" -}}
{{- $logs := dict "list" list }}
{{- range $name, $logDef := .Values.logs }}
{{- if (and $logDef.from.pod $logDef.sourcetype) }}
{{- set $logs "list" (append $logs.list (dict "name" $name "from" $logDef.from "sourcetype" $logDef.sourcetype)) | and nil }}
{{- end }}
{{- end -}}
def find_sourcetype(pod; container_name):
{{- with first $logs.list }}
container_name + "/" + pod |
if startswith({{ list (or .from.container .name) .from.pod | join "/" | quote }}) then {{ .sourcetype | quote }}
{{- end }}
{{- range rest $logs.list }}
elif startswith({{ list (or .from.container .name) .from.pod | join "/" | quote }}) then {{ .sourcetype | quote }}
{{- end }}
else empty
end;

def extract_container_info:
  (.source | ltrimstr("/var/log/containers/") | split("_")) as $parts
  | ($parts[-1] | split("-")) as $cparts
  | .pod = $parts[0]
  | .namespace = $parts[1]
  | .container_name = ($cparts[:-1] | join("-"))
  | .container_id = ($cparts[-1] | rtrimstr(".log"))
  | .;
  
.record | extract_container_info | .sourcetype = (find_sourcetype(.pod; .container_name) // "kube:container:\(.container_name)")
{{- end -}}
