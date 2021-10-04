nginx:
  pkg:
    - installed
  service.running:
    - watch:
      - pkg: nginx
      - file: /etc/nginx/nginx.conf
      - file: /etc/nginx/mime.types
      - file: /etc/nginx/sites-available/default

/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://nginx/files/etc/nginx/nginx.conf
    - makedirs: True
    - user: root
    - group: root
    - mode: 640

/etc/nginx/mime.types:
  file.managed:
    - source: salt://nginx/files/etc/nginx/mime.types
    - makedirs: True
    - user: root
    - group: root
    - mode: 640

/etc/nginx/sites-available/default:
  file.managed:
    - source: salt://nginx/files/etc/nginx/sites-available/default.jinja
    - makedirs: True
    - template: jinja
    - user: root
    - group: root
    - mode: 640

/etc/nginx/sites-enabled/default:
  file.symlink:
    - makedirs: True
    - target: /etc/nginx/sites-available/default
    - require:
      - file: /etc/nginx/sites-available/default

/usr/share/nginx/html/index.html:
  file.managed:
    - source: salt://nginx/files/usr/share/nginx/html/index.html.jinja
    - makedirs: True
    - template: jinja
    - user: root
    - group: root
    - mode: 644
