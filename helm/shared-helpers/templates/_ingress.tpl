{{/*
  shared.ingress — template for Ingress

  Usage:
    {{ include "shared.ingress" (dict
      "name" (include "template.fullname" .)
      "Labels" (include "template.labels" . | fromYaml)
      "Values" .Values
    ) }}
*/}}

{{- define "shared.ingress" -}}
{{- $values := .Values }}
{{- $global := dict }}
{{- if .Values.global }}
  {{- $global = .Values.global }}
{{- end }}
{{- $ingress := or $values.ingress $global.ingress }}
{{- $service := or $values.service $global.service }}

{{- $enabled := false }}
{{- if $ingress }}
  {{- if $ingress.enabled }}
    {{- $enabled = $ingress.enabled }}
  {{- else }}
    {{- $enabled = false }}
  {{- end }}
{{- end }}

{{- $host := "example.com" }}
{{- if and $ingress $ingress.host }}
  {{- $host = $ingress.host }}
{{- end }}

{{- $path := "/" }}
{{- if and $ingress $ingress.path }}
  {{- $path = $ingress.path }}
{{- end }}

{{- $annotations := dict }}
{{- if and $ingress $ingress.annotations }}
  {{- $annotations = $ingress.annotations }}
{{- end }}

{{- $port := 80 }}
{{- if and $service $service.port }}
  {{- $port = $service.port }}
{{- end }}

{{- if $enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .name }}
  labels:
    {{- toYaml .Labels | nindent 4 }}
  annotations:
    {{- if $annotations }}
    {{- toYaml $annotations | nindent 4 }}
    {{- else }}
    traefik.ingress.kubernetes.io/router.entrypoints: web
    {{- end }}
spec:
  rules:
    - host: {{ $host }}
      http:
        paths:
          - path: {{ $path }}
            pathType: Prefix
            backend:
              service:
                name: {{ .name }}
                port:
                  number: {{ $port }}
{{- end }}
{{- end }}
