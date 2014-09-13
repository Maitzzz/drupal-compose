#!/usr/bin/env bash

LOG_DIR=/var/log/dev
LOG="${LOG_DIR}/dev.log"
LOG_ERROR="${LOG_DIR}/error.log"

if [ "${1}" == "-h" ] || [ "${1}" == "--help" ]; then
  cat << EOF
dev install
dev update
dev config up
dev config destroy
dev config get [KEY]
dev config set [KEY] [VALUE]
dev dev config get [KEY]
dev dev config set [KEY] [VALUE]
dev image [IMAGE] pull
dev image [IMAGE] destroy
dev container [CONTAINER] start [IMAGE]
dev container [CONTAINER] destroy
EOF

  exit 1
fi

log() {
  while read DATA; do
    echo "[$(date +"%D %T")] ${DATA}" >> "${LOG}"
  done
}

log_error() {
  while read DATA; do
    echo "[$(date +"%D %T")] ${DATA}" >> "${LOG_ERROR}"
  done
}

output() {
  local COLOR="${2}"

  if [ -z "${COLOR}" ]; then
    COLOR=2
  fi

  echo "$(tput setaf ${COLOR})${1}$(tput sgr 0)"
}

output_error() {
  >&2 output "${1}" 1
}

output_debug() {
  if [ ${DEBUG} ]; then
    output "${1}" 3
  fi
}

image_exists() {
  local RETURN=0

  if [ "$(sudo docker inspect "${1}" 2> /dev/null)" == "[]" ]; then
    RETURN=1
  fi

  return "${RETURN}"
}

image_pull() {
  output_debug "FUNCTION: image_pull ARGS: ${*}"

  local IMAGE="${1}"

  output "Pulling image: ${IMAGE}"

  sudo docker pull "${IMAGE}" > >(log) 2> >(log_error)
}

image_destroy() {
  output_debug "FUNCTION: image_destroy ARGS: ${*}"

  local IMAGE="${1}"

  if ! $(image_exists "${IMAGE}"); then
    output_error "No such image: ${IMAGE}"

    return 1
  fi

  for ID in $(sudo docker ps -aq); do
    if [ "$(sudo docker inspect -f "{{ .Config.Image }}" "${ID}" 2> /dev/null)" == "${IMAGE}" ]; then
      container "${ID}" destroy
    fi
  done

  output "Destroying image: ${IMAGE}"

  sudo docker rmi "${IMAGE}" > >(log) 2> >(log_error)
}

image() {
  output_debug "FUNCTION: image ARGS: ${*}"

  if [ "${1}" == "-h" ] || [ "${1}" == "--help" ]; then
    cat << EOF
dev image [NAME] pull
dev image [NAME] destroy
EOF

    exit 1
  fi

  local IMAGE="${1}"

  case "${2}" in
    pull)
      image_pull "${IMAGE}"
    ;;
    destroy)
      image_destroy "${IMAGE}"
    ;;
    *)
      output_error "dev: Unknown command. See 'dev image --help'"

      exit 1
    ;;
  esac
}

container_exists() {
  local RETURN=0

  if [ "$(sudo docker inspect "${1}" 2> /dev/null)" == "[]" ]; then
    RETURN=1
  fi

  return "${RETURN}"
}

container_running() {
  local RETURN=1

  if [ "$(sudo docker inspect -f "{{ .State.Running }}" "${1}" 2> /dev/null)" == "true" ]; then
    RETURN=0
  fi

  return "${RETURN}"
}

container_name() {
  echo "$(sudo docker inspect -f "{{ .Name }}" "${1}" 2> /dev/null | cut -d "/" -f 2)"
}

container_start() {
  output_debug "FUNCTION: container_start ARGS: ${*}"

  local IMAGE="${1}"
  local CONTAINER="${2}"
  local CALLBACK="${CONTAINER}_start"

  if $(container_exists "${CONTAINER}"); then
    container "${CONTAINER}" destroy
  fi

  image "${IMAGE}" pull

  output "Starting container: ${CONTAINER}"

  eval "${CALLBACK} ${CONTAINER} ${IMAGE}"
}

