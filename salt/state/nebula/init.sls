# OKAY SO WE NEED
# - to distribute the binary
# - customize the config based on role(lighthouse vs client) in the grains
# - systemd unit file?!

{%- set nebula = pillar.get('nebula') %}
{% set node = grains['nodename'] %}

{# TODO: apt repository? #}
/usr/local/bin/nebula:
  file.managed:
    - source: salt://nebula/files/nebula
    - makedirs: True
    - user: root
    - group: root
    - mode: 0755

/etc/nebula/config.yml:
  file.managed:
    - source: salt://nebula/files/config.yml.jinja
    - makedirs: True
    - user: root
    - group: root
    - mode: 640
    - template: jinja

/etc/nebula/ca.crt:
  file.managed:
    - contents: {{ nebula.get('ca').get('cert') | yaml_encode }}
    - makedirs: True
    - user: root
    - group: root
    - mode: 640

/etc/nebula/self.crt:
  file.managed:
    - contents: {{ nebula.get(node).get('cert') | yaml_encode }}
    - makedirs: True
    - user: root
    - group: root
    - mode: 640

/etc/nebula/self.key:
  file.managed:
    - contents: {{ nebula.get(node).get('key') | yaml_encode }}
    - makedirs: True
    - user: root
    - group: root
    - mode: 640

nebula_systemd_unit:
  file.managed:
    - name: /etc/systemd/system/nebula.service
    - source: salt://nebula/files/nebula.service
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: nebula_systemd_unit
      - file: /etc/nebula/self.key
      - file: /etc/nebula/ca.crt
      - file: /etc/nebula/config.yml
      - file: /usr/local/bin/nebula

nebula:
  service.running: []