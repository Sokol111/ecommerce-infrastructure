{{/*
  shared.deployment — template for Deployment

  Usage:
    {{ include "shared.deployment" (dict
      "name" (include "template.fullname" .)
      "Labels" (include "template.labels" . | fromYaml)
      "SelectorLabels" (include "template.selectorLabels" . | fromYaml)
      "Values" .Values
      "ServiceAccountName" (include "template.serviceAccountName" .)
      "Chart" .Chart
    ) }}


*/}}

{{- define "shared.deployment" -}}

{{- $autoscalingEnabled := false }}
{{- if and .Values.autoscaling .Values.autoscaling.enabled }}
  {{- $autoscalingEnabled = .Values.autoscaling.enabled }}
{{- end }}

{{- $replicaCount := 1 }}
{{- if .Values.replicaCount }}
  {{- $replicaCount = .Values.replicaCount }}
{{- end }}

{{- $imagePullPolicy := "IfNotPresent" }}
{{- if and .Values.image .Values.image.pullPolicy }}
  {{- $imagePullPolicy = .Values.image.pullPolicy }}
{{- else if and .Values.global (and .Values.global.image .Values.global.image.pullPolicy) }}
  {{- $imagePullPolicy = .Values.global.image.pullPolicy }}
{{- end }}

{{- $containerPort := 80 }}
{{- if and .Values.service .Values.service.port }}
  {{- $containerPort = .Values.service.port }}
{{- end }}

apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .name }}
  labels:
    {{- toYaml .Labels | nindent 4 }}
spec:
  {{- if not $autoscalingEnabled }}
  replicas: {{ $replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- toYaml .SelectorLabels | nindent 6 }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- toYaml .Labels | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        # app.kubernetes.io/version: {{ .Values.image.tag | quote }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ .ServiceAccountName | quote }}
      {{- with .Values.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.initContainers }}
      initContainers:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ or .Values.nameOverride .Values.chartName "app" }}
          {{- with .Values.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          
          {{- with .Values.securityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if .Values.image.digest }}
          image: "{{ .Values.image.repository }}@{{ .Values.image.digest }}"
          {{- else }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          {{- end }}
          imagePullPolicy: {{ $imagePullPolicy }}
          {{- with .Values.command }}
          command:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          ports:
            - name: http
              containerPort: {{ $containerPort }}
              protocol: TCP
            {{- if .Values.debugPort }}
            - name: debug
              containerPort: {{ .Values.debugPort }}
              protocol: TCP
            {{- end }}
          {{- with .Values.startupProbe }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