container() {
  output_debug "FUNCTION: container ARGS: ${*}"

  if [ "${1}" == "-h" ] || [ "${1}" == "--help" ]; then
    cat << EOF
dev container [CONTAINER] start
dev container [CONTAINER] destroy
EOF

    exit 1
  fi

  local CONTAINER="${1}"

  case "${2}" in
    start)
      local IMAGE="${3}"

      container_start "${IMAGE}" "${CONTAINER}"
    ;;
    destroy)
      if ! $(container_exists "${CONTAINER}"); then
        output_error "No such container: ${CONTAINER}"

        return 1
      fi

      CONTAINER=$(container_name "${CONTAINER}")

      if $(container_running "${CONTAINER}"); then
        output "Stopping container: ${CONTAINER}"

        sudo docker stop "${CONTAINER}" > >(log) 2> >(log_error)
      fi

      output "Destroying container: ${CONTAINER}"

      sudo docker rm "${CONTAINER}" > >(log) 2> >(log_error)
    ;;
    *)
      output_error "dev: Unknown command. See 'dev container --help'"

      exit 1
    ;;
  esac
}

redis2814_start() {
  output_debug "FUNCTION: redis2814_start ARGS: ${*}"

  local CONTAINER="${1}"
  local IMAGE="${2}"

  sudo docker run \
    --name "${CONTAINER}" \
    --net host \
    -v /var/redis-2.8.14/data:/redis-2.8.14/data \
    -d \
    "${IMAGE}" > >(log) 2> >(log_error)
}

config() {
  local SERVICE="Configuration manager"
  local CONTAINER=redis2814
  local IMAGE=simpledrupalcloud/redis:2.8.14

  output_debug "FUNCTION: config ARGS: ${*}"

  if [ "${1}" == "-h" ] || [ "${1}" == "--help" ]; then
    cat << EOF
dev config up
dev config destroy
dev config get [KEY]
dev config set [KEY] [VALUE]
EOF

    exit 1
  fi

  local ACTION="${1}"

  case "${ACTION}" in
    up)
      output "Starting service: ${SERVICE}"

      container "${CONTAINER}" start "${IMAGE}"
    ;;
    destroy)
      output "Destroying service: ${SERVICE}"

      image "${IMAGE}" destroy
    ;;
    get)
      local KEY="${2}"

      echo -n "$(dev config get "${KEY}")"
    ;;
    set)
      local KEY="${2}"
      local VALUE="${3}"

      dev config set "${KEY}" "${VALUE}"
    ;;
    *)
      output_error "dev: Unknown command. See 'dev config --help'"

      exit 1
    ;;
  esac
}

dev() {
  local IMAGE=simpledrupalcloud/dev

  output_debug "FUNCTION: dev ARGS: ${*}"

  if [ "${1}" == "-h" ] || [ "${1}" == "--help" ]; then
    cat << EOF
dev dev config get [KEY]
dev dev config set [KEY] [VALUE]
EOF

    exit 1
  fi

  local ACTION="${1}"

  case "${ACTION}" in
    config)
      case "${2}" in
        get)
          local KEY="${3}"

          echo -n "$(sudo docker run --net host --rm -i -t -a stdout "${IMAGE}" config get "${KEY}" 2> >(log_error))"
        ;;
        set)
          local KEY="${3}"
          local VALUE="${4}"

          sudo docker run --net host --rm -i -t -a stdout "${IMAGE}" config set "${KEY}" "${VALUE}" > >(log) 2> >(log_error)
        ;;
        *)
          output_error "dev: Unknown command. See 'dev dev --help'"

          exit 1
      esac
    ;;
  esac
}

