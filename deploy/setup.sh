#!/usr/bin/env bash

set -e

# TODO: Set to URL of git repo.
PROJECT_GIT_URL='https://github.com/zack-dark/profile-rest-api.git'

PROJECT_BASE_PATH='/usr/local/apps/profiles-rest-api'

# Set Ubuntu Language
locale-gen en_GB.UTF-8

# Install Python, SQLite, pip, supervisor, nginx, git, and development tools
echo "Installing dependencies..."
apt-get update
apt-get install -y python3-dev python3-venv sqlite3 python3-pip supervisor nginx git build-essential

# Check if distutils is available
if ! python3 -c "import distutils" &>/dev/null; then
  echo "distutils is not available. Installing manually."
  sudo apt-get install -y python3-distutils
  if ! python3 -c "import distutils" &>/dev/null; then
    echo "distutils installation failed. Installing Python from pyenv as a fallback."
    curl https://pyenv.run | bash
    source ~/.bashrc
    pyenv install 3.11.5
    pyenv global 3.11.5
    python3 -m venv $PROJECT_BASE_PATH/env
    source $PROJECT_BASE_PATH/env/bin/activate
    pip install -r $PROJECT_BASE_PATH/requirements.txt
    exit 1
  fi
fi

# Create project directory and clone the repository
mkdir -p $PROJECT_BASE_PATH
git clone $PROJECT_GIT_URL $PROJECT_BASE_PATH

# Set up Python virtual environment
python3 -m venv $PROJECT_BASE_PATH/env

# Activate the virtual environment and install required Python packages
$PROJECT_BASE_PATH/env/bin/pip install --upgrade pip
$PROJECT_BASE_PATH/env/bin/pip install -r $PROJECT_BASE_PATH/requirements.txt uwsgi

# Run migrations to set up the database
$PROJECT_BASE_PATH/env/bin/python $PROJECT_BASE_PATH/manage.py migrate

# Setup Supervisor to run our uwsgi process
cp $PROJECT_BASE_PATH/deploy/supervisor_profiles_api.conf /etc/supervisor/conf.d/profiles_api.conf
supervisorctl reread
supervisorctl update
supervisorctl restart profiles_api

# Setup nginx to make our application accessible
cp $PROJECT_BASE_PATH/deploy/nginx_profiles_api.conf /etc/nginx/sites-available/profiles_api.conf
rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/profiles_api.conf /etc/nginx/sites-enabled/profiles_api.conf
systemctl restart nginx.service

echo "DONE! :)"
