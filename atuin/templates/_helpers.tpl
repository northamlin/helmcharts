{{/* Every object is <name>-<uuid>[-suffix]: one owner namespace holds many releases. */}}
{{- define "robots.fullname" -}}
{{- printf "%s-%s" .Values.name .Values.uuid | trunc 50 | trimSuffix "-" -}}
{{- end -}}

{{- define "robots.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ include "robots.fullname" . }}
{{- end -}}

{{- define "robots.labels" -}}
{{ include "robots.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.app.tag | quote }}
app.kubernetes.io/managed-by: robots-service
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{/* hosting.tags (norh/id, norh/owner, ...) as annotations. */}}
{{- define "robots.annotations" -}}
{{- range $k, $v := (default dict (default dict .Values.hosting).tags) }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end -}}

{{/* App container resources from the size tier. */}}
{{- define "robots.tierResources" -}}
{{- $t := default "low" .Values.resource -}}
{{- /* A chart that can't run below a tier sets minResource; the larger of the two wins. */ -}}
{{- $rank := dict "low" 0 "medium" 1 "high" 2 -}}
{{- with .Values.minResource }}
{{- if and (hasKey $rank $t) (gt (int (get $rank .)) (int (get $rank $t))) }}{{ $t = . }}{{ end }}
{{- end -}}
{{- if eq $t "custom" }}
requests: {cpu: {{ .Values.cpu | quote }}, memory: {{ .Values.memory | quote }}}
limits: {cpu: {{ .Values.cpu | quote }}, memory: {{ .Values.memory | quote }}}
{{- else if eq $t "high" }}
requests: {cpu: 250m, memory: 512Mi}
limits: {cpu: 2000m, memory: 4Gi}
{{- else if eq $t "medium" }}
requests: {cpu: 100m, memory: 256Mi}
limits: {cpu: 1000m, memory: 1Gi}
{{- else }}
requests: {cpu: 50m, memory: 128Mi}
limits: {cpu: 500m, memory: 512Mi}
{{- end }}
{{- end -}}

{{- define "robots.sidecarResources" -}}
requests: {cpu: {{ .Values.sidecarCpu | quote }}, memory: {{ .Values.sidecarMemory | quote }}}
limits: {cpu: {{ .Values.sidecarCpuLimit | quote }}, memory: {{ .Values.sidecarMemoryLimit | quote }}}
{{- end -}}

{{- define "robots.dbResources" -}}
requests: {cpu: {{ .Values.dbCpu | quote }}, memory: {{ .Values.dbMemory | quote }}}
limits: {cpu: {{ .Values.dbCpuLimit | quote }}, memory: {{ .Values.dbMemoryLimit | quote }}}
{{- end -}}

{{/* Database endpoint, derived — never taken from .Values.dbhost. */}}
{{- define "robots.dbHost" -}}
{{- if eq .Values.database.type "mysql" -}}
{{ include "robots.fullname" . }}-mysql-master
{{- else if eq .Values.database.type "postgres" -}}
{{ include "robots.fullname" . }}-pg-rw
{{- end -}}
{{- end -}}

{{- define "robots.dbPort" -}}
{{- if eq .Values.database.type "mysql" -}}3306{{- else -}}5432{{- end -}}
{{- end -}}

{{/* Secret + keys holding the DB user/password for the app. */}}
{{- define "robots.dbSecret" -}}
{{- if eq .Values.database.type "postgres" -}}
{{ include "robots.fullname" . }}-pg-app
{{- else -}}
{{ include "robots.fullname" . }}
{{- end -}}
{{- end -}}
{{- define "robots.dbUserKey" -}}{{ if eq .Values.database.type "postgres" }}username{{ else }}USER{{ end }}{{- end -}}
{{- define "robots.dbPassKey" -}}{{ if eq .Values.database.type "postgres" }}password{{ else }}PASSWORD{{ end }}{{- end -}}
