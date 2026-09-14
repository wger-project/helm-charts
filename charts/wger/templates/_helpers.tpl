{{/*
 wger app image reference
 used for the wger-app, celery containers and the powersync-storage hook
 (also guards against the pre-rename PullPolicy key, since this helper is
 rendered on every install)
*/}}
{{- define "wger.image" -}}
{{- if or .Values.app.global.image.PullPolicy .Values.powersync.image.PullPolicy -}}
{{- fail "image.PullPolicy has been renamed to image.pullPolicy - please update your values (app.global.image.pullPolicy / powersync.image.pullPolicy)" -}}
{{- end -}}
{{ .Values.app.global.image.registry }}/{{ .Values.app.global.image.repository }}:{{ .Values.app.global.image.tag | default .Chart.AppVersion }}
{{- end -}}

{{/*
 common resource labels, appended to the per-resource app.kubernetes.io/name.
 Not used in pod template / selector labels: selectors are immutable.
*/}}
{{- define "wger.labels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.app.global.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/*
 wger default environment definition
 used for wger-app and celery containers
*/}}
{{- define "wger.env.default" }}
environment:
  # general
  - name: TZ
    value: {{ .Values.app.timezone | quote }}
  - name: TIME_ZONE
    value: {{ .Values.app.timezone | quote }}
  - name: WGER_MAX_SESSION_LENGTH_HOURS
    value: {{ int .Values.app.maxSessionLengthHours | quote }}
  - name: WGER_SHOW_APP_STORE_LINKS
    value: {{ .Values.app.showAppStoreLinks | quote }}
  # email settings
  {{- if .Values.app.mail.enabled }}
  - name: ENABLE_EMAIL
    value: "True"
  - name: EMAIL_HOST
    value: {{ .Values.app.mail.server | quote }}
  - name: EMAIL_PORT
    value: {{ .Values.app.mail.port | quote }}
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
    value: {{ .Values.app.django.existingDatabase.engine | quote }}
  # cache
  - name: DJANGO_CACHE_BACKEND
    value: "django_redis.cache.RedisCache"
  - name: DJANGO_CACHE_LOCATION
    value: "redis://{{ .Release.Name }}-redis:{{ int .Values.redis.service.serverPort }}/1"
  - name: DJANGO_CACHE_CLIENT_CLASS
    value: "django_redis.client.DefaultClient"
  - name: DJANGO_CACHE_TIMEOUT
    value: {{ int .Values.app.django.cache.timeout | quote }}
  - name: EXERCISE_CACHE_TTL
    value: "2419200"
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
    value: "False"
  - name: DJANGO_MEDIA_ROOT
    value: "/home/wger/media"
  # Django Rest Framework
  # The number of proxies in front of the application. In the default configuration
  # only nginx is. Change as approtriate if your setup differs. Also note that this
  # is only used when throttling API requests.
  - name: NUMBER_OF_PROXIES
    value: {{ int .Values.app.global.proxyCount | quote }}
  - name: USE_X_FORWARDED_HOST
    value: {{ .Values.app.global.useXForwardedHost | quote }}
  # axes
  - name: AXES_ENABLED
  {{- if .Values.app.axes.enabled }}
    value: "True"
  {{- else }}
    value: "False"
  {{- end }}
  - name: AXES_LOCKOUT_PARAMETERS
    value: {{ .Values.app.axes.lockoutParameters | quote }}
  - name: AXES_FAILURE_LIMIT
    value: {{ int .Values.app.axes.failureLimit | quote }}
  - name: AXES_COOLOFF_TIME
    value: {{ int .Values.app.axes.cooloffTime | quote }}
  - name: AXES_IPWARE_PROXY_COUNT
    value: {{ int .Values.app.global.proxyCount | quote }}
    # @todo bad default, use the default from axes REMOTE_ADDR only
  - name: AXES_IPWARE_META_PRECEDENCE_ORDER
    value: {{ .Values.app.axes.ipwareMetaPrecedenceOrder | quote }}
  - name: AXES_HANDLER
    value: "axes.handlers.cache.AxesCacheHandler"
  # jwt auth
  - name: ACCESS_TOKEN_LIFETIME
    value: {{ int .Values.app.jwt.accessTokenLifetime | quote }}
  - name: REFRESH_TOKEN_LIFETIME
    value: {{ int .Values.app.jwt.refreshTokenLifetime | quote }}
  # gunicorn settings
  - name: WGER_USE_GUNICORN
    value: "True"
    # workers (2x CPU Cores +1), rpi4 works well with 2 worker / 2 threads / 1 pod
    # forward-allow-ips="*" for image serving https url
    # accesslog: remote ip - client ip - x-real-ip - x-forward-for -
  - name: GUNICORN_CMD_ARGS
    value: "--timeout 240 --workers 4 --worker-class gthread --threads 3 --forwarded-allow-ips * --proxy-protocol True --access-logformat='%(h)s %(l)s %({client-ip}i)s %(l)s %({x-real-ip}i)s %(l)s %({x-forwarded-for}i)s %(l)s %(t)s \"%(r)s\" %(s)s %(b)s \"%(f)s\" \"%(a)s\"' --access-logfile - --error-logfile -"
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
    value: {{ .Values.celery.syncExercises | quote }}
  - name: SYNC_EXERCISE_IMAGES_CELERY
    value: {{ .Values.celery.syncImages | quote }}
  - name: SYNC_EXERCISE_VIDEOS_CELERY
    value: {{ .Values.celery.syncVideos | quote }}
  - name: DOWNLOAD_INGREDIENTS_FROM
    value: {{ .Values.celery.ingredientsFrom | quote }}
  - name: CELERY_WORKER_CONCURRENCY
    value: {{ .Values.celery.workerConcurrency | quote }}
  - name: CACHE_API_EXERCISES_CELERY
    value: {{ .Values.celery.warmupExercisesCache | quote }}
  - name: CACHE_API_EXERCISES_CELERY_FORCE_UPDATE
    value: {{ .Values.celery.warmupExercisesCacheAll | quote }}
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
 secret-backed environment entries: django SECRET_KEY, mail password,
 celery broker/backend URLs (with or without redis authentication) and
 the flower password
 used for wger-app and celery containers
