#!/usr/bin/env bash

sudo apt-get update

sudo apt-get install -y lsb-release
sudo apt-get install -y openssl
sudo apt-get install -y ca-certificates
sudo apt-get install -y wget

PACKAGE="puppetlabs-release-$(lsb_release -sc).deb"

wget "https://apt.puppetlabs.com/${PACKAGE}" -O "/tmp/${PACKAGE}"

sudo dpkg -i "/tmp/${PACKAGE}"

sudo apt-get update

sudo apt-get install -y puppet

# https://tickets.puppetlabs.com/browse/PUP-2566
sed -i '/templatedir=\$confdir\/templates/d' /etc/puppet/puppet.conf

puppet module install puppetlabs/stdlib

puppet apply --modulepath=setup/modules setup/setup.pp

#sudo apt-get install -y openssh-server
#cat /dev/zero | ssh-keygen -b 4096 -t rsa -N ""
#
#sudo apt-get install -y curl
#curl -sSL https://get.docker.com/ubuntu/ | sudo sh
#
#sudo docker run --rm -v /usr/local/bin:/target jpetazzo/nsenter
#
#sudo apt-get install -y python-pip
#sudo pip install fig
#
#sudo apt-get install -y php5-cli
#sudo apt-get install -y php5-mysql
#sudo apt-get install -y php5-gd
#sudo apt-get install -y php5-redis
#sudo apt-get install -y php5-ldap
#sudo apt-get install -y php5-memcached
#
#curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename composer
#sed -i '1i export PATH="${HOME}/.composer/vendor/bin:$PATH"' ${HOME}/.bashrc
#
#. ${HOME}/.bashrc
#
#composer global require drush/drush:6.*
#
#curl -sL https://deb.nodesource.com/setup | sudo bash -
#sudo apt-get install -y nodejs
#sudo apt-get install -y build-essential
#
#sudo npm install -g less
#sudo npm install -g grunt
#sudo npm install -g grunt-cli
#
#sudo apt-get install -y git
#sudo apt-get install -y subversion
#sudo apt-get install -y mysql-client
#sudo apt-get install -y tmux
#
#sudo wget https://raw.githubusercontent.com/drush-ops/drush/master/drush.complete.sh -O /etc/bash_completion.d/drush.complete.sh
