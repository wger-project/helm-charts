{{/*
 wger default environment definition
 used for wger-app and celery containers
*/}}
{{- define "wger.env.default" }}
environment:
  # general
  - name: TZ
    value: {{ .Values.app.timezone | default "UTC" | quote }}
  - name: TIME_ZONE
    value: {{ .Values.app.timezone | default "UTC" | quote }}
  # email settings
  {{- if .Values.app.mail.enabled }}
  - name: ENABLE_EMAIL
    value: "True"
  - name: EMAIL_HOST
    value: {{ .Values.app.mail.server | quote }}
  - name: EMAIL_PORT
    value: {{ .Values.app.mail.port | default "587" | quote }}
  - name: EMAIL_HOST_USER
    value: {{ .Values.app.mail.user | quote }}
  - name: FROM_EMAIL
    value: {{ .Values.app.mail.from_email | quote }}
    {{- if .Values.app.mail.django_admins }}
  - name: DJANGO_ADMINS
    value: {{ .Values.app.mail.django_admins | quote }}
    {{- end }}
  {{- else }}
  - name: ENABLE_EMAIL
    value: "False"
  {{- end }}
  # django db
  - name: DJANGO_PERFORM_MIGRATIONS
    value: "True"
  - name: DJANGO_DB_ENGINE
    value: {{ .Values.app.django.existingDatabase.engine | default "django.db.backends.postgresql" | quote }}
  - name: DJANGO_DB_HOST
    value: {{ .Values.app.django.existingDatabase.host | default (print .Release.Name "-postgres") | quote }}
  - name: DJANGO_DB_PORT
    value: {{ .Values.app.django.existingDatabase.port | default .Values.postgres.service.port | int | quote }}
  # cache
  - name: DJANGO_CACHE_BACKEND
    value: "django_redis.cache.RedisCache"
  - name: DJANGO_CACHE_LOCATION
    value: "redis://{{ .Release.Name }}-redis:{{ int .Values.redis.service.serverPort }}/1"
  - name: DJANGO_CACHE_CLIENT_CLASS
    value: "django_redis.client.DefaultClient"
  - name: DJANGO_CACHE_TIMEOUT
    value: {{ int .Values.app.django.cache.timeout | default "1296000" | quote }}
  - name: EXERCISE_CACHE_TTL
    value: "18000"
  # django general
  {{- if .Values.ingress.enabled }}
  - name: SITE_URL
    {{- if .Values.ingress.tls }}
    value: "https://{{ .Values.ingress.url }}"
    {{- else }}
    value: "http://{{ .Values.ingress.url }}"
    {{- end }}
  - name: CSRF_TRUSTED_ORIGINS
    value: "http://{{ .Values.ingress.url }},https://{{ .Values.ingress.url }},http://127.0.0.1,https://127.0.0.1,http://localhost,https://localhost"
  {{- else }}
  - name: CSRF_TRUSTED_ORIGINS
    value: "http://127.0.0.1,https://127.0.0.1,http://localhost,https://localhost"
  {{- end }}
  - name: DJANGO_DEBUG
    {{- if .Values.app.nginx.enabled }}
    value: "False"
    {{- else }}
    value: "True"
    {{- end }}
  - name: DJANGO_MEDIA_ROOT
    value: "/home/wger/media"
  # axes
  - name: AXES_ENABLED
  {{- if .Values.app.axes.enabled }}
    value: "True"
  {{- else }}
    value: "False"
  {{- end }}
  - name: AXES_LOCKOUT_PARAMETERS
    value: {{ .Values.app.axes.lockoutParameters | default "ip_address" | quote }}
  - name: AXES_FAILURE_LIMIT
    value: {{ int .Values.app.axes.failureLimit | default "10" | quote }}
  - name: AXES_COOLOFF_TIME
    value: {{ int .Values.app.axes.cooloffTime | default "30" | quote }}
  - name: AXES_IPWARE_PROXY_COUNT
    value: {{ int .Values.app.axes.ipwareProxyCount | default "0" | quote }}
    # @todo bad default, use the default from axes REMOTE_ADDR only
  - name: AXES_IPWARE_META_PRECEDENCE_ORDER
    value: {{ .Values.app.axes.ipwareMetaPrecedenceOrder | default "HTTP_X_FORWARDED_FOR,REMOTE_ADDR" | quote }}
  - name: AXES_HANDLER
    value: "axes.handlers.cache.AxesCacheHandler"
  # jwt auth
  - name: ACCESS_TOKEN_LIFETIME
    value: {{ int .Values.app.jwt.accessTokenLifetime | default "10" | quote }}
  - name: REFRESH_TOKEN_LIFETIME
    value: {{ int .Values.app.jwt.refreshTokenLifetime | default "24" | quote }}
  # others
  {{- if .Values.app.nginx.enabled }}
  - name: WGER_USE_GUNICORN
    value: "True"
    # workers (2x CPU Cores +1), rpi4 works well with 2 worker / 2 threads / 1 pod
    # forward-allow-ips="*" for image serving https url
    # accesslog: remote ip - client ip - x-real-ip - x-forward-for -
  - name: GUNICORN_CMD_ARGS
    value: "--timeout 240 --workers 4 --worker-class gthread --threads 3 --forwarded-allow-ips * --proxy-protocol True --access-logformat='%(h)s %(l)s %({client-ip}i)s %(l)s %({x-real-ip}i)s %(l)s %({x-forwarded-for}i)s %(l)s %(t)s \"%(r)s\" %(s)s %(b)s \"%(f)s\" \"%(a)s\"' --access-logfile - --error-logfile -"
  {{- end }}
  # Users won't be able to contribute to exercises if their account age is
  # lower than this amount in days.
  - name: MIN_ACCOUNT_AGE_TO_TRUST
    value: "21"
  - name: ALLOW_REGISTRATION
    value: "False"
  - name: ALLOW_GUEST_USERS
    value: "False"
  # Exercise synchronization
  # can be done manually / on startup / with celery as timebased job
  # Wger instance from which to sync exercises, images, etc.
  - name: WGER_INSTANCE
    value: "https://wger.de"
  - name: ALLOW_UPLOAD_VIDEOS
    value: "True"
  {{- if .Values.celery.enabled }}
  - name: SYNC_EXERCISES_ON_STARTUP
    value: "False"
  - name: DOWNLOAD_EXERCISE_IMAGES_ON_STARTUP
    value: "False"
  - name: USE_CELERY
    value: "True"
  - name: SYNC_EXERCISES_CELERY
    value: {{ .Values.celery.syncExercises | default "True" | quote }}
  - name: SYNC_EXERCISE_IMAGES_CELERY
    value: {{ .Values.celery.syncImages | default "True" | quote }}
  - name: SYNC_EXERCISE_VIDEOS_CELERY
    value: {{ .Values.celery.syncVideos | default "True" | quote }}
  - name: DOWNLOAD_INGREDIENTS_FROM
    value: {{ .Values.celery.ingredientsFrom | default "WGER" | quote }}
  {{- end }}
{{- end }}