*/}}
{{- define "wger.env.secrets" }}
  - name: SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: {{ include "wger.secretName.django" . | quote }}
        key: "secret-key"
  {{- if .Values.app.mail.enabled }}
  - name: EMAIL_HOST_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "wger.secretName.mail" . | quote }}
        key: {{ .Values.app.mail.secret.key | quote }}
  {{- end }}
  {{- if .Values.app.oauth2Provider.enabled }}
  - name: IDP_OIDC_PRIVATE_KEY
    valueFrom:
      secretKeyRef:
        name: {{ include "wger.secretName.oidc" . | quote }}
        key: "private-key"
  {{- end }}
  {{- /*
   to enable redis authentication additional settings in the values
   must be made, passed to the redis container
  */}}
  {{- if .Values.redis.auth.enabled }}
  - name: DJANGO_CACHE_CLIENT_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ print .Release.Name "-redis" | quote }}
        key: "redis-password"
  - name: CELERY_BROKER
    value: "redis://:$(DJANGO_CACHE_CLIENT_PASSWORD)@{{ .Release.Name }}-redis:{{ int .Values.redis.service.serverPort }}/2"
  - name: CELERY_BACKEND
    value: "redis://:$(DJANGO_CACHE_CLIENT_PASSWORD)@{{ .Release.Name }}-redis:{{ int .Values.redis.service.serverPort }}/2"
  {{- else }}
  - name: CELERY_BROKER
    value: "redis://{{ .Release.Name }}-redis:{{ int .Values.redis.service.serverPort }}/2"
  - name: CELERY_BACKEND
    value: "redis://{{ .Release.Name }}-redis:{{ int .Values.redis.service.serverPort }}/2"
  {{- end }}
  {{- if .Values.celery.flower.enabled }}
  - name: CELERY_FLOWER_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "wger.secretName.flower" . | quote }}
        key: "password"
  {{- end }}
{{- end }}

{{/*
 database settings
 used for wger-app, celery and powersync containers
*/}}
{{- define "database.settings" }}
  - name: DJANGO_DB_HOST
    value: {{ .Values.app.django.existingDatabase.host | default (print .Release.Name "-postgres") | quote }}
  - name: DJANGO_DB_PORT
    value: {{ .Values.app.django.existingDatabase.port | default .Values.postgres.service.port | int | quote }}
  {{- if .Values.app.django.existingDatabase.enabled }}
  - name: DJANGO_DB_USER
    valueFrom:
      secretKeyRef:
        name: {{ .Values.app.django.existingDatabase.existingSecret.name | default (print .Release.Name "-existing-database") | quote }}
        key: {{ .Values.app.django.existingDatabase.existingSecret.dbuserKey | quote }}
  - name: DJANGO_DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ .Values.app.django.existingDatabase.existingSecret.name | default (print .Release.Name "-existing-database") | quote }}
        key: {{ .Values.app.django.existingDatabase.existingSecret.dbpwKey | quote }}
    {{- if .Values.app.django.existingDatabase.existingSecret.dbnameKey }}
  - name: DJANGO_DB_DATABASE
    valueFrom:
      secretKeyRef:
        name: {{ .Values.app.django.existingDatabase.existingSecret.name | default (print .Release.Name "-existing-database") | quote }}
        key: {{ .Values.app.django.existingDatabase.existingSecret.dbnameKey | quote }}
    {{- else }}
  - name: DJANGO_DB_DATABASE
    value: {{ .Values.app.django.existingDatabase.dbname | quote }}
    {{- end }}
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
 powersync settings
 requires database.settings
 used for wger-app, celery and powersync containers
