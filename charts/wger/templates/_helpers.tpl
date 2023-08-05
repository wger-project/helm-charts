{{/* wger container definition used for wger-app and celery containers */}}
{{- define "wger.container" }}
image: "{{ .Values.app.global.image.registry }}/{{ .Values.app.global.image.repository }}:{{ .Values.app.global.image.tag | default .Chart.AppVersion }}"
imagePullPolicy: {{ .Values.app.global.image.PullPolicy }}
env:
  # django db
  - name: DJANGO_DB_ENGINE
    value: "django.db.backends.postgresql"
  - name: DJANGO_DB_USER
    value: {{ .Values.postgres.settings.superuser | quote }}
  - name: DJANGO_DB_PASSWORD
    value: {{ .Values.postgres.settings.superuserPassword | quote }}
  - name: DJANGO_DB_DATABASE
    value: {{ .Values.postgres.userDatabase.name | quote }}
  - name: DJANGO_DB_HOST
    value: "{{ .Release.Name }}-postgres"
  - name: DJANGO_DB_PORT
    value: {{ .Values.postgres.service.port | quote }}
  # django cache
  - name: DJANGO_CACHE_BACKEND
    value: "django_redis.cache.RedisCache"
  - name: DJANGO_CACHE_LOCATION
    value: "redis://{{ .Release.Name }}-redis:{{ .Values.redis.service.serverPort }}/1"
  - name: DJANGO_CACHE_CLIENT_CLASS
    value: "django_redis.client.DefaultClient"
  - name: DJANGO_CACHE_TIMEOUT
    value: {{ .Values.app.django.secret.name | default "1296000" | quote }}
  # django email
  - name: EMAIL_BACKEND
    value: "django.core.mail.backends.console.EmailBackend"
  # django general
  {{- if .Values.app.nginx.enabled }}
  - name: DJANGO_DEBUG
    value: "False"
  {{- else }}
  - name: DJANGO_DEBUG
    value: "True"
  {{- end }}
  - name: DJANGO_MEDIA_ROOT
    value: "/home/wger/media"
  - name: SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: {{ .Values.app.django.secret.name | default "django" | quote }}
        key: "secret-key"
  {{- if .Values.ingress.enabled }}
  - name: SITE_URL
    value: {{ .Values.ingress.url | quote }}
  {{- end }}
  # axes
  {{- if .Values.app.axes.enabled }}
  - name: AXES_ENABLED
    value: "True"
  {{- else }}
  - name: AXES_ENABLED
    value: "False"
  {{- end }}
  - name: AXES_FAILURE_LIMIT
    value: {{ .Values.app.axes.failureLimit | default "10" | quote }}
  - name: AXES_COOLOFF_TIME
    value: {{ .Values.app.axes.cooloffTime | default "30" | quote }}
  - name: AXES_HANDLER
    value: "axes.handlers.cache.AxesCacheHandler"
  # jwt auth
  - name: SIGNING_KEY
    valueFrom:
      secretKeyRef:
        name: {{ .Values.app.jwt.secret.name | default "jwt" | quote }}
        key: "signing-key"
  - name: ACCESS_TOKEN_LIFETIME
    value: {{ .Values.app.jwt.accessTokenLifetime | default "10" | quote }}
  - name: REFRESH_TOKEN_LIFETIME
    value: {{ .Values.app.jwt.refreshTokenLifetime | default "24" | quote }}
  # others
  {{- if .Values.app.nginx.enabled }}
  - name: WGER_USE_GUNICORN
    value: "True"
  {{- end }}
  - name: EXERCISE_CACHE_TTL
    value: "18000"
  # Exercise synchronization
  # can be done manually / on startup / with celery as timebased job
  {{- if .Values.app.celery.enabled }}
  - name: SYNC_EXERCISES_ON_STARTUP
    value: "False"
  - name: DOWNLOAD_EXERCISE_IMAGES_ON_STARTUP
    value: "False"
  - name: USE_CELERY
    value: "True"
  - name: SYNC_EXERCISES_CELERY
    value: {{ .Values.app.celery.syncExercises | default "True" | quote }}
  - name: SYNC_EXERCISE_IMAGES_CELERY
    value: {{ .Values.app.celery.syncImages | default "True" | quote }}
  - name: SYNC_EXERCISE_VIDEOS_CELERY
    value: {{ .Values.app.celery.syncVideos | default "True" | quote }}
  - name: DOWNLOAD_INGREDIENTS_FROM
    value: {{ .Values.app.celery.ingredientsFrom | default "WGER" | quote }}
  - name: CELERY_BROKER
    value: "redis://{{ .Release.Name }}-redis:{{ .Values.redis.service.serverPort }}/2"
  - name: CELERY_BACKEND
    value: "redis://{{ .Release.Name }}-redis:{{ .Values.redis.service.serverPort }}/2"
  {{- if .Values.app.celery.flower.enabled }}
  - name: CELERY_FLOWER_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ .Values.app.celery.flower.secret.name | default "flower" | quote }}
        key: "password"
  {{- end }}
  {{- end }}
  # Add env from values.yaml (can override above)
{{- with .Values.app.environment }}
  {{- range  . }}
  - name: {{ .name | quote }}
    value: {{ .value | quote }}
  {{- end }}
{{- end }}
{{- end }}
