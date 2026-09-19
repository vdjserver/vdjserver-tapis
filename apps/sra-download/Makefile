# helper commands for tapis v3 apps

APP_NAME=sra-download
APP_VERSION=0.2
APP_SYSTEM=vm

APP_ID=${APP_NAME}-${APP_SYSTEM}
APP_FULL=${APP_ID}-${APP_VERSION}
APP_JSON=${APP_ID}.json
APP_ARCHIVE=${APP_FULL}.tgz
BUILD_DIR=build-${APP_FULL}

SCRIPTS_DIR=../../../scripts

# note: "help" MUST be the first target in the file,
# when the user types "make" they should get help info
help:
	@echo ""
	@echo "Helper commands for app: ${APP_FULL}"
	@echo "Assumes you are running in docker with tapis functions."
	@echo ""
	@echo "JSON app description:"
	@echo "make list      -- List tapis apps"
	@echo "make create    -- Create tapis app, only once"
	@echo "make update    -- Update tapis app description"
	@echo ""
	@echo "App assets:"
	@echo "make clean     -- Clean build files"
	@echo "make build     -- Build archive from app assets"
	@echo "make deploy    -- Deploy app assets"
	@echo ""
	@echo "Testing:"
	@echo "make test-cli  -- Submit test-cli job with staging server"
	@echo "make test-cli-dev  -- Submit test-cli job with dev server"
	@echo "make test-all  -- Submit all test jobs"
	@echo ""

list:
	vdjserver-tools apps list

create:
	vdjserver-tools apps create ${APP_JSON}

update:
	vdjserver-tools apps update ${APP_ID} ${APP_VERSION} ${APP_JSON}

clean:
	rm -rf ${BUILD_DIR} ${APP_ARCHIVE}

common-scripts:
	mkdir ${BUILD_DIR}
	# cp ${SCRIPTS_DIR}/get_sra_info.py ${BUILD_DIR}

build: clean common-scripts
	cp ${APP_JSON} ${BUILD_DIR}
	cp tapisjob_app.sh ${BUILD_DIR}
	tar zcf ${APP_ARCHIVE} -C ${BUILD_DIR} .

deploy: build
	vdjserver-tools files upload ${APP_ARCHIVE} /apps/${APP_ARCHIVE}

test-cli:
	vdjserver-tools jobs submit test/test-cli.json

test-cli-dev:
	vdjserver-tools jobs submit test/test-cli-dev.json

test-all:
	vdjserver-tools jobs submit test/test-cli.json
	vdjserver-tools jobs submit test/test-cli-dev.json
	