*/}}
{{- define "powersync.settings" }}
  - name: JWT_PRIVATE_KEY
    valueFrom:
      secretKeyRef:
        name: {{ include "wger.secretName.jwt" . | quote }}
        key: "private-key"
  - name: JWT_PUBLIC_KEY
    valueFrom:
      secretKeyRef:
        name: {{ include "wger.secretName.jwt" . | quote }}
        key: "public-key"
  # This is the path (inside the container) to the YAML config file
  # Alternatively the config path can be specified in the command
  # e.g:
  #   command: ['start', '-r', 'unified', '-c', '/config/powersync.yaml']
  #
  # The config file can also be specified in Base 64 encoding
  # e.g.: Via an environment variable
  #   POWERSYNC_CONFIG_B64: [base64 encoded content]
  # or e.g.: Via a command line parameter
  #    command: ['start', '-r', 'unified', '-c64', '[base64 encoded content]']
  - name: POWERSYNC_CONFIG_PATH
    value: {{ .Values.powersync.configPath | quote }}
  # Sync rules can be specified as base 64 encoded YAML
  # e.g: Via an environment variable
  # POWERSYNC_SYNC_RULES_B64: "[base64 encoded sync rules]"
  # or e.g.: Via a command line parameter
  #     command: ['start', '-r', 'unified', '-sync64', '[base64 encoded content]']
  - name: PS_JWKS_URL
    {{- if .Values.powersync.jwksURL }}
    value: {{ .Values.powersync.jwksURL | quote }}
    {{- else }}
    value: "http://{{ .Release.Name }}-http:80/api/v2/powersync-keys"
    {{- end }}
  - name: PS_PORT
    value: "8080"
  - name: POWERSYNC_URL_PATH
    value: "ps"
  # ps database settings
  - name: PS_DB_USER
    valueFrom:
      secretKeyRef:
        name: {{ print .Release.Name "-powersync" | quote }}
        key: "user"
  - name: PS_DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ print .Release.Name "-powersync" | quote }}
        key: "pw"
  - name: PS_STORAGE_PG_URI
    value: "postgres://$(PS_DB_USER):$(PS_DB_PASSWORD)@$(DJANGO_DB_HOST):$(DJANGO_DB_PORT)/$(DJANGO_DB_DATABASE)"
  - name: PS_DATABASE_URI
    value: "postgres://$(DJANGO_DB_USER):$(DJANGO_DB_PASSWORD)@$(DJANGO_DB_HOST):$(DJANGO_DB_PORT)/$(DJANGO_DB_DATABASE)"
{{- end }}

{{/*
 initContainer postgres command
 used for wger-app
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
 initContainer app command
 used for celery and powersync containers
*/}}
{{- define "initContainer.app.command" }}
{{- $dbhost := .Values.app.django.existingDatabase.host | default (print .Release.Name "-postgres") | quote }}
{{- $dbport := .Values.app.django.existingDatabase.port | default .Values.postgres.service.port | int | quote }}
{{- $svcport := .Values.app.service.port | int | quote }}
- /bin/sh
- -c
# sleep 35; wait for terminationGracePeriodSeconds of the wger-app container
# this prevents using the wger-app container which are in the process of termination
# @todo find a better solution to prevent starting powersync
# on upgrades before the new wger-app container is ready
# -> this may be only relevant when upgrading from a "non" powersync setup
- sleep 35; until nc -zvw10 {{ $dbhost }} {{ $dbport }}; do echo "Waiting for postgres service ({{ $dbhost }}:{{ $dbport }}) "; sleep 2; done &&
  until nc -zvw10 {{ .Release.Name }}-redis {{ .Values.redis.service.serverPort }}; do echo "Waiting for redis service ({{ .Release.Name }}-redis:{{ .Values.redis.service.serverPort }})"; sleep 2; done &&
  until nc -zvw10 {{ .Release.Name }}-app {{ $svcport }}; do echo "Waiting for wger app service ({{ .Release.Name }}-app:{{ $svcport }})"; sleep 2; done
{{- end }}

