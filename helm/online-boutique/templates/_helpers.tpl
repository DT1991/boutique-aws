{{/*
==============================================================================
Online Boutique Helm Chart — Template Helpers
==============================================================================
*/}}

{{/*
Chart name
*/}}
{{- define "online-boutique.name" -}}
{{- .Chart.Name }}
{{- end }}

{{/*
Full release name, truncated at 63 chars
*/}}
{{- define "online-boutique.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources
*/}}
{{- define "online-boutique.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
environment: {{ .Values.global.environment }}
{{- end }}

{{/*
Selector labels for a given service
Usage: include "online-boutique.selectorLabels" (dict "name" "frontend")
*/}}
{{- define "online-boutique.selectorLabels" -}}
app: {{ .name }}
app.kubernetes.io/name: {{ .name }}
{{- end }}

{{/*
Image reference for a service
Usage: include "online-boutique.image" (dict "svc" .Values.services.frontend "global" .Values.global)
*/}}
{{- define "online-boutique.image" -}}
{{- printf "%s/%s:%s" .global.registry .svc.image .global.tag }}
{{- end }}

{{/*
Standard pod security context
*/}}
{{- define "online-boutique.podSecurityContext" -}}
{{- toYaml .Values.global.podSecurityContext }}
{{- end }}

{{/*
Standard container security context
*/}}
{{- define "online-boutique.containerSecurityContext" -}}
{{- toYaml .Values.global.containerSecurityContext }}
{{- end }}

{{/*
Topology spread constraints (zone spreading)
Usage: include "online-boutique.topologySpread" (dict "name" "frontend" "global" .Values.global)
*/}}
{{- define "online-boutique.topologySpread" -}}
{{- if .global.topologySpreadEnabled }}
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: {{ .name }}
{{- end }}
{{- end }}

{{/*
gRPC liveness probe (default)
*/}}
{{- define "online-boutique.grpcLivenessProbe" -}}
livenessProbe:
  grpc:
    port: {{ .port }}
  initialDelaySeconds: 15
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
{{- end }}

{{/*
gRPC readiness probe (default)
*/}}
{{- define "online-boutique.grpcReadinessProbe" -}}
readinessProbe:
  grpc:
    port: {{ .port }}
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
{{- end }}