#
#docker_dev_stop() {
#  sudo docker stop dev
#}
#
#docker_dev_rm() {
#  docker_dev_stop
#
#  sudo docker rm dev
#}
#
#docker_dev_rmi() {
#  docker_dev_rm
#
#  sudo docker rmi simpledrupalcloud/dev
#}
#
#docker_dev_pull() {
#  sudo docker pull simpledrupalcloud/dev
#}
#
#docker_dev_update() {
#  docker_dev_rm
#  docker_dev_pull
#}
#
#docker_dev_destroy() {
#  docker_dev_rmi
#}
#
#docker_config_run() {
#  sudo docker run \
#    --name config \
#    --net host \
#    -v /var/redis-2.8.14/data:/redis-2.8.14/data \
#    -d \
#    simpledrupalcloud/redis:2.8.14
#}
#
#docker_config_stop() {
#  sudo docker stop config
#}
#
#docker_config_rm() {
#  docker_config_stop
#
#  sudo docker rm config
#}
#
#docker_config_rmi() {
#  docker_config_rm
#
#  sudo docker rmi simpledrupalcloud/redis:2.8.14
#}
#
#docker_config_pull() {
#  sudo docker pull simpledrupalcloud/redis:2.8.14
#}
#
#docker_config_update() {
#  docker_config_rm
#  docker_config_pull
#  docker_config_run
#}
#
#docker_config_start() {
#  docker_config_rm
#  docker_config_run
#}
#
#docker_config_restart() {
#  docker_config_rm
#  docker_config_run
#}
#
#docker_config_destroy() {
#  docker_config_rmi
#}
#
#docker_mailcatcher0512_run() {
#  sudo docker run \
#    --name mailcatcher0512 \
#    --net host \
#    -d \
#    simpledrupalcloud/mailcatcher:0.5.12
#}
#
#docker_mailcatcher0512_stop() {
#  sudo docker stop mailcatcher0512
#}
#
#docker_mailcatcher0512_rm() {
#  docker_mailcatcher0512_stop
#
#  sudo docker rm mailcatcher0512
#}
#
#docker_mailcatcher0512_rmi() {
#  docker_mailcatcher0512_rm
#
#  sudo docker rmi simpledrupalcloud/mailcatcher:0.5.12
#}
#
#docker_mailcatcher0512_pull() {
#  sudo docker pull simpledrupalcloud/mailcatcher:0.5.12
#}
#
#docker_mailcatcher0512_update() {
#  docker_mailcatcher0512_rm
#  docker_mailcatcher0512_pull
#  docker_mailcatcher0512_run
#}
#
#docker_mailcatcher0512_start() {
#  docker_mailcatcher0512_rm
#  docker_mailcatcher0512_run
#}
#
#docker_mailcatcher0512_restart() {
#  docker_mailcatcher0512_rm
#  docker_mailcatcher0512_run
#}
#
#docker_mailcatcher0512_destroy() {
#  docker_mailcatcher0512_rmi
#}
#
#docker_apache2222_run() {
#  APACHE_SERVERNAME=$(config_get APACHE_SERVERNAME)
#
#  sudo docker run \
#    --name apache2222 \
#    --net host \
#    -v /var/apache-2.2.22/conf.d:/apache-2.2.22/conf.d \
#    -v /var/apache-2.2.22/data:/apache-2.2.22/data \
#    -v /var/apache-2.2.22/log:/apache-2.2.22/log \
#    -e APACHE_SERVERNAME="${APACHE_SERVERNAME}" \
#    -d \
#    simpledrupalcloud/apache:2.2.22
#}
#
#docker_apache2222_stop() {
#  sudo docker stop apache2222
#}
#
#docker_apache2222_rm() {
#  docker_apache2222_stop
#
#  sudo docker rm apache2222
#}
#
#docker_apache2222_rmi() {
#  docker_apache2222_rm
#
#  sudo docker rmi simpledrupalcloud/apache:2.2.22
#}
#
#docker_apache2222_pull() {
#  sudo docker pull simpledrupalcloud/apache:2.2.22
#}
#
#docker_apache2222_update() {
#  docker_apache2222_rm
#  docker_apache2222_pull
#  docker_apache2222_run
#}
#
#docker_apache2222_start() {
#  docker_apache2222_rm
#  docker_apache2222_run
#}
#
#docker_apache2222_restart() {
#  docker_apache2222_rm
#  docker_apache2222_run
#}
#
#docker_apache2222_destroy() {
#  docker_apache2222_rmi
#}
#
#docker_php5217_run() {
#  sudo docker run \
#    --name php5217 \
#    --net host \
#    --volumes-from apache2222 \
#    -d \
#    simpledrupalcloud/php:5.2.17
#}
#
#docker_php5217_stop() {
#  sudo docker stop php5217
#}
#
#docker_php5217_rm() {
#  docker_php5217_stop
#
#  sudo docker rm php5217
#}
#
#docker_php5217_rmi() {
#  docker_php5217_rm
#
#  sudo docker rmi simpledrupalcloud/php:5.2.17
#}
#
#docker_php5217_pull() {
#  sudo docker pull simpledrupalcloud/php:5.2.17
#}
#
#docker_php5217_update() {
#  docker_php5217_rm
#  docker_php5217_pull
#  docker_php5217_run
#}
#
#docker_php5217_start() {
#  docker_php5217_rm
#  docker_php5217_run
#}
#
#docker_php5217_restart() {
#  docker_php5217_rm
#  docker_php5217_run
#}
#
#docker_php5217_destroy() {
#  docker_php5217_rmi
#}
#
#docker_php5328_run() {
#  sudo docker run \
#    --name php5328 \
#    --net host \
#    --volumes-from apache2222 \
#    -d \
#    simpledrupalcloud/php:5.3.28
#}
#
#docker_php5328_stop() {
#  sudo docker stop php5328
#}
#
#docker_php5328_rm() {
#  docker_php5328_stop
#
#  sudo docker rm php5328
#}
#
#docker_php5328_rmi() {
#  docker_php5328_rm
#
#  sudo docker rmi simpledrupalcloud/php:5.3.28
#}
#
#docker_php5328_pull() {
#  sudo docker pull simpledrupalcloud/php:5.3.28
#}
#
#docker_php5328_update() {
#  docker_php5328_rm
#  docker_php5328_pull
#  docker_php5328_run
#}
#
#docker_php5328_start() {
#  docker_php5328_rm
#  docker_php5328_run
#}
#
#docker_php5328_restart() {
#  docker_php5328_rm
#  docker_php5328_run
#}
#
#docker_php5328_destroy() {
#  docker_php5328_rmi
#}
#
#docker_php5431_run() {
#  sudo docker run \
#    --name php5431 \
#    --net host \
#    --volumes-from apache2222 \
#    -d \
#    simpledrupalcloud/php:5.4.31
#}
#
#docker_php5431_stop() {
#  sudo docker stop php5431
#}
#
#docker_php5431_rm() {
#  docker_php5431_stop
#
#  sudo docker rm php5431
#}
#
#docker_php5431_rmi() {
#  docker_php5431_rm
#
#  sudo docker rmi simpledrupalcloud/php:5.4.31
#}
#
#docker_php5431_pull() {
#  sudo docker pull simpledrupalcloud/php:5.4.31
#}
#
#docker_php5431_update() {
#  docker_php5431_rm
#  docker_php5431_pull
#  docker_php5431_run
#}
#
#docker_php5431_start() {
#  docker_php5431_rm
#  docker_php5431_run
#}
#
#docker_php5431_restart() {
#  docker_php5431_rm
#  docker_php5431_run
#}
#
#docker_php5431_destroy() {
#  docker_php5431_rmi
#}
#
#docker_php5515_run() {
#  sudo docker run \
#    --name php5515 \
#    --net host \
#    --volumes-from apache2222 \
#    -d \
#    simpledrupalcloud/php:5.5.15
#}
#
#docker_php5515_stop() {
#  sudo docker stop php5515
#}
#
#docker_php5515_rm() {
#  docker_php5515_stop
#
#  sudo docker rm php5515
#}
#
#docker_php5515_rmi() {
#  docker_php5515_rm
#
#  sudo docker rmi simpledrupalcloud/php:5.5.15
#}
#
#docker_php5515_pull() {
#  sudo docker pull simpledrupalcloud/php:5.5.15
#}
#
#docker_php5515_update() {
#  docker_php5515_rm
#  docker_php5515_pull
#  docker_php5515_run
#}
#
#docker_php5515_start() {
#  docker_php5515_rm
#  docker_php5515_run
#}
#
#docker_php5515_restart() {
#  docker_php5515_rm
#  docker_php5515_run
#}
#
#docker_php5515_destroy() {
#  docker_php5515_rmi
#}
#
#docker_mysql5538_run() {
#  sudo docker run \
#    --name mysql5538 \
#    --net host \
#    -v /var/mysql-5.5.38/conf.d:/mysql-5.5.38/conf.d \
#    -v /var/mysql-5.5.38/data:/mysql-5.5.38/data \
#    -v /var/mysql-5.5.38/log:/mysql-5.5.38/log \
#    -d \
#    simpledrupalcloud/mysql:5.5.38
#}
#
#docker_mysql5538_stop() {
#  sudo docker stop mysql5538
#}
#
#docker_mysql5538_rm() {
#  docker_mysql5538_stop
#
#  sudo docker rm mysql5538
#}
#
#docker_mysql5538_rmi() {
#  docker_mysql5538_rm
#
#  sudo docker rmi simpledrupalcloud/mysql:5.5.38
#}
#
#docker_mysql5538_pull() {
#  sudo docker pull simpledrupalcloud/mysql:5.5.38
#}
#
#docker_mysql5538_update() {
#  docker_mysql5538_rm
#  docker_mysql5538_pull
#  docker_mysql5538_run
#}
#
#docker_mysql5538_start() {
#  docker_mysql5538_rm
#  docker_mysql5538_run
#}
#
#docker_mysql5538_restart() {
#  docker_mysql5538_rm
#  docker_mysql5538_run
#}
#
#docker_mysql5538_destroy() {
#  docker_mysql5538_rmi
#}
#
#phpmyadmin() {
#  TMP=$(mktemp -d)
#
#  sudo wget http://sourceforge.net/projects/phpmyadmin/files/phpMyAdmin/4.2.8/phpMyAdmin-4.2.8-english.zip -O "${TMP}/phpMyAdmin-4.2.8-english.zip"
#
#  sudo apt-get install -y unzip
#
#  sudo unzip "${TMP}/phpMyAdmin-4.2.8-english.zip" -d /var/apache-2.2.22/data
#
#  sudo rm -rf /var/apache-2.2.22/data/phpmyadmin
#
#  sudo mv /var/apache-2.2.22/data/phpMyAdmin-4.2.8-english /var/apache-2.2.22/data/phpmyadmin
#}

