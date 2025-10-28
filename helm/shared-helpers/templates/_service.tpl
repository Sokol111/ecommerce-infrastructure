{{/*
  Shared Service Template

  Usage:
    {{ include "shared.service" (dict
      "name" (include "template.fullname" .)
      "Values" .Values
      "Labels" (include "template.labels" . | fromYaml)
      "SelectorLabels" (include "template.selectorLabels" . | fromYaml)
    ) }}
*/}}

{{- define "shared.service" -}}

{{- $values := .Values }}
{{- $global := dict }}
{{- if .Values.global }}
  {{- $global = .Values.global }}
{{- end }}
{{- $service := or $values.service $global.service }}

{{- $type := "ClusterIP" }}
{{- if and $service $service.type }}
  {{- $type = $service.type }}
{{- end }}

{{- $port := 80 }}
{{- if and $service $service.port }}
  {{- $port = $service.port }}
{{- end }}

apiVersion: v1
kind: Service
metadata:
  name: {{ .name }}
  labels:
    {{- toYaml .Labels | nindent 4 }}
spec:
  type: {{ $type }}
  ports:
    - port: {{ $port }}
      targetPort: http
      protocol: TCP
      name: http
    {{- if $values.debugPort }}
    - port: {{ $values.debugPort }}
      targetPort: debug
      protocol: TCP
      name: debug
    {{- end }}
  selector:
    {{- toYaml .SelectorLabels | nindent 4 }}
{{- end }}
