{{/*
  shared.configmap — template for ConfigMap with application config

  Creates a ConfigMap named "<name>-config" containing config.yaml
  when .Values.config is set. Used together with the auto-mount
  logic in shared.deployment to inject configuration into pods.

  Usage:
    {{ include "shared.configmap" (dict
      "name" (include "template.fullname" .)
      "Labels" (include "template.labels" . | fromYaml)
      "Values" .Values
    ) }}
*/}}

{{- define "shared.configmap" -}}
{{- if .Values.config }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .name }}-config
  labels:
    {{- toYaml .Labels | nindent 4 }}
data:
  config.yaml: |
{{ .Values.config | indent 4 }}
{{- end }}
{{- end }}