install() {
  sudo mkdir -p "${LOG_DIR}"

  if [ ! -f /usr/local/bin/dev ]; then
    sudo apt-get install -y realpath
  fi

  SCRIPT=$(realpath -s "${0}")

  if [ "${SCRIPT}" = /usr/local/bin/dev ]; then
    cat << EOF
dev is already installed on this machine.

Type "dev update" to get the latest updates.
EOF
    exit
  fi

  if [ ! -f /usr/local/bin/dev ]; then
    sudo apt-get install -y curl

    curl -sSL https://get.docker.io/ubuntu/ | sudo bash
  fi

#  sudo docker stop redis2814
#  sudo docker rm redis2814
#  sudo docker stop apache
#  sudo docker rm apache
#  sudo docker stop mysql
#  sudo docker rm mysql
#
#  docker_dev_update
#  docker_config_update
#  docker_apache2222_update
#
#  sudo cp $(dirname "${0}")/php5-fcgi /var/apache-2.2.22/conf.d
#
#  docker_apache2222_update
#
#  docker_php5217_update
#  docker_php5328_update
#  docker_php5328_update
#  docker_php5431_update
#  docker_php5515_update
#  docker_mysql5538_update
#  docker_mailcatcher0512_update
#
#  phpmyadmin
#
#  sudo cp $(dirname "${0}")/config.inc.php /var/apache-2.2.22/data/phpmyadmin
#
#  sudo chown www-data.www-data /var/apache-2.2.22/data/phpmyadmin -R

  sudo cp "${SCRIPT}" /usr/local/bin/dev
}

