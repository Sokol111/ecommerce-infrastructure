{{/*
  shared.notes - template for NOTES.txt
  
  Usage:
    {{ include "shared.notes" (dict
        "Values" .Values
        "Release" .Release
        "Chart" .Chart
        "fullname" (include "template.fullname" .)
        "appName" (include "template.name" .)
    ) }}
*/}}

{{- define "shared.notes" -}}

{{- $svc := .Values.service | default dict }}
{{- $svcType := $svc.type | default "ClusterIP" }}
{{- $svcPort := $svc.port | default 80 }}
{{- $ingress := .Values.ingress | default dict }}

1. Get the application URL by running these commands:

{{- if $ingress.enabled }}
  {{- range $host := $ingress.hosts }}
    {{- range $path := $host.paths }}
http{{ if $ingress.tls }}s{{ end }}://{{ $host.host }}{{ $path.path }}
    {{- end }}
  {{- end }}

{{- else if contains "NodePort" $svcType }}
  export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ .fullname }})
  export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT

{{- else if contains "LoadBalancer" $svcType }}
  NOTE: It may take a few minutes for the LoadBalancer IP to be available.
        You can watch its status by running 'kubectl get --namespace {{ .Release.Namespace }} svc -w {{ .fullname }}'
  export SERVICE_IP=$(kubectl get svc --namespace {{ .Release.Namespace }} {{ .fullname }} --template "{{"{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}"}}")
  echo http://$SERVICE_IP:{{ $svcPort }}

{{- else if contains "ClusterIP" $svcType }}
  export POD_NAME=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "app.kubernetes.io/name={{ .appName }},app.kubernetes.io/instance={{ .Release.Name }}" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace {{ .Release.Namespace }} $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace {{ .Release.Namespace }} port-forward $POD_NAME 8080:$CONTAINER_PORT
{{- end }}

{{- end }}