{{/*
 merged custom environment definition with default
 used for wger-app and celery containers
*/}}
{{- define "wger.env" }}
# get default env
{{- $envDefault := (include "wger.env.default" .) | fromYaml }}
# get list of custom defined env
{{- $customnames := list }}
{{- range $custom := .Values.app.environment }}
  {{- $customnames = append $customnames $custom.name }}
{{- end }}
# get default env list without custom ones (override)
{{- $defaultlist := list }}
{{- range $default := $envDefault.environment }}
  {{- if has $default.name $customnames }}
  {{- else }}
    {{- $defaultlist = append $defaultlist $default }}
  {{- end }}
{{- end }}
# merge default env with values env
{{- range $custom := .Values.app.environment }}
  {{- $defaultlist = append $defaultlist $custom }}
{{- end }}
# ouput list of dict
{{- range $defaultlist }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
{{- end }}
{{/*
 database settings
 used for wger-app and celery containers
*/}}
{{- define "database.settings" }}
  {{- if .Values.app.django.existingDatabase.enabled }}
    - name: DJANGO_DB_USER
      valueFrom:
        secretKeyRef:
          name: {{ .Values.app.django.existingDatabase.existingSecret.name | default (print .Release.Name "-existing-database") | quote }}
          key: {{ .Values.app.django.existingDatabase.existingSecret.dbuserKey | default "USERDB_USER" | quote }}
    - name: DJANGO_DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ .Values.app.django.existingDatabase.existingSecret.name | default (print .Release.Name "-existing-database") | quote }}
          key: {{ .Values.app.django.existingDatabase.existingSecret.dbpwKey | default "USERDB_PASSWORD" | quote }}
    - name: DJANGO_DB_DATABASE
      valueFrom:
        secretKeyRef:
          name: {{ .Values.app.django.existingDatabase.existingSecret.name | default (print .Release.Name "-existing-database") | quote }}
          key: {{ .Values.app.django.existingDatabase.existingSecret.dbnameKey | default "USERDB_NAME" | quote }}
  {{- else }}
    - name: DJANGO_DB_USER
      valueFrom:
        secretKeyRef:
          name:  {{.Release.Name}}-postgres
          key: "USERDB_USER"
    - name: DJANGO_DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{.Release.Name}}-postgres
          key: "USERDB_PASSWORD"
    - name: DJANGO_DB_DATABASE
      valueFrom:
        secretKeyRef:
          name: {{.Release.Name}}-postgres
          key: "POSTGRES_DB"
  {{- end }}
{{- end }}
{{/*
 initContainer postgres command
 used for wger-app and celery containers
*/}}
{{- define "initContainer.pgonly.command" }}
{{- $dbhost := .Values.app.django.existingDatabase.host | default (print .Release.Name "-postgres") | quote }}
{{- $dbport := .Values.app.django.existingDatabase.port | default .Values.postgres.service.port | int | quote }}
- /bin/sh
- -c
- until nc -zvw10 {{ $dbhost }} {{ $dbport }}; do echo "Waiting for postgres service ({{ $dbhost }}:{{ $dbport }}) "; sleep 2; done &&
  until nc -zvw10 {{.Release.Name}}-redis {{ .Values.redis.service.serverPort }}; do echo "Waiting for redis service ({{.Release.Name}}-redis:{{ .Values.redis.service.serverPort }})"; sleep 2; done
{{- end }}
{{/*
 initContainer web command
 used for celery containers
*/}}
{{- define "initContainer.web.command" }}
{{- $dbhost := .Values.app.django.existingDatabase.host | default (print .Release.Name "-postgres") | quote }}
{{- $dbport := .Values.app.django.existingDatabase.port | default .Values.postgres.service.port | int | quote }}
- /bin/sh
- -c
- until nc -zvw10 {{ $dbhost }} {{ $dbport }}; do echo "Waiting for postgres service ({{ $dbhost }}:{{ $dbport }}) "; sleep 2; done &&
  until nc -zvw10 {{ .Release.Name }}-redis {{ .Values.redis.service.serverPort }}; do echo "Waiting for redis service ({{ .Release.Name }}-redis:{{ .Values.redis.service.serverPort }})"; sleep 2; done &&
  until wget --spider http://{{ .Release.Name }}-http:8000; do echo "Waiting for wger app service ({{ .Release.Name }}-http:8000)"; sleep 2; done
{{- end }}