update() {
  TMP=$(mktemp -d)

  git clone http://git.simpledrupalcloud.com/simpledrupalcloud/dev.git "${TMP}"

  "${TMP}"/dev.sh install
}

#start() {
#  docker_config_start
#  docker_apache2222_start
#  docker_php5217_start
#  docker_php5328_start
#  docker_php5431_start
#  docker_php5515_start
#  docker_mysql5538_start
#  docker_mailcatcher0512_start
#}
#
#restart() {
#  case "${1}" in
#    config)
#      docker_config_restart
#      ;;
#    apache)
#      docker_apache2222_restart
#      ;;
#    php)
#      docker_php5217_restart
#      docker_php5328_restart
#      docker_php5431_restart
#      docker_php5515_restart
#      ;;
#    mysql)
#      docker_mysql5538_restart
#      ;;
#    mailcatcher)
#      docker_mailcatcher0512_restart
#      ;;
#    *)
#      docker_config_restart
#      docker_apache2222_restart
#      docker_php5217_restart
#      docker_php5328_restart
#      docker_php5431_restart
#      docker_php5515_restart
#      docker_mysql5538_restart
#      docker_mailcatcher0512_restart
#      ;;
#  esac
#}
#
#destroy() {
#  docker_dev_destroy
#  docker_config_destroy
#  docker_apache2222_destroy
#  docker_php5217_destroy
#  docker_php5328_destroy
#  docker_php5431_destroy
#  docker_php5515_destroy
#  docker_mysql5538_destroy
#  docker_mailcatcher0512_destroy
#}

case "${1}" in
  install)
    install
    ;;
  update)
    update
    ;;
#  start)
#    start
#    ;;
#  restart)
#    restart "${2}"
#    ;;
#  destroy)
#    destroy
#    ;;
#  config)
#    case "${2}" in
#      get)
#        echo -n $(config get "${3}")
#      ;;
#      set)
#        echo $(config set "${3}" "${4}")
#      ;;
#      *)
#        echo $(config "${3}")
#      ;;
#    esac
#    ;;
  config)
    case "${2}" in
      get)
        echo -n "$(config get "${@:3}")"
      ;;
      *)
        config "${@:2}"
      ;;
    esac
  ;;
  dev)
    dev "${@:2}"
  ;;
  image)
    image "${@:2}"
  ;;
  container)
    container "${@:2}"
  ;;
  *)
    output_error "dev: Unknown command. See 'dev --help'"

    exit 1
  ;;
esac
