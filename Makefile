# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

.PHONY: build clean dev help install sdist test install

PYTHON?=python3

REPO:=jupyter/pyspark-notebook:2988869079e6
DEV_REPO:=jupyter/pyspark-notebook-cms:2988869079e6
PYTHON2_SETUP:=source activate python2

define EXT_DEV_SETUP
	pushd /src && \
	pip install --no-deps -e . && \
	jupyter cms install --user && \
	jupyter cms activate && \
	popd
endef

help:
	@echo 'Host commands:'
	@echo '     build - build dev image'
	@echo '     clean - clean built files'
	@echo '       dev - start notebook server in a container with source mounted'
	@echo '   install - install latest sdist into a container'
	@echo '     sdist - build a source distribution into dist/'
	@echo '      test - run unit tests within a container'

build:
	@-docker rm -f cms-build
	@docker run -it --name cms-build \
		$(REPO) bash -c 'pip install whoosh scandir; \
			$(PYTHON2_SETUP); \
			pip install whoosh scandir'
	@docker commit cms-build $(DEV_REPO)
	@-docker rm -f cms-build

clean:
	@-rm -rf dist
	@-rm -rf *.egg-info
	@-rm -rf __pycache__ */__pycache__ */*/__pycache__
	@-find . -name '*.pyc' -exec rm -fv {} \;

dev: dev-$(PYTHON)

dev-python2: LANG_SETUP_CMD?=$(PYTHON2_SETUP) && python --version
dev-python2: _dev

dev-python3: LANG_SETUP_CMD?=python --version
dev-python3: _dev

_dev: CMD?=start-notebook.sh
_dev: AUTORELOAD?=no
_dev:
	@docker run -it --rm \
		--user jovyan \
		-p 9500:8888 \
		-e AUTORELOAD=$(AUTORELOAD) \
		-v `pwd`:/src \
		-v `pwd`/etc/notebooks:/home/jovyan/work \
		$(DEV_REPO) bash -c '$(LANG_SETUP_CMD) && $(EXT_DEV_SETUP) && $(CMD)'

install: CMD?=exit
install:
	@docker run -it --rm \
		-v `pwd`:/src \
		$(REPO) bash -c 'cd /src/dist && \
			pip install --no-binary :all: $$(ls -1 *.tar.gz | tail -n 1) && \
			jupyter cms install --user && \
			jupyter cms activate && \
			$(CMD)'

sdist:
	@docker run -it --rm \
		-v `pwd`:/src \
		$(REPO) bash -c 'cp -r /src /tmp/src && \
			cd /tmp/src && \
			python setup.py sdist $(POST_SDIST) && \
			cp -r dist /src'

test: test-$(PYTHON)

test-python2: SETUP_CMD?=$(PYTHON2_SETUP);
test-python2: _test

test-python3: _test

_test: CMD?=cd /src; python --version; python -B -m unittest discover -s test
_test:
# Need to use two commands here to allow for activation of multiple python versions
	@docker run -it --rm \
		-v `pwd`:/src \
		$(DEV_REPO) bash -c '$(SETUP_CMD) $(CMD)'

release: POST_SDIST=register upload
release: sdist
