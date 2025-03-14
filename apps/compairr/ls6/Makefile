# helper commands for tapis v3 apps

APP_NAME=compairr
APP_VERSION=0.1
APP_SYSTEM=ls6

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
	@echo "make create    -- Create tapis app, only once"
	@echo "make update    -- Update tapis app description"
	@echo ""
	@echo "App assets:"
	@echo "make clean     -- Clean build files"
	@echo "make build     -- Build archive from app assets"
	@echo "make deploy    -- Deploy app assets"
	@echo ""
	@echo "Testing:"
	@echo "make test-job  -- Submit test job"
	@echo ""

create:
	tapis_apps_create ${APP_JSON}

update:
	tapis_apps_update ${APP_ID} ${APP_VERSION} ${APP_JSON}

clean:
	rm -rf ${BUILD_DIR} ${APP_ARCHIVE}

common-scripts:
	mkdir ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/common_functions.sh ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/provenance_functions.sh ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/process_metadata.py ${BUILD_DIR}

build: clean common-scripts
	cp ${APP_JSON} ${BUILD_DIR}
	cp tapisjob_app.sh ${BUILD_DIR}
	cp ${APP_NAME}_common.sh ${BUILD_DIR}
	tar zcf ${APP_ARCHIVE} -C ${BUILD_DIR} .

deploy: build
	tapis_files_upload /akc/apps/${APP_ARCHIVE} ${APP_ARCHIVE}

test-job:
	tapis_jobs_submit test/test-cli.json