{{/*
 secret names: user override from values, or a release-prefixed default
*/}}
{{- define "wger.secretName.django" -}}
{{- .Values.app.django.secret.name | default (print .Release.Name "-django") -}}
{{- end -}}
{{- define "wger.secretName.mail" -}}
{{- .Values.app.mail.secret.name | default (print .Release.Name "-mail") -}}
{{- end -}}
{{- define "wger.secretName.jwt" -}}
{{- .Values.app.jwt.secret.name | default (print .Release.Name "-jwt") -}}
{{- end -}}
{{- define "wger.secretName.flower" -}}
{{- .Values.celery.flower.secret.name | default (print .Release.Name "-flower") -}}
{{- end -}}
{{- define "wger.secretName.oidc" -}}
{{- .Values.app.oauth2Provider.secret.name | default (print .Release.Name "-oidc") -}}
{{- end -}}

{{/*
 generate-or-preserve secret value
 - if a value is configured in values.yaml, use it
 - otherwise reuse the value from the existing secret (upgrades)
 - otherwise generate a random one (first install)
 Call with: (dict "ctx" $ "name" <secret name> "key" <secret key>
                  "value" <configured value> "length" <random length>)
 Optional: "legacyName" — pre-2.0 unprefixed secret name; its value is
 reused once when the release-prefixed secret does not exist yet, so
 upgrades keep their generated passwords.
 Optional: "rsa" — generate a PEM encoded RSA private key instead of a
 random string ("length" is ignored).
 Returns the plain (not base64 encoded) value.
*/}}
{{- define "wger.secretValue" -}}
{{- if .value -}}
{{- .value -}}
{{- else -}}
{{- $data := (lookup "v1" "Secret" .ctx.Release.Namespace .name).data -}}
{{- if and .legacyName (not (and $data (index $data .key))) -}}
{{- $data = (lookup "v1" "Secret" .ctx.Release.Namespace .legacyName).data -}}
{{- end -}}
{{- if and $data (index $data .key) -}}
{{- index $data .key | b64dec -}}
{{- else if .rsa -}}
{{- genPrivateKey "rsa" -}}
{{- else -}}
{{- randAlphaNum (.length | int) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
 checksum over all values that end up in secrets referenced by the pods.
 Used as a pod template annotation so pods restart when a secret's content
 changes: secret values are resolved at container start via secretKeyRef,
 so a change in the secret alone does not alter the pod spec and would
 otherwise not trigger a rollout.
*/}}
{{- define "wger.checksum.secrets" -}}
{{- dict "django" .Values.app.django.secret
         "database" .Values.app.django.existingDatabase
         "postgres" .Values.postgres.settings
         "postgresUser" .Values.postgres.userDatabase
         "mail" .Values.app.mail.secret
         "redis" .Values.redis.auth
         "flower" .Values.celery.flower.secret
         "jwt" .Values.app.jwt.secret
         "oidc" .Values.app.oauth2Provider
         "powersync" .Values.powersync.secretDatabase
    | toJson | sha256sum -}}
{{- end -}}

{{/*
 pod template annotations driving restarts on config changes
 used for wger-app and celery pods (powersync adds a configmap checksum)
*/}}
{{- define "wger.rollme.annotations" }}
checksum/secrets: {{ include "wger.checksum.secrets" . }}
{{- /*
 while jwt.secret.update is set and no key is supplied, the keygen hook
 generates fresh random keys on every upgrade; no checksum can see that,
 so force a restart the old-fashioned way
*/}}
{{- if and .Values.app.jwt.secret.update (not .Values.app.jwt.secret.privateKey) }}
rollme: {{ randAlphaNum 5 | quote }}
{{- end }}
{{- end }}

{{/*
 "manipulateXX" definitions
 used for secret creation or update
*/}}
# jwt secret
{{- define "manipulatejwt" -}}
{{- if (lookup "v1" "Secret" .Release.Namespace (include "wger.secretName.jwt" .)) -}}
  {{- if .Values.app.jwt.secret.update -}}
doit
  {{- end -}}
{{- else -}}
doit
{{- end -}}
{{- end -}}
# mail secret
{{- define "manipulatemail" -}}
{{- if (lookup "v1" "Secret" .Release.Namespace (include "wger.secretName.mail" .)) -}}
  {{- if .Values.app.mail.secret.update -}}
    {{- if .Values.app.mail.secret.password -}}
doit
    {{- end -}}
  {{- end -}}
{{- else -}}
  {{- if .Values.app.mail.secret.password -}}
doit
  {{- end -}}
{{- end -}}
{{- end -}}
