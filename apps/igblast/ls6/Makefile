# helper commands for tapis v3 apps

APP_NAME=igblast
APP_VERSION=0.2
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
	@echo "make test-tcr  -- Submit test TCR job"
	@echo "make test-bcr  -- Submit test BCR job"
	@echo "make test-all  -- Submit all test jobs"
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
	cp ${SCRIPTS_DIR}/airr_metadata.py ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/process_metadata.py ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/presto_annotations.py ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/count_statistics.py ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/changeo_clones.sh ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/find_threshold.R ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/parse_changeo.py ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/repcalc_create_config.py ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/create_airr_metadata.py ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/assign_repertoire_id.py ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/repcalc_clones.sh ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/tcr_clone_template.json ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/clone_report.py ${BUILD_DIR}

build: clean common-scripts
	cp ${APP_JSON} ${BUILD_DIR}
	cp tapisjob_app.sh ${BUILD_DIR}
	cp igblast_common.sh ${BUILD_DIR}
	cp do_airr_makedb.sh ${BUILD_DIR}
	cp do_annotations.sh ${BUILD_DIR}
	cp do_makedb.sh ${BUILD_DIR}
	cp do_merge.sh ${BUILD_DIR}
	cp fastq2fasta.py ${BUILD_DIR}
	cp splitfasta.pl ${BUILD_DIR}
	tar zcf ${APP_ARCHIVE} -C ${BUILD_DIR} .

deploy: build
	tapis_files_upload /apps/${APP_ARCHIVE} ${APP_ARCHIVE}

test-bcr:
	tapis_jobs_submit test/test-bcr.json

test-tcr:
	tapis_jobs_submit test/test-tcr.json

test-all:
	tapis_jobs_submit test/test-bcr.json
	tapis_jobs_submit test/test-tcr.json
	tapis_jobs_submit test/test-bcr4.json
	tapis_jobs_submit test/test-cdr3-bcr4.json
	tapis_jobs_submit test/test-gene-bcr4.json
	tapis_jobs_submit test/test-mutations-bcr4.json
