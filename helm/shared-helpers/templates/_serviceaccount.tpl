{{/*
  Shared ServiceAccount Template

  Usage:
    {{ include "shared.serviceAccount" (dict
      "name" (include "template.serviceAccountName" .)
      "Values" .Values
      "Labels" (include "template.labels" . | fromYaml)
    ) }}
*/}}

{{- define "shared.serviceAccount" -}}

{{- $sa := .Values.serviceAccount | default dict }}

{{- $create := $sa.create | default false }}
{{- if $create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .name }}
  labels:
    {{- toYaml .Labels | nindent 4 }}
  {{- with $sa.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ $sa.automount | default true }}
{{- end }}

{{- end }}
