{{- define "shared-gateway.hostname" -}}
{{- $root := .root -}}
{{- $key := .key -}}
{{- $value := .value | default "" -}}
{{- if $value -}}
{{- $value -}}
{{- else -}}
{{- $global := $root.Values.global | default dict -}}
{{- printf "%s.%s" $key (default "opsbox.org" $global.domain) -}}
{{- end -}}
{{- end -}}
