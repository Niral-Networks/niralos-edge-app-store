{{/*
Expand the name of the chart.
*/}}
{{- define "niralos-5gcore.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "niralos-5gcore.fullname" -}}
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
Common labels
*/}}
{{- define "niralos-5gcore.labels" -}}
app.kubernetes.io/name: {{ include "niralos-5gcore.name" . }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Legacy helper for backward compatibility
*/}}
{{- define "niralos.name" -}}niralos{{- end -}}

{{/*
Resolve service_id for a given NF.
Usage: {{ include "niralos.serviceId" (dict "root" $ "nf" "amf") }}
*/}}
{{- define "niralos.serviceId" -}}
{{- $root := .root -}}
{{- $nf := .nf -}}
{{- $val := "" -}}
{{- if and $root.Values.coreNetwork $root.Values.coreNetwork.service_ids (hasKey $root.Values.coreNetwork.service_ids $nf) -}}
  {{- $val = index $root.Values.coreNetwork.service_ids $nf -}}
{{- else if and $root.Values.coreNetwork $root.Values.coreNetwork.serviceIds (hasKey $root.Values.coreNetwork.serviceIds $nf) -}}
  {{- $val = index $root.Values.coreNetwork.serviceIds $nf -}}
{{- else if and $root.Values.coreNetwork (hasKey $root.Values.coreNetwork "service_id") -}}
  {{- $raw := toString $root.Values.coreNetwork.service_id -}}
  {{- if contains (printf ".%s." $nf) $raw -}}
    {{- $val = $raw -}}
  {{- else -}}
    {{- $val = printf "niralos.%s.%s" $nf $raw -}}
  {{- end -}}
{{- else if and $root.Values.coreNetwork (hasKey $root.Values.coreNetwork "serviceId") -}}
  {{- $raw := toString $root.Values.coreNetwork.serviceId -}}
  {{- if contains (printf ".%s." $nf) $raw -}}
    {{- $val = $raw -}}
  {{- else -}}
    {{- $val = printf "niralos.%s.%s" $nf $raw -}}
  {{- end -}}
{{- else if and $root.Values.coreEnv (hasKey $root.Values.coreEnv "SERVICE_ID") -}}
  {{- $raw := toString $root.Values.coreEnv.SERVICE_ID -}}
  {{- $val = printf "niralos.%s.%s" $nf $raw -}}
{{- else -}}
  {{- $val = printf "niralos.%s.001" $nf -}}
{{- end -}}
{{- $val -}}
{{- end -}}

{{/*
Resolve imsVoPS for AMF nf_support.
Usage: {{ include "niralos.imsVoPS" . }}
*/}}
{{- define "niralos.imsVoPS" -}}
{{- $imsvops := 1 -}}
{{- if and .Values.coreNetwork (hasKey .Values.coreNetwork "imsvops") -}}
  {{- $imsvops = .Values.coreNetwork.imsvops -}}
{{- else if and .Values.coreNetwork (hasKey .Values.coreNetwork "imsVoPS") -}}
  {{- $imsvops = .Values.coreNetwork.imsVoPS -}}
{{- else if and .Values.coreNetwork .Values.coreNetwork.amf (hasKey .Values.coreNetwork.amf "imsvops") -}}
  {{- $imsvops = .Values.coreNetwork.amf.imsvops -}}
{{- else if and .Values.coreNetwork .Values.coreNetwork.amf (hasKey .Values.coreNetwork.amf "imsVoPS") -}}
  {{- $imsvops = .Values.coreNetwork.amf.imsVoPS -}}
{{- end -}}
{{- $imsvops -}}
{{- end -}}
